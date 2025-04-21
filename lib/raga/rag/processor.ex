defmodule Raga.RAG.Processor do
  @moduledoc """
  Module for processing documents and queries for the RAG system
  """

  import Ecto.Query, only: [where: 3, select: 3]
  alias Raga.Repo
  alias Raga.RAG.{Document, DocumentChunk, Query}
  alias Raga.Ollama.Client, as: OllamaClient
  alias Raga.Groq.Client, as: GroqClient
  require Logger

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
  def process_document(params) do
    # Handle both string and atom keys
    title = params["title"] || params[:title]
    content = params["content"] || params[:content]

    unless title && content do
      {:error, "Title and content are required"}
    else
      # Start transaction to ensure all parts succeed or fail together
      # Create document record
      {:ok, document} =
        %Document{}
        |> Document.changeset(%{title: title, content: content})
        |> Repo.insert()

      IO.inspect("Complete inserting")

      # Split content into chunks
      chunks = split_into_chunks(content)

      Logger.info("Processing document: #{title} with #{length(chunks)} chunks")

      # Process each chunk
      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        case OllamaClient.generate_embeddings(chunk.text) do
          {:ok, embedding} ->
            # Log the embedding dimensions for debugging
            Logger.debug("Generated embedding with #{length(embedding)} dimensions")

            # Create chunk with embedding
            %DocumentChunk{}
            |> DocumentChunk.changeset(%{
              document_id: document.id,
              content: chunk.text,
              chunk_index: index,
              embedding: embedding
            })
            |> Repo.insert!()

          {:error, reason} ->
            # Raise to rollback transaction
            Logger.error("Failed to generate embeddings: #{inspect(reason)}")
            raise "Failed to generate embeddings: #{reason}"
        end
      end)

      # Return the document
      {:ok, document}
    end
  end

  @doc """
  Process a query using Approach 2 (Tool-based):
  1. Send query directly to GROQ LLM with tool capabilities
  2. LLM decides if it needs to search the knowledge base
  3. If search is used, relevant documents are retrieved
  4. LLM generates final response with citations if applicable
  """
  def process_query(query_text, session_id \\ nil) do
    approach = Application.get_env(:raga, :rag_approach)[:type] || :tool_based
    
    case approach do
      :tool_based ->
        process_query_tool_based(query_text, session_id)
      :pre_retrieval ->
        process_query_old_approach(query_text, session_id)
    end
  end
  
  defp process_query_tool_based(query_text, session_id) do
    Logger.info(
      "Processing query (Approach 2): #{query_text}, session_id: #{session_id || "none"}"
    )

    # Get or create conversation and add user message first
    conversation_history =
      if session_id do
        # Get or create conversation
        {:ok, conversation} = Raga.RAG.get_or_create_conversation(session_id)
        
        # Add user message to conversation first, so it's available in the UI
        {:ok, updated_conversation} = Raga.RAG.add_message_to_conversation(conversation, "user", query_text)

        # Format conversation history for LLM
        Raga.RAG.Conversation.format_messages_for_llm(updated_conversation.messages)
      else
        []
      end

    # Generate response from Groq with tool support
    case GroqClient.generate_response(query_text, conversation_history) do
      {:ok, response, tool_sources} ->
        # New 3-tuple response with tool sources
        handle_response_with_sources(response, tool_sources, query_text, session_id)
        
      {:ok, response} ->
        # Legacy 2-tuple response (no tools used)
        handle_response_with_sources(response, nil, query_text, session_id)

      {:error, reason} ->
        Logger.error("Failed to generate response: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_response_with_sources(response, tool_sources, query_text, session_id) do
    # Generate embedding for the query for saving
    {:ok, embedding} = OllamaClient.generate_embeddings(query_text)

    # Save query and response
    {:ok, query} =
      %Query{}
      |> Query.changeset(%{
        query_text: query_text,
        response: response,
        embedding: embedding
      })
      |> Repo.insert()

    # Add assistant response to conversation (user message already added)
    if session_id do
      {:ok, conversation} = Raga.RAG.get_or_create_conversation(session_id)
      {:ok, _} = Raga.RAG.add_message_to_conversation(conversation, "assistant", response)
    end

    # Extract unique sources from tool usage
    sources = process_tool_sources(tool_sources)

    {:ok,
     %{
       response: response,
       sources: sources,
       conversation_id: session_id
     }}
  end

  @doc """
  Process a query using the old approach (Approach 1) for backward compatibility:
  1. Generating embedding for the query using Ollama
  2. Finding relevant document chunks
  3. Generating a response using the Groq LLM, including conversation context if provided
  4. Saving the query, response, and conversation context
  """
  def process_query_old_approach(query_text, session_id \\ nil) do
    Logger.info(
      "Processing query (Approach 1): #{query_text}, session_id: #{session_id || "none"}"
    )

    # Generate embedding for the query using Ollama
    case OllamaClient.generate_embeddings(query_text) do
      {:ok, embedding} ->
        Logger.debug("Generated query embedding with #{length(embedding)} dimensions")

        # Find most relevant chunks with a lower similarity threshold
        chunks =
          embedding
          |> DocumentChunk.nearest_chunks(5)
          |> Repo.all()

        Logger.info("Found #{length(chunks)} relevant chunks")

        if Enum.empty?(chunks) do
          Logger.warn("No relevant documents found for query: #{query_text}")
          {:error, "No relevant documents found"}
        else
          # Log the similarities for debugging
          chunks
          |> Enum.each(fn %{document_title: title, similarity: similarity} ->
            Logger.debug("Chunk from '#{title}' with similarity: #{similarity}")
          end)

          # Get conversation history if session_id is provided
          conversation_history =
            if session_id do
              # Get or create conversation
              {:ok, conversation} = Raga.RAG.get_or_create_conversation(session_id)

              # Add user message to conversation first
              {:ok, updated_conversation} =
                Raga.RAG.add_message_to_conversation(conversation, "user", query_text)

              # Format conversation history for LLM
              Raga.RAG.Conversation.format_messages_for_llm(updated_conversation.messages)
            else
              # No conversation context
              [%{role: "user", content: query_text}]
            end

          # Generate response from Groq with conversation history
          case GroqClient.generate_response(query_text, chunks, conversation_history) do
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

              # If we have a session, add assistant response to conversation
              if session_id do
                {:ok, conversation} = Raga.RAG.get_or_create_conversation(session_id)

                {:ok, _} =
                  Raga.RAG.add_message_to_conversation(conversation, "assistant", response)
              end

              {:ok,
               %{
                 response: response,
                 sources: extract_sources(chunks),
                 conversation_id: session_id
               }}

            {:error, reason} ->
              Logger.error("Failed to generate response: #{inspect(reason)}")
              {:error, reason}
          end
        end

      {:error, reason} ->
        Logger.error("Failed to generate query embedding: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Split text into overlapping chunks
  """
  def split_into_chunks(text) do
    TextChunker.split(text, chunk_size: @chunk_size, chunk_overlap: @chunk_overlap)
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

  @doc """
  Process tool sources to find document IDs
  """
  defp process_tool_sources(nil), do: []

  defp process_tool_sources(tool_sources) do
    # Fetch document info based on titles from tool sources
    titles = Enum.map(tool_sources, & &1.title)

    Document
    |> where([d], d.title in ^titles)
    |> select([d], %{id: d.id, title: d.title})
    |> Repo.all()
  end
end
