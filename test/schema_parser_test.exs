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

  @expected_union %{:Animal =>
    {
      :union, 
      [
        :Dog,
        :Cat,
        :Mouse
      ]
    }
  }

  test "parse simple schema" do
    res =
      File.read!("test/parser_simple.fbs")
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse()

    assert {:ok, { %{}, @expected_simple} } == res
  end

  test "parse schema with table" do
    res =
      File.read!("test/parser_table.fbs")
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse()

    assert {:ok, {@expected_table, %{}}} == res
  end

  test "parse schema with enum" do
    res =
      File.read!("test/parser_enum.fbs")
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse()

    assert {:ok, {@expected_enum, %{}}} == res
  end

  test "parse schema with union" do
    res =
      File.read!("test/parser_union.fbs")
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse()

    assert {:ok, {@expected_union, %{}}} == res
  end

  test "parse a whole schema" do
    res =
      ["test/parser_simple.fbs", "test/parser_table.fbs", "test/parser_union.fbs", "test/parser_enum.fbs", ]
      |> Enum.map(fn(file) -> File.read!(file) end)
      |> Enum.join("\n")
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse()
    assert {:ok, {Map.merge(@expected_table, @expected_enum) |> Map.merge(@expected_union), @expected_simple}} == res
  end

  test "correlate table" do
    parsed_entities = %{
      :table_inner =>
        {:table, [field: :int, field_int_default: {:int, 23}]},
      :table_outer =>
        {:table, [table_field: :table_inner, table_vector: {:vector, :table_inner}]}
    }
    correlated_entities = %{
      :table_inner =>
        {:table, [field: :int, field_int_default: {:int, 23}]},
      :table_outer =>
        {:table, [table_field: {:table, :table_inner}, table_vector: {:vector, {:table, :table_inner}}]}
    }
    assert {correlated_entities, %{}} == Eflatbuffers.Schema.correlate({parsed_entities, %{}})
  end

  test "correlate enumerable" do
    parsed_entities = %{
      :enum_inner =>
      {{:enum, :byte}, [:Red, :Green, :Blue]},
      :table_outer =>
        {:table, [enum_field: :enum_inner, enum_vector: {:vector, :enum_inner}]}
    }
    correlated_entities = %{
      :enum_inner =>
        {{:enum, :byte}, [:Red, :Green, :Blue]},
      :table_outer =>
        {:table, [enum_field: {:enum, :enum_inner}, enum_vector: {:vector, {:enum, :enum_inner}}]}
    }
    assert {correlated_entities, %{}} == Eflatbuffers.Schema.correlate({parsed_entities, %{}})
  end

  test "parse doge schemas" do
    File.ls!("test/doge_schemas")
    |> Enum.map(fn(file) -> File.read!(Path.join("test/doge_schemas", file)) end)
    |> Enum.map(fn(schema_str) -> assert {:ok, _} = Eflatbuffers.Schema.parse(schema_str) end)
  end

end
