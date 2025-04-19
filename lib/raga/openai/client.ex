defmodule Raga.OpenAI.Client do
  @moduledoc """
  Client for interacting with the OpenAI API for embeddings
  """
  use GenServer
  require Logger

  @embedding_model "text-embedding-3-small"
  @base_url "https://api.openai.com/v1"

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    api_key = Application.get_env(:raga, :openai_api_key)
    {:ok, Map.put(state, :api_key, api_key)}
  end

  @doc """
  Generate embeddings for the given text using OpenAI's API
  """
  def generate_embeddings(text) when is_binary(text) do
    GenServer.call(__MODULE__, {:embeddings, text}, 30_000)  # 30 second timeout
  end

  # GenServer callbacks

  def handle_call({:embeddings, text}, _from, %{api_key: api_key} = state) do
    url = "#{@base_url}/embeddings"
    
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
    
    body = Jason.encode!(%{
      model: @embedding_model,
      input: text
    })
    
    response = 
      :post
      |> Finch.build(url, headers, body)
      |> Finch.request(Raga.Finch)
    
    case response do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        result = Jason.decode!(body)
        embedding = get_in(result, ["data", Access.at(0), "embedding"])
        {:reply, {:ok, embedding}, state}
      
      {:ok, %Finch.Response{status: status, body: body}} ->
        error = Jason.decode!(body)
        Logger.error("OpenAI API error: #{status} - #{inspect(error)}")
        {:reply, {:error, "OpenAI API error: #{status}"}, state}
      
      {:error, reason} ->
        Logger.error("OpenAI API request failed: #{inspect(reason)}")
        {:reply, {:error, "Failed to connect to OpenAI API"}, state}
    end
  end
end
