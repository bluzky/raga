defmodule RagaWeb.DocumentHTML do
  use RagaWeb, :html

  embed_templates "document_html/*"

  @doc """
  Renders a document form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def document_form(assigns)
end
