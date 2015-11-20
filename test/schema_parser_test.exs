defmodule Eflatbuffers.SchemaTest do
  use ExUnit.Case

  @expected_simple %{
      namespace: :SyGame, 
      include: "some_other.fbs", 
      attribute: "priority", 
      file_identifier: "FOOO", 
      file_extension: "baa", 
      root_type: :Monster
    }

  @expected_table %{:Monster => 
    { :table,
      [
        name: :string,
        pos: :Vec3,
        inventory: {:vector, :ubyte},
        mana: {:int, 150},
        hp: {:foo, -100},
        fl: {:float, 1.5},
        fl2: {:float, -1_512.3},
        waa: {:bool, :true},            
        # frie: :bool,
        # friendly: {:bool, false}
      ]
    }
  }    

  test "apply lexer to schema" do
      File.read!("test/parser_all.fbs")
      |> Eflatbuffers.Schema.lexer
  end


  test "parse simple schema" do
    res = 
      File.read!("test/parser_simple.fbs")
      |> Eflatbuffers.Schema.parse    

    assert {:ok, { %{}, @expected_simple} } == res
  end

  test "parse schema with table" do
    res = 
      File.read!("test/parser_table.fbs")
      |> Eflatbuffers.Schema.parse 

    assert {:ok, {@expected_table, %{}}} == res     
  end

  test "parse a whole schema" do
    res = 
      File.read!("test/parser_all.fbs")
      |> Eflatbuffers.Schema.parse 

    assert {:ok, {@expected_table, @expected_simple}} == res     
  end

end