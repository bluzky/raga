defmodule Raga.Groq.ToolHandler do
  @moduledoc """
  Handles tool/function execution from GROQ LLM responses
  """
  require Logger

  alias Raga.Groq.ToolDefinitions.RagSearch

  @available_tools %{
    "search_knowledge_base" => RagSearch
  }

  def get_available_tools do
    Enum.map(@available_tools, fn {_name, module} ->
      module.get_tool_definition()
    end)
  end

  def handle_tool_call(tool_name, arguments) do
    case Map.get(@available_tools, tool_name) do
      nil ->
        {:error, "Unknown tool: #{tool_name}"}

      module ->
        Logger.info("Executing tool: #{tool_name} with arguments: #{inspect(arguments)}")
        module.execute(arguments)
    end
  end
end
