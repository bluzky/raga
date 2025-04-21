defmodule Raga.SessionManager do
  @moduledoc """
  Tracks active conversation sessions and cleans up inactive ones.
  """
  use GenServer
  require Logger
  alias Raga.RAG

  # How often to check and clean up sessions (in ms)
  @cleanup_interval 15_000  # 15 seconds

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Register a session as active
  """
  def register_session(session_id) do
    GenServer.cast(__MODULE__, {:register, session_id})
  end

  @doc """
  Unregister a session (mark as inactive)
  """
  def unregister_session(session_id) do
    GenServer.cast(__MODULE__, {:unregister, session_id})
  end

  @doc """
  Get a list of all active session IDs
  """
  def get_active_sessions do
    GenServer.call(__MODULE__, :get_active_sessions)
  end

  # GenServer callbacks

  @impl true
  def init(_) do
    # Start the cleanup process
    schedule_cleanup()
    
    # Initialize with empty set of active sessions
    {:ok, %{active_sessions: MapSet.new()}}
  end

  @impl true
  def handle_cast({:register, session_id}, %{active_sessions: sessions} = state) do
    {:noreply, %{state | active_sessions: MapSet.put(sessions, session_id)}}
  end

  @impl true
  def handle_cast({:unregister, session_id}, %{active_sessions: sessions} = state) do
    new_sessions = MapSet.delete(sessions, session_id)
    # Clean up immediately when a session is unregistered
    cleanup_inactive_sessions(new_sessions)
    {:noreply, %{state | active_sessions: new_sessions}}
  end

  @impl true
  def handle_call(:get_active_sessions, _from, %{active_sessions: sessions} = state) do
    {:reply, MapSet.to_list(sessions), state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Clean up and reschedule
    cleanup_inactive_sessions(state.active_sessions)
    schedule_cleanup()
    {:noreply, state}
  end

  # Helper functions

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp cleanup_inactive_sessions(active_sessions) do
    active_session_list = MapSet.to_list(active_sessions)
    {count, _} = RAG.delete_inactive_conversations(active_session_list)
    if count > 0 do
      Logger.info("Cleaned up #{count} inactive conversations")
    end
  end
end
