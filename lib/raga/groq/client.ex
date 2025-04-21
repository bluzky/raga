defmodule Raga.Groq.Client do
  @moduledoc """
  Client for interacting with the Groq API with tool/function support
  """
  use GenServer
  require Logger

  alias Raga.Groq.ToolHandler

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
  Generate a response using the Groq chat API with tool support
  """
  def generate_response(query, context \\ nil, conversation_history \\ nil) do
    cond do
      # If context is a list of maps with document info, use legacy method
      is_list(context) && Enum.all?(context, fn item -> Map.has_key?(item, :document_title) end) ->
        # Legacy method with context and optional conversation history
        # 30 second timeout
        GenServer.call(__MODULE__, {:chat, query, context, conversation_history}, 30_000)
        
      # If context is actually conversation history, use tool support method
      true ->
        # New method with tool support (context as conversation_history)
        # 30 second timeout
        GenServer.call(__MODULE__, {:chat_with_tools, query, context}, 30_000)
    end
  end

  # GenServer callbacks

  def handle_call(
        {:chat_with_tools, query, conversation_history},
        _from,
        %{api_key: api_key} = state
      ) do
    url = "#{@base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    system_prompt = """
    You are a helpful AI assistant that can search through a knowledge base when needed.
    You have access to tools including 'search_knowledge_base' which you can use to find relevant information.
    Only use the search tool when you believe the question requires specific information from the knowledge base.
    For general questions that don't require specific facts or documentation, answer directly.
    When using information from the knowledge base, always cite your sources.
    Maintain a conversational style when responding to follow-up questions.
    """

    # Build messages
    messages =
      if conversation_history && length(conversation_history) > 0 do
        # Keep conversation history
        [%{role: "system", content: system_prompt}] ++ conversation_history ++ [%{role: "user", content: query}]
      else
        # New conversation
        [
          %{role: "system", content: system_prompt},
          %{role: "user", content: query}
        ]
      end

    # Get tool definitions
    tools = ToolHandler.get_available_tools()

    body =
      Jason.encode!(%{
        model: @chat_model,
        messages: messages,
        temperature: 0.2,
        tools: tools,
        tool_choice: "auto"
      })

    response =
      :post
      |> Finch.build(url, headers, body)
      |> Finch.request(Raga.Finch)

    case response do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        result = Jason.decode!(body)
        handle_groq_response(result, messages, state)

      {:ok, %Finch.Response{status: status, body: body}} ->
        error = Jason.decode!(body)
        Logger.error("Groq API error: #{status} - #{inspect(error)}")
        {:reply, {:error, "Groq API error: #{status}"}, state}

      {:error, reason} ->
        Logger.error("Groq API request failed: #{inspect(reason)}")
        {:reply, {:error, "Failed to connect to Groq API"}, state}
    end
  end

  # Legacy method for backward compatibility
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
    """

    formatted_context = format_context(context)

    messages =
      cond do
        # If conversation_history is provided, append the context and query
        conversation_history && length(conversation_history) > 0 ->
          [%{role: "system", content: system_prompt}] ++ 
          conversation_history ++ 
          [%{
            role: "user",
            content: """
            Context information:
            #{formatted_context}

            Question: #{query}

            Please answer the question based only on the provided context.
            """
          }]
          
        # No conversation history, create simple messages
        true ->
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

  defp handle_groq_response(result, messages, state) do
    choice = hd(result["choices"])
    message = choice["message"]

    # Check if there's a tool call
    case message["tool_calls"] do
      nil ->
        # No tool call, return the response with nil sources
        response_content = message["content"]
        {:reply, {:ok, response_content, nil}, state}

      tool_calls ->
        # Handle tool calls
        tool_results = execute_tool_calls(tool_calls)
        
        # Continue conversation with tool results
        updated_messages = messages ++ [message] ++ tool_results

        # Make another request with the tool results
        continue_conversation(updated_messages, state)
    end
  end

  defp execute_tool_calls(tool_calls) do
    tool_calls
    |> Enum.map(fn tool_call ->
      function = tool_call["function"]
      tool_name = function["name"]
      tool_call_id = tool_call["id"]  # Get the actual tool call ID from the response
      arguments = function["arguments"] |> Jason.decode!()

      case ToolHandler.handle_tool_call(tool_name, arguments) do
        {:ok, result} ->
          # Pass the tool_call_id to format_tool_result
          format_tool_result(tool_call_id, result)

        {:error, error} ->
          format_tool_result(tool_call_id, "Error: #{error}")
      end
    end)
  end

  defp format_tool_result(tool_call_id, result) do
    %{
      role: "tool",
      tool_call_id: tool_call_id,
      content: Jason.encode!(result)
    }
  end

  defp continue_conversation(messages, %{api_key: api_key} = state) do
    url = "#{@base_url}/chat/completions"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

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
        
        # Extract sources from tool results if any
        sources = extract_sources_from_tool_results(messages)
        
        {:reply, {:ok, response_content, sources}, state}

      {:ok, %Finch.Response{status: status, body: body}} ->
        error = Jason.decode!(body)
        Logger.error("Groq API error: #{status} - #{inspect(error)}")
        {:reply, {:error, "Groq API error: #{status}"}, state}

      {:error, reason} ->
        Logger.error("Groq API request failed: #{inspect(reason)}")
        {:reply, {:error, "Failed to connect to Groq API"}, state}
    end
  end

  defp format_context(context) when is_list(context) do
    # Handle document chunks or conversation history properly
    if Enum.all?(context, fn item -> is_map(item) && Map.has_key?(item, :document_title) end) do
      # Format document chunks
      context
      |> Enum.map(fn %{document_title: title, chunk_content: content, similarity: similarity} ->
        """
        Document: #{title}
        Content: #{content}
        Relevance: #{Float.round(similarity * 100, 2)}%
        """
      end)
      |> Enum.join("\n\n")
    else
      # Handle potential conversation history or other formats
      inspect(context)
    end
  end
  
  defp format_context(context), do: inspect(context)

  defp extract_sources_from_tool_results(messages) do
    messages
    |> Enum.filter(fn msg -> msg[:role] == "tool" end)
    |> Enum.flat_map(fn msg ->
      content = Jason.decode!(msg[:content])
      if content && is_list(content) do
        Enum.map(content, fn result ->
          %{title: result["title"]}
        end)
      else
        []
      end
    end)
    |> Enum.uniq_by(fn source -> source.title end)
  end
end
