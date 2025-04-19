defmodule Raga.Ollama.Client do
  @moduledoc """
  Client for interacting with the local Ollama API for embeddings
  """
  use GenServer
  require Logger

  @embedding_model "nomic-embed-text"
  @base_url "http://localhost:11434/api"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  @doc """
  Generate embeddings for the given text using Ollama's API
  """
  def generate_embeddings(text) when is_binary(text) do
    GenServer.call(__MODULE__, {:embeddings, text}, 30_000)  # 30 second timeout
  end

  # GenServer callbacks

  def handle_call({:embeddings, text}, _from, state) do
    url = "#{@base_url}/embeddings"
    
    headers = [
      {"Content-Type", "application/json"}
    ]
    
    body = Jason.encode!(%{
      model: @embedding_model,
      prompt: text
    })
    
    response = 
      :post
      |> Finch.build(url, headers, body)
      |> Finch.request(Raga.Finch)
    
    case response do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        result = Jason.decode!(body)
        embedding = result["embedding"]
        {:reply, {:ok, embedding}, state}
      
      {:ok, %Finch.Response{status: status, body: body}} ->
        error = Jason.decode!(body)
        Logger.error("Ollama API error: #{status} - #{inspect(error)}")
        {:reply, {:error, "Ollama API error: #{status}"}, state}
      
      {:error, reason} ->
        Logger.error("Ollama API request failed: #{inspect(reason)}")
        {:reply, {:error, "Failed to connect to Ollama API"}, state}
    end
  end
end
