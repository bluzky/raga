defmodule Raga.RAG do
  @moduledoc """
  The RAG context - provides functions for managing documents and queries
  """

  import Ecto.Query, warn: false
  
  alias Raga.Repo
  alias Raga.RAG.{Document, DocumentChunk, Query, Processor}

  # Document functions

  @doc """
  Returns the list of documents.
  """
  def list_documents do
    Document.all_ordered_query()
    |> Repo.all()
  end

  @doc """
  Gets a single document.
  """
  def get_document(id) do
    Repo.get(Document, id)
  end

  @doc """
  Gets a single document with associated chunks.
  """
  def get_document_with_chunks(id) do
    Document
    |> Repo.get(id)
    |> Repo.preload(chunks: from(c in DocumentChunk, order_by: c.chunk_index))
  end

  @doc """
  Creates a document with content processing.
  """
  def create_document(attrs \\ %{}) do
    Processor.process_document(attrs)
  end

  @doc """
  Updates a document.
  
  This will delete all existing chunks and re-process the document.
  """
  def update_document(%Document{} = document, attrs) do
    Repo.transaction(fn ->
      # Delete existing chunks
      from(c in DocumentChunk, where: c.document_id == ^document.id)
      |> Repo.delete_all()
      
      # Update document
      document
      |> Document.changeset(attrs)
      |> Repo.update!()
      
      # Re-process document
      attrs = Map.merge(%{title: document.title, content: document.content}, attrs)
      
      # Split content into chunks
      chunks = Processor.split_into_chunks(attrs.content)
      
      # Process each chunk
      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk_content, index} ->
        case Raga.Groq.Client.generate_embeddings(chunk_content) do
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

      # Return the updated document
      Repo.get(Document, document.id)
    end)
  end

  @doc """
  Deletes a document.
  
  This will cascade delete all associated chunks.
  """
  def delete_document(%Document{} = document) do
    Repo.delete(document)
  end

  # Query functions

  @doc """
  Process a query and return the response.
  """
  def process_query(query_text) do
    Processor.process_query(query_text)
  end

  @doc """
  Returns the list of recent queries.
  """
  def list_recent_queries(limit \\ 10) do
    Query.all_ordered_query()
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets a single query.
  """
  def get_query(id) do
    Repo.get(Query, id)
  end
end
