# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Raga.Repo.insert!(%Raga.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Raga.RAG

# Check if we have any documents already
if Enum.empty?(RAG.list_documents()) do
  IO.puts("Creating sample document...")

  # Sample document about AI and RAG systems
  sample_doc = %{
    "title" => "Introduction to Retrieval-Augmented Generation",
    "content" => """
    # Retrieval-Augmented Generation (RAG)

    Retrieval-Augmented Generation (RAG) is a technique that enhances Large Language Models (LLMs) by combining them with information retrieval systems. This approach addresses some of the key limitations of traditional LLMs, such as providing access to more up-to-date information, reducing hallucinations, and enabling the use of private or domain-specific knowledge.

    ## How RAG Works

    RAG systems follow a three-step process:

    1. **Retrieval**: When a user query is received, the system searches a knowledge base to find relevant information that might help answer the question. This typically involves vector similarity search against a database of documents.

    2. **Augmentation**: The retrieved information is then combined with the original query to create a more informed prompt for the LLM.

    3. **Generation**: The LLM generates a response based on the augmented prompt, which includes both the query and the retrieved context.

    ## Benefits of RAG

    RAG systems offer several advantages over standalone LLMs:

    - **Reduced Hallucinations**: By grounding responses in retrieved facts, RAG systems are less likely to generate incorrect information.

    - **Access to Current Information**: RAG can utilize knowledge bases that are regularly updated, overcoming the "knowledge cutoff" limitation of pre-trained LLMs.

    - **Domain Specialization**: Organizations can use RAG to incorporate their own proprietary information, creating specialized AI assistants without needing to retrain the entire model.

    - **Transparency**: RAG systems can cite their sources, making it easier to verify the information they provide.

    ## Technical Implementation

    A typical RAG implementation includes:

    - A document store with vector embeddings for efficient similarity search
    - An embedding model to convert queries and documents into vector representations
    - A retrieval mechanism that finds the most relevant documents for a given query
    - A language model that generates responses using the retrieved context

    ## Applications

    RAG is particularly valuable in scenarios where factual accuracy is crucial, such as:

    - Customer support systems that need access to product information
    - Research assistants that must integrate the latest academic papers
    - Legal or medical applications that require reference to specific documents or guidelines
    - Educational tools that need to provide well-sourced information

    ## Limitations and Challenges

    Despite its benefits, RAG also faces challenges:

    - Quality of retrieval directly impacts response quality
    - Keeping knowledge bases current requires maintenance
    - System performance depends on effective prompt engineering to integrate retrieved information
    - Handling queries that require information from multiple documents can be complex

    ## Future Directions

    The field of RAG continues to evolve with research focusing on more sophisticated retrieval mechanisms, better ways to integrate retrieved information with queries, and methods to evaluate and improve response quality.

    As RAG systems become more advanced, they promise to deliver AI assistants that combine the flexibility of language models with the reliability of knowledge-based systems.
    """
  }

  case RAG.create_document(sample_doc) do
    {:ok, document} ->
      IO.puts("Sample document created successfully with ID: #{document.id}")

    {:error, reason} ->
      IO.puts("Failed to create sample document: #{inspect(reason)}")
  end
else
  IO.puts("Database already contains documents, skipping seed.")
end
