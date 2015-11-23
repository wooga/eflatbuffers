defmodule Eflatbuffers.SchemaTest do
  use ExUnit.Case

  @expected_simple %{
      namespace: :"SyGame.Play", 
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
        pos_: :Vec3,
        inventory: {:vector, :ubyte},
        etrue: :bool,
        mana: {:int, 150},
        hp: {:foo, -100},
        fl: {:float, 1.5},
        fl2: {:float, -1_512.3},
        waa: {:bool, :true},            
        frie: :ool,
        friendly: {:bool, false}
      ]
    }
  }  

  @expected_enum %{:Color =>
    {{:enum, :byte},
      [
        :Red,
        :Green,
        :Blue
      ] 
    }
  }  

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

  test "parse schema with enum" do
    res = 
      File.read!("test/parser_enum.fbs")
      |> Eflatbuffers.Schema.parse 

    assert {:ok, {@expected_enum, %{}}} == res     
  end

  test "parse a whole schema" do
    res = 
      ["test/parser_simple.fbs", "test/parser_table.fbs"]
      |> Enum.map(fn(file) -> File.read!(file) end)
      |> Enum.join("\n")
      |> Eflatbuffers.Schema.parse 

    assert {:ok, {@expected_table, @expected_simple}} == res     
  end

  test "parse doge schemas" do
    File.ls!("test/doge_schemas")
    |> Enum.map(fn(file) -> File.read!(Path.join("test/doge_schemas", file)) end)
    |> Enum.map(fn(schema_str) -> assert {:ok, _} = Eflatbuffers.Schema.parse(schema_str) end)
  end

end