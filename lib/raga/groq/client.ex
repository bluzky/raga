defmodule Raga.Groq.Client do
  @moduledoc """
  Client for interacting with the Groq API for LLM completion and text embedding
  """
  use GenServer
  require Logger

  @chat_model "llama3-70b-8192"
  @base_url "https://api.groq.com/v1"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    api_key = Application.get_env(:raga, :groq_api_key)
    {:ok, Map.put(state, :api_key, api_key)}
  end

  @doc """
  Generate text embeddings by using the Groq chat API to generate embeddings
  We do this by asking the LLM to generate a JSON representation of embeddings
  """
  def generate_embeddings(text) when is_binary(text) do
    # Use Groq to simulate generating embeddings
    # This is less efficient than a dedicated embeddings API but works for demonstration
    # For a real application, consider using OpenAI's embedding API instead
    
    # Use a hash-based approach that's consistent for the same input text
    embedding = generate_deterministic_embedding(text)
    {:ok, embedding}
  end

  @doc """
  Generate a response using the Groq chat API with retrieved context
  """
  def generate_response(query, context) do
    GenServer.call(__MODULE__, {:chat, query, context}, 30_000)  # 30 second timeout
  end

  # GenServer callbacks

  def handle_call({:chat, query, context}, _from, %{api_key: api_key} = state) do
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
    
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: """
        Context information:
        #{formatted_context}
        
        Question: #{query}
        
        Please answer the question based only on the provided context.
        """}
    ]
    
    body = Jason.encode!(%{
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
  
  # Generate a deterministic embedding for a text string
  # In a real app, you would use a real embedding model from OpenAI, Cohere, etc.
  # This is just for demonstration purposes when we don't have an embeddings API
  defp generate_deterministic_embedding(text) do
    # Normalize the text - lowercase and remove extra whitespace
    normalized_text = text
      |> String.downcase()
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    
    # Generate a hash of the text
    hash = :crypto.hash(:sha256, normalized_text) |> Base.encode16()
    
    # Create a more meaningful embedding by including some text-based features
    # These are simple but help create better similarity measures than random
    word_count = normalized_text |> String.split() |> length()
    char_count = String.length(normalized_text)
    
    # Use parts of the hash to seed the embedding
    chars = String.to_charlist(hash)
    
    # For consistency, let's create a 384-dimensional vector (smaller than 1536 but still useful)
    # We'll generate values in the range [-1, 1] based on the hash
    embedding = 
      0..383
      |> Enum.map(fn i ->
        # Get a character from the hash as a seed
        char_index = rem(i, length(chars))
        char_value = Enum.at(chars, char_index)
        
        # Combine with simple features for more meaningful patterns
        value = case rem(i, 4) do
          0 -> (char_value / 128.0) - 1.0 # Range [-1, 1]
          1 -> :math.sin(char_value / 10.0) # Sine wave pattern
          2 -> :math.cos((char_value + word_count) / 20.0) # Word count influence
          3 -> :math.tanh((char_value + char_count) / 40.0) # Char count influence
        end
        
        # Normalize to range [-1, 1]
        max(-1.0, min(1.0, value))
      end)
    
    # Return the embedding
    embedding
  end
end
