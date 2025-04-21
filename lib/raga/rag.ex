defmodule Raga.RAG do
  @moduledoc """
  The RAG context - provides functions for managing documents and queries
  """

  import Ecto.Query, warn: false
  require Logger
  
  alias Raga.Repo
  alias Raga.RAG.{Document, DocumentChunk, Query, Processor, Conversation}

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
      
      # Re-process document with the new content
      attrs = %{
        "title" => attrs["title"] || attrs[:title] || document.title,
        "content" => attrs["content"] || attrs[:content] || document.content
      }
      
      # Split content into chunks
      chunks = Processor.split_into_chunks(attrs["content"])
      
      # Process each chunk
      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk_content, index} ->
        case Raga.Ollama.Client.generate_embeddings(chunk_content) do
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
  If session_id is provided, maintains conversation context.
  """
  def process_query(query_text, session_id \\ nil) do
    Processor.process_query(query_text, session_id)
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
  
  @doc """
  Search for text directly in document content (without embeddings)
  This is useful for debugging when vector similarity search isn't working
  """
  def search_document_content(search_text) do
    from(d in Document,
      where: ilike(d.content, ^"%#{search_text}%"),
      select: %{id: d.id, title: d.title, excerpt: fragment("substring(? from position(? in ?) - 50 for 200)", d.content, ^search_text, d.content)}
    )
    |> Repo.all()
  end
  
  @doc """
  Get the total count of document chunks
  """
  def count_document_chunks do
    Repo.aggregate(DocumentChunk, :count, :id)
  end
  
  @doc """
  Debug function to test various vector search methods
  """
  # Conversation functions

  @doc """
  Gets a conversation by session_id or creates a new one
  """
  def get_or_create_conversation(session_id) do
    case Repo.one(Conversation.get_by_session_id_query(session_id)) do
      nil ->
        # Create new conversation
        %Conversation{}
        |> Conversation.changeset(%{
          session_id: session_id,
          last_activity: DateTime.utc_now(),
          messages: []
        })
        |> Repo.insert()
      
      conversation ->
        # Update last activity time
        conversation
        |> Conversation.changeset(%{last_activity: DateTime.utc_now()})
        |> Repo.update()
    end
  end

  @doc """
  Adds a message to a conversation
  """
  def add_message_to_conversation(conversation, role, content) do
    conversation
    |> Conversation.add_message_changeset(role, content)
    |> Repo.update()
  end

  @doc """
  Deletes all conversations except for the provided active session IDs
  """
  def delete_inactive_conversations(active_session_ids) do
    Conversation.inactive_conversations_query(active_session_ids || [])
    |> Repo.delete_all()
  end

  @doc """
  Gets all messages for a conversation
  """
  def get_conversation_messages(session_id) do
    case Repo.one(Conversation.get_by_session_id_query(session_id)) do
      nil -> []
      conversation -> conversation.messages || []
    end
  end

  def debug_vector_search(query_text) do
    Logger.info("Debug vector search for: #{query_text}")
    
    case Raga.Ollama.Client.generate_embeddings(query_text) do
      {:ok, embedding} ->
        # Try different similarity methods
        
        # 1. Cosine similarity (default)
        cosine_results = 
          embedding
          |> DocumentChunk.nearest_chunks(5, 0.1) # Lower threshold
          |> Repo.all()
          
        # 2. L2 distance
        l2_results =
          embedding
          |> DocumentChunk.nearest_chunks_l2(5)
          |> Repo.all()
          
        # 3. Inner product
        inner_results =
          embedding
          |> DocumentChunk.nearest_chunks_inner(5)
          |> Repo.all()
          
        # 4. Direct text search (fallback)
        text_results = search_document_content(query_text)
        
        Logger.info("Query '#{query_text}' results:")
        Logger.info("- Cosine similarity: #{length(cosine_results)} results")
        Logger.info("- L2 distance: #{length(l2_results)} results")
        Logger.info("- Inner product: #{length(inner_results)} results")
        Logger.info("- Text search: #{length(text_results)} results")
        
        # Return all results for comparison
        %{
          query: query_text,
          cosine_results: cosine_results,
          l2_results: l2_results,
          inner_results: inner_results,
          text_results: text_results
        }
        
      {:error, reason} ->
        Logger.error("Failed to generate embedding: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
