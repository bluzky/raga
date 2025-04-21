defmodule Raga.RAG do
  @moduledoc """
  The RAG context for Retrieval-Augmented Generation functionality
  Supports both Approach 1 (pre-retrieval) and Approach 2 (tool-based)
  """

  import Ecto.Query
  alias Raga.Repo
  alias Raga.RAG.{Document, DocumentChunk, Query, Processor, Conversation}

  @doc """
  Lists all documents with their chunk count
  """
  def list_documents do
    Document
    |> preload(:chunks)
    |> Repo.all()
    |> Enum.map(fn doc ->
      Map.put(doc, :chunk_count, length(doc.chunks))
    end)
  end

  @doc """
  Gets a single document without preloaded chunks
  """
  def get_document(id) do
    Repo.get(Document, id)
  end

  @doc """
  Gets a single document with preloaded chunks (raises if not found)
  """
  def get_document!(id) do
    Document
    |> Repo.get!(id)
    |> Repo.preload(:chunks)
  end

  @doc """
  Gets a single document with preloaded chunks (alias for get_document!)
  """
  def get_document_with_chunks(id) do
    get_document!(id)
  end

  @doc """
  Creates a document and processes it for RAG
  """
  def create_document(attrs \\ %{}) do
    Processor.process_document(attrs)
  end

  @doc """
  Updates a document and reprocesses it for RAG
  """
  def update_document(%Document{} = document, attrs) do
    Repo.transaction(fn ->
      # Delete existing chunks
      from(c in DocumentChunk, where: c.document_id == ^document.id)
      |> Repo.delete_all()

      # Update the document
      {:ok, updated_document} =
        document
        |> Document.changeset(attrs)
        |> Repo.update()

      # Reprocess chunks
      {:ok, _} =
        Processor.process_document(%{
          title: updated_document.title,
          content: updated_document.content
        })

      updated_document
    end)
  end

  @doc """
  Deletes a document and all associated chunks
  """
  def delete_document(%Document{} = document) do
    Repo.delete(document)
  end

  @doc """
  Lists recent queries with their responses
  """
  def list_queries(limit \\ 10) do
    Query.all_ordered_query()
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Processes a query using either Approach 1 or Approach 2 based on configuration
  """
  def process_query(query_text, session_id \\ nil) do
    Processor.process_query(query_text, session_id)
  end

  @doc """
  Gets or creates a conversation by session_id
  """
  def get_or_create_conversation(session_id) do
    case Repo.get_by(Conversation, session_id: session_id) do
      nil ->
        %Conversation{}
        |> Conversation.changeset(%{
          session_id: session_id,
          messages: [],
          last_activity: NaiveDateTime.utc_now()
        })
        |> Repo.insert()

      conversation ->
        {:ok, conversation}
    end
  end

  @doc """
  Adds a message to a conversation
  """
  def add_message_to_conversation(%Conversation{} = conversation, role, content) do
    messages = conversation.messages || []
    new_message = %{"role" => role, "content" => content}
    updated_messages = messages ++ [new_message]

    conversation
    |> Conversation.changeset(%{messages: updated_messages})
    |> Repo.update()
  end

  @doc """
  Gets conversation messages for a session ID
  """
  def get_conversation_messages(session_id) do
    case Repo.get_by(Conversation, session_id: session_id) do
      nil -> []
      conversation -> conversation.messages || []
    end
  end

  @doc """
  Clears all messages from a conversation
  """
  def clear_conversation(%Conversation{} = conversation) do
    conversation
    |> Conversation.changeset(%{messages: []})
    |> Repo.update()
  end

  @doc """
  Returns the current RAG approach configuration
  """
  def get_current_approach do
    Application.get_env(:raga, :rag_approach)[:type] || :tool_based
  end

  @doc """
  Deletes inactive conversations based on provided session list
  """
  def delete_inactive_conversations(active_sessions) do
    from(c in Conversation,
      where: c.session_id not in ^active_sessions
    )
    |> Repo.delete_all()
  end
end
