defmodule Eflatbuffers.Schema do
  
  def lexer(schema_str) do
    {:ok, tokens, _} = 
      to_char_list(schema_str)
      |> :schema_lexer.string
    tokens
  end

  def parse(schema_str) when is_binary(schema_str) do
    lexer(schema_str)
    |> :schema_parser.parse()
  end


end