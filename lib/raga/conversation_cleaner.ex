defmodule Raga.ConversationCleaner do
  @moduledoc """
  A GenServer that periodically checks for orphaned conversations and cleans them up.
  This is a safety net in case some conversations aren't properly cleaned by the SessionManager.
  """
  use GenServer
  require Logger
  alias Raga.RAG
  alias Raga.SessionManager

  # Run every 30 minutes by default
  @default_interval 30 * 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Get interval from options or use default
    interval = Keyword.get(opts, :interval, @default_interval)
    
    # Schedule periodic cleanup
    schedule_cleanup(interval)
    
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:cleanup, %{interval: interval} = state) do
    cleanup()
    schedule_cleanup(interval)
    {:noreply, state}
  end

  defp cleanup do
    # Get active sessions from the SessionManager
    active_sessions = SessionManager.get_active_sessions()
    
    # Delete all conversations except active ones
    {count, _} = RAG.delete_inactive_conversations(active_sessions)
    
    if count > 0 do
      Logger.info("Cleaned up #{count} orphaned conversations")
    end
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
