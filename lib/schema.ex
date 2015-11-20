defmodule Eflatbuffers.Schema do

  
  def lexer(schema_str) do
    to_char_list(schema_str)
    |> :schema_lexer.string
  end

  def parse(schema_str) when is_binary(schema_str) do
    {:ok, tokens, _} = lexer(schema_str)
    :schema_parser.parse(tokens)
  end


end