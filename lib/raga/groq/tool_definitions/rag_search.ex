defmodule Raga.Groq.ToolDefinitions.RagSearch do
  @moduledoc """
  Defines the RAG search tool that can be used by GROQ LLM
  """

  @tool_definition %{
    type: "function",
    function: %{
      name: "search_knowledge_base",
      description: """
      Search the knowledge base for information related to the query.
      Use this tool when the user asks questions that might require specific information from documents.
      This will perform a semantic search and retrieve relevant document chunks.
      """,
      parameters: %{
        type: "object",
        properties: %{
          query: %{
            type: "string",
            description: "The search query to find relevant information"
          },
          num_results: %{
            type: "integer",
            description: "Number of results to retrieve (default: 5)",
            default: 5
          }
        },
        required: ["query"]
      }
    }
  }

  def get_tool_definition, do: @tool_definition

  def execute(params) do
    query = params["query"]
    num_results = params["num_results"] || 5

    # Generate embedding for the query
    case Raga.Ollama.Client.generate_embeddings(query) do
      {:ok, embedding} ->
        # Find relevant chunks
        chunks =
          embedding
          |> Raga.RAG.DocumentChunk.nearest_chunks(num_results)
          |> Raga.Repo.all()

        # Format results for the LLM
        results = format_search_results(chunks)
        {:ok, results}

      {:error, reason} ->
        {:error, "Failed to search knowledge base: #{reason}"}
    end
  end

  defp format_search_results(chunks) do
    chunks
    |> Enum.map(fn %{document_title: title, chunk_content: content, similarity: similarity} ->
      %{
        title: title,
        content: content,
        relevance: Float.round(similarity * 100, 2)
      }
    end)
  end
end
