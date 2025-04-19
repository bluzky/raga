# Raga - Retrieval-Augmented Generation System

A Phoenix application that demonstrates Retrieval-Augmented Generation (RAG) using Phoenix, PostgreSQL with pgvector, and the Groq API.

## Core Technologies

- Phoenix/Elixir for the web framework
- PostgreSQL with pgvector extension for vector storage
- Groq API for LLM responses

## Features

1. **Document Management:**
   - List documents (simple table view)
   - Add new text documents
   - Delete documents
   - Edit document content and title
   
2. **RAG Query Interface:**
   - Text input field for queries
   - Vector similarity search against stored documents
   - Response generation using retrieved context
   - Display response with source references

## Setup

### Prerequisites

1. Elixir and Erlang installed
2. PostgreSQL with pgvector extension
3. A Groq API key

### PostgreSQL with pgvector

To install pgvector:

```bash
# On Ubuntu/Debian
sudo apt-get install postgresql-server-dev-all
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install
```

Then connect to PostgreSQL and enable the extension:

```sql
CREATE EXTENSION vector;
```

### Application Setup

1. Clone the repository

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Set up your Groq API key:

   ```bash
   export GROQ_API_KEY=your_actual_api_key
   ```

4. Configure database in `config/dev.exs` if needed

5. Create and migrate the database:
   ```bash
   mix ecto.setup
   ```

6. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

7. Visit [`localhost:4000`](http://localhost:4000) in your browser to use the application

## Usage

### Managing Documents

1. Add documents through the `/documents/new` page
2. Each document will be chunked and embedded automatically
3. You can view, edit, or delete documents from the document list

### Querying Documents

1. Go to the query interface at `/query`
2. Enter your question in the text field
3. The system will:
   - Process your query
   - Perform a similarity search to find relevant document chunks
   - Send the query and retrieved context to Groq API
   - Display the response with source documents

## System Architecture

1. **Database:**
   - Schema for documents (id, title, content, date)
   - Schema for embeddings (id, document_id, embedding_vector)
   - pgvector setup for vector similarity

2. **Groq API Integration:**
   - HTTP client to call Groq API
   - Text processing for queries and responses

3. **Phoenix Components:**
   - Controllers and views for document management
   - LiveView for the query interface
   - Simple responsive UI

4. **Helper Modules:**
   - Document chunking logic
   - Vector similarity calculation
   - Context preparation for LLM

## Implementation Notes

This implementation uses a deterministic vector generation approach for text embeddings since Groq doesn't currently have a dedicated embeddings API. In a production system, you would typically use a dedicated embeddings API from providers like OpenAI, Cohere, or others.

## Limitations

This is a learning project and has the following limitations:

- No authentication or user management
- Limited error handling
- Simple embedding generation (not using a true embedding model)
