defmodule Raga.RAG.Query do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "queries" do
    field :query_text, :string
    field :response, :string
    field :embedding, Pgvector.Ecto.Vector

    timestamps()
  end

  @doc """
  Changeset for validating and creating/updating queries
  """
  def changeset(query, attrs) do
    query
    |> cast(attrs, [:query_text, :response, :embedding])
    |> validate_required([:query_text, :response])
  end

  @doc """
  Returns a query for getting all queries ordered by their creation date
  """
  def all_ordered_query do
    from q in __MODULE__,
      order_by: [desc: q.inserted_at]
  end
end
