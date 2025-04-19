defmodule Raga.RAG.Document do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "documents" do
    field :title, :string
    field :content, :string
    has_many :chunks, Raga.RAG.DocumentChunk

    timestamps()
  end

  @doc """
  Changeset for validating and creating/updating documents
  """
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:title, :content])
    |> validate_required([:title, :content])
  end

  @doc """
  Returns a query for getting all documents ordered by their creation date
  """
  def all_ordered_query do
    from d in __MODULE__,
      order_by: [desc: d.inserted_at]
  end
end
