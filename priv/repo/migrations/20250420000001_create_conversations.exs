defmodule Raga.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :session_id, :string, null: false
      add :messages, {:array, :map}, default: []
      add :last_activity, :utc_datetime, null: false

      timestamps()
    end

    create index(:conversations, [:session_id])
    create index(:conversations, [:last_activity])
  end
end
