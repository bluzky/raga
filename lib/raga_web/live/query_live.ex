defmodule RagaWeb.QueryLive do
  use RagaWeb, :live_view
  
  alias Raga.RAG
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, 
      query_text: "",
      response: nil,
      sources: [],
      loading: false,
      error: nil,
      document_count: get_document_count()
    )}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div id="query-interface" class="space-y-8 mb-10">
      <.header>
        RAG Query Interface
        <:subtitle>
          Ask questions about your documents (<%= @document_count %> document<%= if @document_count != 1, do: "s" %> available)
        </:subtitle>
        <:actions>
          <.link navigate={~p"/documents"}>
            <.button>Manage Documents</.button>
          </.link>
        </:actions>
      </.header>

      <.simple_form for={%{"text" => @query_text}} phx-submit="submit" id="query-form" phx-hook="QueryForm">
        <.input name="query[text]" value={@query_text} type="textarea" label="Your Question" required rows={3} phx-debounce="blur" />
        <:actions>
          <.button phx-disable-with="Searching..." disabled={@loading}>
            <%= if @loading do %>
              <span class="animate-pulse">Processing...</span>
            <% else %>
              Ask Question
            <% end %>
          </.button>
        </:actions>
      </.simple_form>

      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 text-red-800 rounded-md p-4 mt-6">
          <div class="font-medium">Error</div>
          <div><%= @error %></div>
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

      <%= if @response do %>
        <div id="response-section" class="mt-8 border rounded-md overflow-hidden">
          <div class="bg-green-50 px-4 py-2 border-b font-medium">Response</div>
          <div class="p-4 prose max-w-none" id="response-content" phx-hook="HighlightResponse">
            <%= for line <- String.split(@response, "\n") do %>
              <p><%= line %></p>
            <% end %>
          </div>
        </div>

        <%= if @sources && @sources != [] do %>
          <div class="mt-6">
            <h3 class="text-sm font-medium text-gray-500 mb-2">Sources Used</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for source <- @sources do %>
                <div class="border rounded-md p-3 bg-gray-50">
                  <.link navigate={~p"/documents/#{source.id}"} class="font-medium text-blue-600 hover:text-blue-800">
                    <%= source.title %>
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
  
  @impl true
  def handle_event("submit", %{"query" => %{"text" => query_text}}, socket) when query_text != "" do
    socket = 
      socket
      |> assign(loading: true, error: nil)
      |> push_event("scroll-to-response", %{})
      
    # Process the query asynchronously
    send(self(), {:process_query, query_text})
    
    {:noreply, socket}
  end
  
  @impl true
  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, error: "Please enter a query")}
  end
  
  @impl true
  def handle_info({:process_query, query_text}, socket) do
    case RAG.process_query(query_text) do
      {:ok, %{response: response, sources: sources}} ->
        socket = 
          socket
          |> assign(
            query_text: query_text, 
            response: response, 
            sources: sources,
            loading: false
          )
          |> push_event("highlight-response", %{})
        
        {:noreply, socket}
        
      {:error, message} ->
        {:noreply, assign(socket, loading: false, error: message)}
    end
  end
  
  defp get_document_count do
    length(RAG.list_documents())
  end
end
