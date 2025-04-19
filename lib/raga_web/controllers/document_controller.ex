defmodule RagaWeb.DocumentController do
  use RagaWeb, :controller

  alias Raga.RAG
  alias Raga.RAG.Document

  def index(conn, _params) do
    documents = RAG.list_documents()
    render(conn, :index, documents: documents)
  end

  def new(conn, _params) do
    changeset = Document.changeset(%Document{}, %{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"document" => document_params}) do
    case RAG.create_document(document_params) do
      {:ok, _document} ->
        conn
        |> put_flash(:info, "Document created successfully.")
        |> redirect(to: ~p"/documents")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Error creating document: #{reason}")
        |> redirect(to: ~p"/documents/new")
    end
  end

  def show(conn, %{"id" => id}) do
    document = RAG.get_document_with_chunks(id)
    render(conn, :show, document: document)
  end

  def edit(conn, %{"id" => id}) do
    document = RAG.get_document(id)
    changeset = Document.changeset(document, %{})
    render(conn, :edit, document: document, changeset: changeset)
  end

  def update(conn, %{"id" => id, "document" => document_params}) do
    document = RAG.get_document(id)

    case RAG.update_document(document, document_params) do
      {:ok, document} ->
        conn
        |> put_flash(:info, "Document updated successfully.")
        |> redirect(to: ~p"/documents/#{document}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, document: document, changeset: changeset)
        
      {:error, reason} ->
        conn
        |> put_flash(:error, "Error updating document: #{reason}")
        |> redirect(to: ~p"/documents/#{id}/edit")
    end
  end

  def delete(conn, %{"id" => id}) do
    document = RAG.get_document(id)
    {:ok, _document} = RAG.delete_document(document)

    conn
    |> put_flash(:info, "Document deleted successfully.")
    |> redirect(to: ~p"/documents")
  end
end
