defmodule Raga.RAG.Processor do
  @moduledoc """
  Module for processing documents and queries for the RAG system
  """

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
  Process a query by:
  1. Generating embedding for the query using Ollama
  2. Finding relevant document chunks
  3. Generating a response using the Groq LLM, including conversation context if provided
  4. Saving the query, response, and conversation context
  """
  def process_query(query_text, session_id \\ nil) do
    Logger.info("Processing query: #{query_text}, session_id: #{session_id || "none"}")

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
          conversation_history = if session_id do
            # Get or create conversation
            {:ok, conversation} = Raga.RAG.get_or_create_conversation(session_id)
            
            # Add user message to conversation
            {:ok, conversation} = Raga.RAG.add_message_to_conversation(conversation, "user", query_text)
            
            # Format conversation history for LLM
            Raga.RAG.Conversation.format_messages_for_llm(conversation.messages)
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
                {:ok, _} = Raga.RAG.add_message_to_conversation(conversation, "assistant", response)
              end

              {:ok, %{
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
end
