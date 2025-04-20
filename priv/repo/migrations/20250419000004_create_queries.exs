defmodule Raga.Repo.Migrations.CreateQueries do
  use Ecto.Migration

  def change do
    create table(:queries) do
      add :query_text, :text, null: false
      add :response, :text, null: false
      add :embedding, :vector, size: 768

      timestamps()
    end

    # Add vector index for similarity search (in case we want to find similar queries)
    execute "CREATE INDEX queries_embedding_idx ON queries USING ivfflat (embedding vector_l2_ops) WITH (lists = 100)"
  end
end
