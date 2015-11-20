defmodule Eflatbuffers.SchemaTest do
  use ExUnit.Case

  test "apply lexer to schema" do
    res = 
      File.read!("test/parser.fbs")
      |> Eflatbuffers.Schema.lexer

    assert {:ok, _tokens, _} = res  
  end

  test "parse simple schema" do
    res = 
      File.read!("test/parser_simple.fbs")
      |> Eflatbuffers.Schema.parse    

    expected = %{
      "namespace" => "SyGame", 
      "include" => "some_other", 
      "attribute" => "priority", 
      "file_identifier" => "FOOO", 
      "file_extension" => "baa", 
      "root_type" => "Monster"
    }

    assert {:ok, expected } == res
  end

  test "parse schema with table" do
    res = 
      File.read!("test/parser_table.fbs")
      |> Eflatbuffers.Schema.parse 

    assert true == res     

  end

end