defmodule Raga.RAG.Conversation do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "conversations" do
    field :session_id, :string
    field :messages, {:array, :map}, default: []
    field :last_activity, :utc_datetime

    timestamps()
  end

  @doc """
  Changeset for validating and creating/updating conversations
  """
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:session_id, :messages, :last_activity])
    |> validate_required([:session_id, :last_activity])
  end

  @doc """
  Add a new message to the conversation
  """
  def add_message_changeset(conversation, role, content) do
    message = %{
      role: role,
      content: content,
      timestamp: DateTime.utc_now()
    }

    # Get current messages or initialize empty list
    current_messages = conversation.messages || []
    new_messages = current_messages ++ [message]

    conversation
    |> cast(
      %{
        messages: new_messages,
        last_activity: DateTime.utc_now()
      },
      [:messages, :last_activity]
    )
  end

  @doc """
  Returns a query to find a conversation by session_id
  """
  def get_by_session_id_query(session_id) do
    from c in __MODULE__,
      where: c.session_id == ^session_id
  end

  @doc """
  Returns a query to find all conversations except for active session IDs
  """
  def inactive_conversations_query(active_session_ids) do
    from c in __MODULE__,
      where: c.session_id not in ^active_session_ids
  end

  @doc """
  Format messages for LLM context
  """
  def format_messages_for_llm(messages) do
    messages
    |> Enum.map(fn message ->
      %{
        role: message["role"] || message[:role],
        content: message["content"] || message[:content]
      }
    end)
  end
end
