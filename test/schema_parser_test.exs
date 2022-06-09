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

  @expected_table %{
    :Monster =>
      {:table,
       [
         name: :string,
         pos_: :Vec3,
         inventory: {:vector, :ubyte},
         etrue: :bool,
         mana: {:int, 150},
         hp: {:foo, -100},
         fl: {:float, 1.5},
         fl2: {:float, -1_512.3},
         waa: {:bool, true},
         frie: :ool,
         friendly: {:bool, false}
       ]}
  }

  @expected_enum %{
    :Color => {
      {:enum, :byte},
      [
        :Red,
        :Green,
        :Blue
      ]
    }
  }

  @expected_union %{
    :Animal => {
      :union,
      [
        :Dog,
        :Cat,
        :Mouse
      ]
    }
  }

  @expected_struct %{
    Color: {{:enum, :byte}, [:Red, :Green, :Blue]},
    Everything: {:struct, [size: :float, color: :Color, nested: :Nest]},
    Nest: {:struct, [age: :int]}
  }

  @expected_attribute %{State: {:table, [active: {:bool, false}]}}

  test "parse simple schema" do
    res =
      File.read!("test/schemas/parser_simple.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {%{}, @expected_simple}} == res
  end

  test "parse schema with table" do
    res =
      File.read!("test/schemas/parser_table.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {@expected_table, %{}}} == res
  end

  test "parse schema with enum" do
    res =
      File.read!("test/schemas/parser_enum.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {@expected_enum, %{}}} == res
  end

  test "parse schema with union" do
    res =
      File.read!("test/schemas/parser_union.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {@expected_union, %{}}} == res
  end

  test "parse schema with struct" do
    res =
      File.read!("test/schemas/parser_struct.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {@expected_struct, %{}}} == res
  end

  test "parse schema with additional attributes" do
    res =
      File.read!("test/schemas/parser_attribute.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok, {@expected_attribute, %{attribute: "priority", root_type: :State}}} == res
  end

  test "parse a whole schema" do
    res =
      [
        "test/schemas/parser_simple.fbs",
        "test/schemas/parser_table.fbs",
        "test/schemas/parser_union.fbs",
        "test/schemas/parser_enum.fbs"
      ]
      |> Enum.map(fn file -> File.read!(file) end)
      |> Enum.join("\n")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert {:ok,
            {Map.merge(@expected_table, @expected_enum) |> Map.merge(@expected_union),
             @expected_simple}} == res
  end

  test "decorate table" do
    parsed_entities = %{
      :table_inner => {:table, [field: :int, field_int_default: {:int, 23}]},
      :table_outer => {:table, [table_field: :table_inner, table_vector: {:vector, :table_inner}]}
    }

    decorated_entities = %{
      table_inner:
        {:table,
         %{
           fields: [field: {:int, %{default: 0}}, field_int_default: {:int, %{default: 23}}],
           indices: %{
             field: {0, {:int, %{default: 0}}},
             field_int_default: {1, {:int, %{default: 23}}}
           }
         }},
      table_outer:
        {:table,
         %{
           fields: [
             table_field: {:table, %{name: :table_inner}},
             table_vector: {:vector, %{type: {:table, %{name: :table_inner}}}}
           ],
           indices: %{
             table_field: {0, {:table, %{name: :table_inner}}},
             table_vector: {1, {:vector, %{type: {:table, %{name: :table_inner}}}}}
           }
         }}
    }

    assert {decorated_entities, %{}} == Eflatbuffers.Schema.decorate({parsed_entities, %{}})
  end

  test "decorate enumerable" do
    parsed_entities = %{
      :enum_inner => {{:enum, :byte}, [:Red, :Green, :Blue]},
      :table_outer => {:table, [enum_field: :enum_inner, enum_vector: {:vector, :enum_inner}]}
    }

    decorated_entities = %{
      enum_inner:
        {:enum,
         %{
           members: %{0 => :Red, 1 => :Green, 2 => :Blue, :Blue => 2, :Green => 1, :Red => 0},
           type: {:byte, %{}}
         }},
      table_outer:
        {:table,
         %{
           fields: [
             enum_field: {:enum, %{name: :enum_inner}},
             enum_vector: {:vector, %{type: {:enum, %{name: :enum_inner}}}}
           ],
           indices: %{
             enum_field: {0, {:enum, %{name: :enum_inner}}},
             enum_vector: {1, {:vector, %{type: {:enum, %{name: :enum_inner}}}}}
           }
         }}
    }

    assert {decorated_entities, %{}} == Eflatbuffers.Schema.decorate({parsed_entities, %{}})
  end

  test "decorate union" do
    parsed_entities = %{
      :union_inner => {:union, [:hello, :bye]},
      :table_outer => {:table, [union_field: :union_inner, union_vector: {:vector, :union_inner}]}
    }

    decorated_entities = %{
      table_outer:
        {:table,
         %{
           fields: [
             union_field: {:union, %{name: :union_inner}},
             union_vector: {:vector, %{type: {:union, %{name: :union_inner}}}}
           ],
           indices: %{
             union_field: {0, {:union, %{name: :union_inner}}},
             union_vector: {2, {:vector, %{type: {:union, %{name: :union_inner}}}}}
           }
         }},
      union_inner: {:union, %{members: %{0 => :hello, 1 => :bye, :bye => 1, :hello => 0}}}
    }

    assert {decorated_entities, %{}} == Eflatbuffers.Schema.decorate({parsed_entities, %{}})
  end

  test "parse doge schemas" do
    File.ls!("test/complex_schemas")
    |> Enum.filter(fn file -> String.contains?(file, ".fbs") end)
    |> Enum.map(fn file -> File.read!(Path.join("test/complex_schemas", file)) end)
    |> Enum.map(fn schema_str -> assert {:ok, _} = Eflatbuffers.Schema.parse(schema_str) end)
  end

  test "parse FlatBuffers example schema" do
    expected =
      {%{
         Any: {:union, [:Monster, :Weapon, :Pickup]},
         Color: {{:enum, :byte}, [{:Red, 1}, :Green, :Blue]},
         Monster:
           {:table,
            [
              pos: :Vec3,
              mana: {:short, 150},
              hp: {:short, 100},
              name: :string,
              friendly: {:bool, false},
              inventory: {:vector, :ubyte},
              color: {:Color, "Blue"},
              test: :Any
            ]},
         Vec3: {:struct, [x: :float, y: :float, z: :float]}
       },
       %{
         attribute: "priority",
         include: "simple_table.fbs",
         namespace: :MyGame,
         root_type: :Monster
       }}

    {:ok, schema} =
      File.read!("test/schemas/flatbuffers_example_table.fbs")
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    assert schema == expected
  end
end
