defmodule Eflatbuffers.SchemaTest do
  use ExUnit.Case

  test "apply lexer to schema" do
    res = 
      File.read!("test/parser_all.fbs")
      |> Eflatbuffers.Schema.lexer
  end

  test "parse simple schema" do
    res = 
      File.read!("test/parser_simple.fbs")
      |> Eflatbuffers.Schema.parse    

    expected = %{
      namespace: :SyGame, 
      include: :some_other, 
      attribute: :priority, 
      file_identifier: :FOOO, 
      file_extension: :baa, 
      root_type: :Monster
    }

    assert {:ok, { %{}, expected} } == res
  end

  test "parse schema with table" do
    res = 
      File.read!("test/parser_table.fbs")
      |> Eflatbuffers.Schema.parse 

    expected =
      %{:Monster => { :table,
          [
            pos: :Other,
            name: :string,
            test: :any,
            inventory: {:vector, :ubyte}
          ]
        }
      }  

    assert {:ok, {expected, %{}}} == res     
  end

  test "parse a whole table" do
    res = 
      File.read!("test/parser_all.fbs")
      |> Eflatbuffers.Schema.parse 

    expected_table =
      %{:Monster => { :table,
          [
            pos: :Other,
            name: :string,
            test: :any,
            inventory: {:vector, :ubyte}
          ]
        }
      }  

    expected_opts = %{
      namespace: :SyGame, 
      include: :some_other, 
      attribute: :priority, 
      file_identifier: :FOOO, 
      file_extension: :baa, 
      root_type: :Monster
    }
      

    assert {:ok, {expected_table, expected_opts}} == res     
  end

end