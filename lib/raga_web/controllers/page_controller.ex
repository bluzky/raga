defmodule RagaWeb.PageController do
  use RagaWeb, :controller

  def home(conn, _params) do
    # Redirect to documents list
    redirect(conn, to: ~p"/documents")
  end
end
