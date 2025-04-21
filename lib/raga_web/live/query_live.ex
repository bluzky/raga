defmodule RagaWeb.QueryLive do
  use RagaWeb, :live_view

  alias Raga.RAG
  alias Raga.SessionManager

  @impl true
  def mount(_params, session, socket) do
    # Generate a session ID if not present to track conversation
    session_id = Map.get(session, "session_id") || generate_session_id()
    # Get existing conversation messages if any
    conversation_messages = Raga.RAG.get_conversation_messages(session_id)

    # Register this session as active
    SessionManager.register_session(session_id)

    socket =
      socket
      |> assign(
        query_text: "",
        response: nil,
        sources: [],
        loading: false,
        error: nil,
        document_count: get_document_count(),
        session_id: session_id,
        conversation_messages: conversation_messages
      )
      # Store session_id in browser session storage
      |> push_event("store-session", %{session_id: session_id})

    {:ok, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    # When LiveView terminates, unregister the session
    if socket.assigns[:session_id] do
      SessionManager.unregister_session(socket.assigns.session_id)
    end

    :ok
  end

  defp generate_session_id do
    # Generate a random session ID with timestamp to ensure uniqueness
    time_part = System.system_time(:millisecond)
    random_part = :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
    "session_#{time_part}_#{random_part}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="query-interface" class="space-y-8 mb-10" phx-hook="SessionManager">
      <.header>
        RAG Query Interface
        <:subtitle>
          Ask questions about your documents ({@document_count} document{if @document_count != 1,
            do: "s"} available)
        </:subtitle>
        <:actions>
          <.link navigate={~p"/documents"}>
            <.button>Manage Documents</.button>
          </.link>
          <.button phx-click="reset_conversation" class="ml-2" type="button">
            Reset Conversation
          </.button>
        </:actions>
      </.header>

      <div id="conversation-container" class="space-y-6 border rounded-lg p-4">
        <!-- Display conversation history -->
        <%= if @conversation_messages && @conversation_messages != [] do %>
          <div class="space-y-4">
            <h3 class="text-sm font-medium">Conversation History</h3>
            <div class="space-y-4" id="conversation-messages-container" phx-hook="HighlightResponse" phx-update="replace">
              <%= for {message, idx} <- Enum.with_index(@conversation_messages) do %>
                <div class={"p-3 rounded-lg " <> if message["role"] == "user", do: "bg-blue-50 ml-8", else: "bg-green-50 mr-8"}>
                  <div class="font-medium mb-1">
                    {if message["role"] == "user", do: "You", else: "Assistant"}
                  </div>
                  <div id={"message-content-#{idx}"} class="prose max-w-none">
                    {Phoenix.HTML.raw(render_markdown(message["content"]))}
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

    <!-- Question input form -->
        <.simple_form
          for={%{"text" => @query_text}}
          phx-submit="submit"
          id="query-form"
          phx-hook="QueryForm"
        >
          <.input
            name="query[text]"
            value={@query_text}
            type="textarea"
            label={
              if Enum.empty?(@conversation_messages || []),
                do: "Your Question",
                else: "Follow-up Question"
            }
            required
            rows={3}
            phx-debounce="blur"
          />
          <:actions>
            <.button phx-disable-with="Searching..." disabled={@loading}>
              <%= if @loading do %>
                <span class="animate-pulse">Processing...</span>
              <% else %>
                {if Enum.empty?(@conversation_messages || []),
                  do: "Ask Question",
                  else: "Send Follow-up"}
              <% end %>
            </.button>
          </:actions>
        </.simple_form>

        <%= if @error do %>
          <div class="bg-red-50 border border-red-200 text-red-800 rounded-md p-4 mt-6">
            <div class="font-medium">Error</div>
            <div>{@error}</div>
          </div>
        <% end %>

        <%= if @loading do %>
          <div id="loading-section" class="mt-8 border rounded-md overflow-hidden">
            <div class="bg-blue-50 px-4 py-2 border-b font-medium">Processing Query</div>
            <div class="p-4">
              <.loading message="Searching documents and generating response..." />
            </div>
          </div>
        <% end %>

        <%= if @sources && @sources != [] do %>
          <div class="mt-6">
            <h3 class="text-sm font-medium text-gray-500 mb-2">Sources Used</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for source <- @sources do %>
                <div class="border rounded-md p-3 bg-gray-50">
                  <.link
                    navigate={~p"/documents/#{source.id}"}
                    class="font-medium text-blue-600 hover:text-blue-800"
                  >
                    {source.title}
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("submit", %{"query" => %{"text" => query_text}}, socket)
      when query_text != "" do
    socket =
      socket
      |> assign(loading: true, error: nil)
      |> push_event("scroll-to-response", %{})

    # Process the query asynchronously with session_id for context
    send(self(), {:process_query, query_text, socket.assigns.session_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, error: "Please enter a query")}
  end

  @impl true
  def handle_info({:process_query, query_text, session_id}, socket) do
    case RAG.process_query(query_text, session_id) do
      {:ok, %{response: response, sources: sources}} ->
        # Get updated conversation messages after processing
        conversation_messages = RAG.get_conversation_messages(session_id)

        socket =
          socket
          |> assign(
            # Clear the input for next question
            query_text: "",
            sources: sources,
            loading: false,
            conversation_messages: conversation_messages
          )
          |> push_event("highlight-response", %{})

        {:noreply, socket}

      {:error, message} ->
        {:noreply, assign(socket, loading: false, error: message)}
    end
  end

  @impl true
  def handle_event("reset_conversation", _params, socket) do
    # Unregister the old session
    if socket.assigns[:session_id] do
      SessionManager.unregister_session(socket.assigns.session_id)
    end

    # Generate a new session ID
    new_session_id = generate_session_id()

    # Register the new session
    SessionManager.register_session(new_session_id)

    socket =
      socket
      |> assign(
        session_id: new_session_id,
        conversation_messages: [],
        query_text: "",
        response: nil,
        sources: [],
        error: nil
      )
      |> push_event("store-session", %{session_id: new_session_id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("restore_session", %{"session_id" => session_id}, socket) do
    # Unregister old session if exists
    if socket.assigns[:session_id] do
      SessionManager.unregister_session(socket.assigns.session_id)
    end

    # Register the restored session
    SessionManager.register_session(session_id)

    # Get conversation messages for the restored session
    conversation_messages = RAG.get_conversation_messages(session_id)

    socket =
      assign(socket,
        session_id: session_id,
        conversation_messages: conversation_messages
      )

    {:noreply, socket}
  end

  # Helper function to render markdown as HTML
  defp render_markdown(markdown_text) do
    # Configure Earmark with code syntax highlighting
    opts = %Earmark.Options{
      code_class_prefix: "language-",
      gfm: true,
      breaks: true,
      smartypants: false
    }
    
    case Earmark.as_html(markdown_text, opts) do
      {:ok, html, _} ->
        html
        
      {:error, _html, error_messages} ->
        # Log errors but still show the original markdown as fallback
        require Logger
        Logger.error("Markdown rendering error: #{inspect(error_messages)}")
        "<pre>#{escape_html(markdown_text)}</pre>"
    end
  end

  
  # Escape HTML to prevent XSS in fallback rendering
  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp get_document_count do
    length(RAG.list_documents())
  end
end
