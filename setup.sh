#!/bin/bash

# Raga - RAG System Setup Script
echo "=== Setting up Raga RAG System ==="

# Check for Elixir installation
if ! command -v elixir &> /dev/null; then
    echo "Error: Elixir is not installed. Please install Elixir and try again."
    exit 1
fi

# Check for PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "Error: PostgreSQL is not installed. Please install PostgreSQL and try again."
    exit 1
fi

# Get Groq API key
if [ -z "$GROQ_API_KEY" ]; then
    echo "Groq API key not found in environment."
    read -p "Enter your Groq API key: " groq_api_key
    export GROQ_API_KEY=$groq_api_key
    echo "API key set for this session."
    echo "Note: You should add 'export GROQ_API_KEY=your_key' to your shell profile for permanent configuration."
fi

# Get dependencies
echo "=== Installing dependencies ==="
mix deps.get

# Check if database exists and create if needed
echo "=== Setting up database ==="
if mix ecto.create; then
    echo "Database created successfully."
else
    echo "Database may already exist, attempting to continue..."
fi

# Run migrations
echo "=== Running migrations ==="
mix ecto.migrate

# Setup and build assets
echo "=== Setting up assets ==="
mix assets.setup
mix assets.build

echo "=== Setup complete! ==="
echo "You can now start the Phoenix server with:"
echo "  mix phx.server"
echo ""
echo "Then visit http://localhost:4000 in your browser."
