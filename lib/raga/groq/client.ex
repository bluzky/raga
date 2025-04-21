defmodule Raga.Groq.Client do
  @moduledoc """
  Client for interacting with the Groq API for LLM completion and text embedding
  """
  use GenServer
  require Logger

  @chat_model "llama3-70b-8192"
  @base_url "https://api.groq.com/openai/v1"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    api_key = Application.get_env(:raga, :groq_api_key)
    {:ok, Map.put(state, :api_key, api_key)}
  end

  @doc """
  Generate a response using the Groq chat API with retrieved context
  If conversation_history is provided, it will be used to maintain context
  """
  def generate_response(query, context, conversation_history \\ nil) do
    # 30 second timeout
    GenServer.call(__MODULE__, {:chat, query, context, conversation_history}, 30_000)
  end

  # GenServer callbacks

  def handle_call(
        {:chat, query, context, conversation_history},
        _from,
        %{api_key: api_key} = state
      ) do
    url = "#{@base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    system_prompt = """
    You are a helpful AI assistant that answers questions based on provided context.
    If the context doesn't contain relevant information, indicate that you don't know rather than making up an answer.
    Always cite your sources by referring to the document title in your answer.
    Maintain a conversational style when responding to follow-up questions.
    """

    formatted_context = format_context(context)

    # Decide which messages to use based on conversation history
    messages =
      if conversation_history && length(conversation_history) > 0 do
        # Create initial system message
        system_message = %{role: "system", content: system_prompt}

        # Create a context message that will be inserted just before the latest user query
        context_message = %{
          role: "system",
          content: """
          Here is relevant context information to help answer the latest question:
          #{formatted_context}

          Use this context to inform your next response.
          """
        }

        # Use existing conversation history, but insert context before the last user message
        # This approach keeps the full conversation history intact but adds context
        history_length = length(conversation_history)

        if history_length > 1 do
          # Insert context message before the latest user message
          {earlier_messages, [last_message]} =
            Enum.split(conversation_history, history_length - 1)

          [system_message] ++ earlier_messages ++ [context_message, last_message]
        else
          # If there's only one message (the current user query), add context before it
          [system_message, context_message] ++ conversation_history
        end
      else
        # No conversation history, use simple prompt with context
        [
          %{role: "system", content: system_prompt},
          %{
            role: "user",
            content: """
            Context information:
            #{formatted_context}

            Question: #{query}

            Please answer the question based only on the provided context.
            """
          }
        ]
      end

    body =
      Jason.encode!(%{
        model: @chat_model,
        messages: messages,
        temperature: 0.2
      })

    response =
      :post
      |> Finch.build(url, headers, body)
      |> Finch.request(Raga.Finch)

    case response do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        result = Jason.decode!(body)
        response_content = get_in(result, ["choices", Access.at(0), "message", "content"])
        {:reply, {:ok, response_content}, state}

      {:ok, %Finch.Response{status: status, body: body}} ->
        error = Jason.decode!(body)
        Logger.error("Groq API error: #{status} - #{inspect(error)}")
        {:reply, {:error, "Groq API error: #{status}"}, state}

      {:error, reason} ->
        Logger.error("Groq API request failed: #{inspect(reason)}")
        {:reply, {:error, "Failed to connect to Groq API"}, state}
    end
  end

  # Helper functions

  defp format_context(context) do
    context
    |> Enum.map(fn %{document_title: title, chunk_content: content, similarity: similarity} ->
      """
      Document: #{title}
      Content: #{content}
      Relevance: #{Float.round(similarity * 100, 2)}%
      """
    end)
    |> Enum.join("\n\n")
  end
end
