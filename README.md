# Raga - Retrieval-Augmented Generation System

A Phoenix application that demonstrates Retrieval-Augmented Generation (RAG) using Phoenix, PostgreSQL with pgvector, local Ollama embeddings, and the Groq API. 

Now supports two approaches:
- **Approach 1 (Pre-retrieval)**: Always retrieves context before querying the LLM
- **Approach 2 (Tool-based)**: LLM decides when to access the knowledge base

## Core Technologies

- Phoenix/Elixir for the web framework
- PostgreSQL with pgvector extension for vector storage
- Ollama with nomic-embed-text for local embedding generation
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

3. **Flexible RAG Approaches:**
   - **Approach 1**: Pre-retrieval (traditional RAG)
   - **Approach 2**: Tool-based (LLM-driven retrieval)

## RAG Approaches

### Approach 1: Pre-retrieval (Traditional RAG)
1. User query → Generate embedding → Search similar documents → Send context + query to LLM → Response
2. Always performs retrieval regardless of query type
3. Simpler architecture with lower latency

### Approach 2: Tool-based (LLM-Driven)
1. User query → LLM evaluates if it needs additional context → If needed, calls search_knowledge_base function → Retrieves information → Generates response
2. More flexible - LLM decides when retrieval is necessary
3. Can handle general queries without retrieval and complex queries with multiple retrievals

You can switch between approaches in `config/config.exs`:

```elixir
# Choose between :tool_based (Approach 2) or :pre_retrieval (Approach 1)
config :raga, :rag_approach,
  type: :tool_based
```

## Setup

### Prerequisites

1. Elixir and Erlang installed
2. PostgreSQL with pgvector extension
3. Ollama for local embeddings
4. A Groq API key

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

### Install Ollama for Local Embeddings

1. Install Ollama from [ollama.ai](https://ollama.ai) or run:
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

2. Pull the embedding model:
   ```bash
   ollama pull nomic-embed-text
   ```

3. Make sure Ollama is running:
   ```bash
   ollama serve
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
2. Each document will be chunked and embedded using Ollama locally
3. You can view, edit, or delete documents from the document list

### Querying Documents

1. Go to the query interface at `/query`
2. Enter your question in the text field
3. The system will:
   - With Approach 1: Always retrieve relevant context first
   - With Approach 2: Let the LLM decide if context is needed
   - Generate a response with appropriate citations

## Architecture

1. **Database:**
   - Document storage with title and content
   - Document chunking with vector embeddings
   - Query history tracking

2. **Embedding Generation:**
   - Local embedding generation using Ollama with nomic-embed-text
   - No need for external API calls for embeddings
   - Privacy-preserving as text never leaves your machine

3. **LLM Integration:**
   - Groq API for high-quality responses
   - Function calling support for Approach 2
   - Context enrichment with retrieved documents
   - Source attribution in responses

4. **UI Components:**
   - Document management interface
   - Interactive query interface with LiveView
   - Real-time feedback during processing

## Limitations and Future Enhancements

This is a learning project with some limitations:

- No authentication or user management
- Limited error handling
- Basic document chunking strategy

Potential enhancements:
- Use Ollama for both embedding and LLM (fully offline operation)
- Implement more sophisticated chunking strategies
- Add user authentication
- Add document categorization
- Implement more tools for the LLM to use (e.g., web search, calculator)
