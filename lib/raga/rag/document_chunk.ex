defmodule Raga.RAG.DocumentChunk do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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
  """
  def nearest_chunks(embedding, limit \\ 5) do
    from c in __MODULE__,
      join: d in assoc(c, :document),
      select: %{
        document_id: c.document_id,
        document_title: d.title,
        chunk_content: c.content,
        similarity: fragment("1 - (? <-> ?)::float", c.embedding, ^embedding)
      },
      order_by: fragment("? <-> ?", c.embedding, ^embedding),
      limit: ^limit
  end
end
