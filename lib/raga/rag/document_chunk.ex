defmodule Raga.RAG.DocumentChunk do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  schema "document_chunks" do
    field :content, :string
    field :chunk_index, :integer
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :document, Raga.RAG.Document

    timestamps()
  end

  @doc """
  Changeset for validating and creating/updating document chunks
  """
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:document_id, :content, :chunk_index, :embedding])
    |> validate_required([:document_id, :content, :chunk_index])
    |> foreign_key_constraint(:document_id)
  end

  @doc """
  Query for finding the nearest chunks by vector similarity
  Uses cosine similarity with a lower threshold to find more matches
  """
  def nearest_chunks(embedding, limit \\ 5, similarity_threshold \\ 0.3) do
    # Log the query parameters for debugging
    Logger.debug("Searching for nearest chunks with threshold: #{similarity_threshold}")

    from c in __MODULE__,
      join: d in assoc(c, :document),
      # Calculate cosine similarity (1 - distance)
      select: %{
        document_id: c.document_id,
        document_title: d.title,
        chunk_content: c.content,
        chunk_index: c.chunk_index,
        similarity: fragment("1 - (? <=> ?)::float", c.embedding, ^embedding)
      },
      # Only include results above the similarity threshold
      where: fragment("1 - (? <=> ?)::float", c.embedding, ^embedding) > ^similarity_threshold,
      # Order by cosine similarity (use <=> for cosine distance)
      order_by: [desc: fragment("1 - (? <=> ?)::float", c.embedding, ^embedding)],
      limit: ^limit
  end

  @doc """
  Alternative implementation using L2 distance
  This can be used if the cosine similarity is not working well
  """
  def nearest_chunks_l2(embedding, limit \\ 5) do
    from c in __MODULE__,
      join: d in assoc(c, :document),
      select: %{
        document_id: c.document_id,
        document_title: d.title,
        chunk_content: c.content,
        chunk_index: c.chunk_index,
        # L2 similarity (inverse of distance)
        similarity: fragment("1 - (? <-> ?)::float", c.embedding, ^embedding)
      },
      # Order by L2 distance
      order_by: fragment("? <-> ?", c.embedding, ^embedding),
      limit: ^limit
  end

  @doc """
  Alternative implementation using inner product (dot product)
  Useful for models that work better with dot product similarity
  """
  def nearest_chunks_inner(embedding, limit \\ 5) do
    from c in __MODULE__,
      join: d in assoc(c, :document),
      select: %{
        document_id: c.document_id,
        document_title: d.title,
        chunk_content: c.content,
        chunk_index: c.chunk_index,
        # Inner product (dot product) similarity
        similarity: fragment("? <#> ?", c.embedding, ^embedding)
      },
      # Order by inner product (descending)
      order_by: [desc: fragment("? <#> ?", c.embedding, ^embedding)],
      limit: ^limit
  end
end
