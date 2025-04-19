defmodule RagaWeb.LoadingComponent do
  use Phoenix.Component

  @doc """
  Renders a loading spinner with optional message.
  
  ## Examples
  
      <.loading />
      <.loading message="Processing your query..." />
  """
  attr :message, :string, default: "Loading..."
  attr :class, :string, default: ""
  
  def loading(assigns) do
    ~H"""
    <div class={"flex items-center justify-center p-4 #{@class}"}>
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mr-3"></div>
      <span><%= @message %></span>
    </div>
    """
  end
end
