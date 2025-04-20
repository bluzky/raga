defmodule MarkdownParser do
  @moduledoc """
  Module for parsing large markdown files and splitting them by level 1 headings.
  """

  @doc """
  Reads a markdown file, splits it by level 1 headings, and returns a list of
  maps with title and content keys.

  ## Parameters
    - file_path: Path to the markdown file

  ## Returns
    - A list of maps with keys :title and :content

  ## Example
    ```elixir
    MarkdownParser.parse_by_headings("path/to/large_file.md")
    # Returns:
    # [
    #   %{title: "First Heading", content: "Content under first heading..."},
    #   %{title: "Second Heading", content: "Content under second heading..."}
    # ]
    ```
  """
  def parse_by_headings(file_path) do
    # Read the file in streaming mode to handle large files efficiently
    file_path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Enum.reduce({[], nil, []}, &process_line/2)
    |> finalize_sections()
  end

  # Process each line of the markdown file
  defp process_line(line, {sections, current_title, current_content}) do
    if heading_level_1?(line) do
      # If we find a level 1 heading and we already have a current title,
      # we need to save the previous section before starting a new one
      new_sections =
        if current_title do
          section = %{
            title: current_title,
            content: Enum.reverse(current_content) |> Enum.join("\n") |> String.trim()
          }

          [section | sections]
        else
          sections
        end

      # Extract the title from the heading and start a new section
      title = extract_title(line)
      {new_sections, title, []}
    else
      # If it's not a level 1 heading, add the line to the current content
      {sections, current_title, [line | current_content]}
    end
  end

  # Finalize the sections list by adding the last section and reversing the list
  defp finalize_sections({sections, nil, _}), do: Enum.reverse(sections)

  defp finalize_sections({sections, current_title, current_content}) do
    section = %{
      title: current_title,
      content: Enum.reverse(current_content) |> Enum.join("\n") |> String.trim()
    }

    [section | sections] |> Enum.reverse()
  end

  # Check if a line is a level 1 heading (starts with # followed by a space)
  defp heading_level_1?(line), do: String.match?(line, ~r/^# /)

  # Extract the title from a level 1 heading line
  defp extract_title(line), do: String.replace(line, ~r/^# /, "")
end

# Example usage:
# sections = MarkdownParser.parse_by_headings("path/to/your_markdown_file.md")
# Enum.each(sections, fn %{title: title, content: _} -> IO.puts("Found section: #{title}") end)

sections =
  MarkdownParser.parse_by_headings(
    Application.app_dir(:raga, "priv/sample data/OctoPOS-Documents.md")
  )

sections
|> Enum.reject(fn %{title: title, content: content} ->
  title in ["", nil] or content in ["", nil]
end)
|> Enum.each(fn %{title: title, content: content} ->
  IO.inspect(content)

  Raga.RAG.create_document(%{
    "title" => title,
    "content" => content
  })
end)
