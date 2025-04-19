defmodule Raga.Repo.Migrations.CreateDocumentChunks do
  use Ecto.Migration

  def change do
    create table(:document_chunks) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :chunk_index, :integer, null: false
      add :embedding, :vector, size: 1536  # Groq embeddings are 1536 dimensions

      timestamps()
    end

    create index(:document_chunks, [:document_id])
    # Add vector index for similarity search
    execute "CREATE INDEX document_chunks_embedding_idx ON document_chunks USING ivfflat (embedding vector_l2_ops) WITH (lists = 100)"
  end
end
