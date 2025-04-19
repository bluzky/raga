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
