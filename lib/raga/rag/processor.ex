defmodule Raga.RAG.Processor do
  @moduledoc """
  Module for processing documents and queries for the RAG system
  """

  alias Raga.Repo
  alias Raga.RAG.{Document, DocumentChunk, Query}
  alias Raga.Ollama.Client, as: OllamaClient
  alias Raga.Groq.Client, as: GroqClient

  @doc """
  Chunk size in characters for splitting documents
  Overlap helps maintain context between chunks
  """
  @chunk_size 1000
  @chunk_overlap 200

  @doc """
  Process a document by:
  1. Creating document record
  2. Splitting content into chunks
  3. Generating embeddings for each chunk using Ollama
  4. Saving chunks with embeddings
  """
  def process_document(%{"title" => title, "content" => content}) do
    # Start transaction to ensure all parts succeed or fail together

    Repo.transaction(fn ->
      # Create document record
      {:ok, document} =
        %Document{}
        |> Document.changeset(%{title: title, content: content})
        |> Repo.insert()

      # Split content into chunks
      chunks = split_into_chunks(content)

      # Process each chunk
      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk_content, index} ->
        case OllamaClient.generate_embeddings(chunk_content) do
          {:ok, embedding} ->
            # Create chunk with embedding
            %DocumentChunk{}
            |> DocumentChunk.changeset(%{
              document_id: document.id,
              content: chunk_content,
              chunk_index: index,
              embedding: embedding
            })
            |> Repo.insert!()

          {:error, reason} ->
            # Raise to rollback transaction
            raise "Failed to generate embeddings: #{reason}"
        end
      end)

      # Return the document
      document
    end)
  end

  @doc """
  Process a query by:
  1. Generating embedding for the query using Ollama
  2. Finding relevant document chunks
  3. Generating a response using the Groq LLM
  4. Saving the query and response
  """
  def process_query(query_text) do
    # Generate embedding for the query using Ollama
    case OllamaClient.generate_embeddings(query_text) do
      {:ok, embedding} ->
        # Find most relevant chunks
        chunks =
          embedding
          |> DocumentChunk.nearest_chunks(5)
          |> Repo.all()

        if Enum.empty?(chunks) do
          {:error, "No relevant documents found"}
        else
          # Generate response from Groq
          case GroqClient.generate_response(query_text, chunks) do
            {:ok, response} ->
              # Save query and response
              {:ok, query} =
                %Query{}
                |> Query.changeset(%{
                  query_text: query_text,
                  response: response,
                  embedding: embedding
                })
                |> Repo.insert()

              {:ok, %{response: response, sources: extract_sources(chunks)}}

            {:error, reason} ->
              {:error, reason}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Split text into overlapping chunks
  """
  def split_into_chunks(text) do
    # Split by paragraphs first to try to keep coherent chunks
    paragraphs = String.split(text, ~r/\n\s*\n/)

    build_chunks(paragraphs, "", [], @chunk_size, @chunk_overlap)
  end

  # Helper function to recursively build chunks
  defp build_chunks([], current_chunk, chunks, _, _) do
    # Add the last chunk if it's not empty
    if current_chunk != "", do: chunks ++ [current_chunk], else: chunks
  end

  defp build_chunks([paragraph | rest], current_chunk, chunks, chunk_size, chunk_overlap) do
    # If adding this paragraph would exceed the chunk size, start a new chunk
    new_chunk = if current_chunk == "", do: paragraph, else: current_chunk <> "\n\n" <> paragraph

    if String.length(new_chunk) > chunk_size do
      overlap = String.slice(current_chunk, -chunk_overlap..-1)

      build_chunks(
        [paragraph | rest],
        overlap,
        chunks ++ [current_chunk],
        chunk_size,
        chunk_overlap
      )
    else
      build_chunks(rest, new_chunk, chunks, chunk_size, chunk_overlap)
    end
  end

  @doc """
  Extract unique document sources from chunks
  """
  defp extract_sources(chunks) do
    chunks
    |> Enum.map(fn %{document_id: id, document_title: title} ->
      %{id: id, title: title}
    end)
    |> Enum.uniq_by(fn %{id: id} -> id end)
  end
end
