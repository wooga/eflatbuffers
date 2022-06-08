defmodule EflatbuffersTest do
  use ExUnit.Case
  import TestHelpers
  doctest Eflatbuffers

  def before_test do
    flush_port_commands()
  end

  test "creating test data" do
    expected = <<12, 0, 0, 0, 8, 0, 8, 0, 6, 0, 0, 0, 8, 0, 0, 0, 0, 0, 17, 0>>
    assert expected == reference_fb(:simple_table, %{field_a: 17})
  end

  ### complete flatbuffer binaries

  test "table of scalars" do
    map = %{
      my_byte: 66,
      my_ubyte: 200,
      my_bool: true,
      my_short: -23,
      my_ushort: 42,
      my_int: -1000,
      my_uint: 1000,
      my_float: 3.124,
      my_long: -10_000_000,
      my_ulong: 10_000_000,
      my_double: 3.141593
    }

    assert_full_circle(:all_my_scalars, map)
  end

  test "table of scalars with defaults" do
    map = %{
      my_byte: -7,
      my_ubyte: 7,
      my_bool: true,
      my_short: -7,
      my_ushort: 7,
      my_int: -7,
      my_uint: 7,
      my_float: -7,
      my_long: -7,
      my_ulong: 7,
      my_double: -7
    }

    assert_full_circle(:defaults, map)
  end

  test "read simple table" do
    map = %{
      field_a: 42,
      field_b: 23
    }

    assert_full_circle(:simple_table, map)
  end

  test "read simple table with extended schema" do
    map = %{
      field_a: 42,
      field_b: 23
    }

    assert_full_circle(:simple_table_plus, :simple_table, map)
  end

  test "read table with missing values" do
    map = %{}
    assert_full_circle(:simple_table, map)
  end

  test "table with scalar vector" do
    map = %{
      int_vector: [23, 42, 666]
    }

    assert_full_circle(:int_vector, map)
  end

  test "table with string vector" do
    map = %{
      string_vector: ["foo", "bar", "baz"]
    }

    assert_full_circle(:string_vector, map)
  end

  test "table with enum" do
    map = %{
      enum_field: "Green"
    }

    assert_full_circle(:enum_field, map)
    assert_full_circle(:enum_field, %{})
  end

  test "vector of enum" do
    map = %{
      enum_fields: ["Blue", "Green", "Red"]
    }

    # writing
    {:ok, reply} = Eflatbuffers.write(map, load_schema(:vector_of_enums))
    assert(map == Eflatbuffers.read!(reply, load_schema(:vector_of_enums)))
  end

  test "table with union" do
    map = %{
      data: %{greeting: 42},
      data_type: "bye",
      additions_value: 123
    }

    assert_full_circle(:union_field, map)
  end

  test "table with table vector" do
    map = %{
      inner: [%{value_inner: "aaa"}]
    }

    assert_full_circle(:table_vector, map)
  end

  # test "nested vectors (not supported by flatc)" do
  #  map = %{
  #    the_vector: [[1,2,3],[4,5,6]],
  #  }
  #  # writing
  #  {:ok, reply} = Eflatbuffers.write(map, load_schema(:nested_vector))
  #  assert(map == Eflatbuffers.read!(reply, load_schema(:nested_vector)))
  # end

  test "fb with string" do
    map = %{
      my_string: "hello",
      my_bool: true
    }

    assert_full_circle(:string_table, map)
  end

  test "config debug fb" do
    map = %{technologies: [%{category: "aaa"}, %{}]}
    assert_full_circle(:config_path, map)
  end

  test "config fb" do
    {:ok, schema} = Eflatbuffers.Schema.parse(load_schema({:doge, :config}))
    map = Poison.decode!(File.read!("test/complex_schemas/config.json"), keys: :atoms)
    # writing
    reply = Eflatbuffers.write!(map, schema)
    reply_map = Eflatbuffers.read!(reply, schema)
    assert [] == compare_with_defaults(round_floats(map), round_floats(reply_map), schema)

    assert_full_circle({:doge, :config}, map)
  end

  test "commands fb" do
    maps = [
      %{data_type: "RefineryStartedCommand", data: %{}},
      %{data_type: "CraftingFinishedCommand", data: %{}},
      %{data_type: "MoveBuildingCommand", data: %{from: %{x: 23, y: 11}, to: %{x: 42, y: -1}}}
    ]

    Enum.each(
      maps,
      fn map -> assert_full_circle({:doge, :commands}, map) end
    )
  end

  test "read nested table" do
    map = %{
      value_outer: 42,
      inner: %{value_inner: 23}
    }

    assert_full_circle(:nested, map)
  end

  test "write fb" do
    map = %{my_bool: true, my_string: "max", my_second_string: "minimum"}
    assert_full_circle(:table_bool_string_string, map)
  end

  test "no file identifier" do
    fb = Eflatbuffers.write!(%{}, load_schema(:no_identifier))
    assert <<_::size(4)-binary>> <> <<0, 0, 0, 0>> <> <<_::binary>> = fb
  end

  test "file identifier" do
    fb_id = Eflatbuffers.write!(%{}, load_schema(:identifier))
    fb_no_id = Eflatbuffers.write!(%{}, load_schema(:no_identifier))
    assert <<_::size(32)>> <> "helo" <> <<_::binary>> = fb_id
    assert <<_::size(32)>> <> <<0, 0, 0, 0>> <> <<_::binary>> = fb_no_id
    assert %{} == Eflatbuffers.read!(fb_id, load_schema(:no_identifier))

    assert {:error, {:identifier_mismatch, %{data: <<0, 0, 0, 0>>, schema: "helo"}}} ==
             catch_throw(Eflatbuffers.read!(fb_no_id, load_schema(:identifier)))

    assert_full_circle(:identifier, %{})
    assert_full_circle(:no_identifier, %{})
  end

  test "path errors" do
    map = %{foo: true, tables_field: [%{string_field: "hello"}]}
    assert_full_circle(:error, map)

    map = %{foo: true, tables_field: [%{}, %{bar: 3, string_field: 23}]}

    assert {:error, {:wrong_type, :string, 23, [{:tables_field}, [1], {:string_field}]}} ==
             catch_throw(
               Eflatbuffers.write!(map, Eflatbuffers.parse_schema!(load_schema(:error)))
             )

    map = %{foo: true, tables_field: [%{}, "hoho!"]}

    assert {:error, {:wrong_type, :table, "hoho!", [{:tables_field}, [1]]}} ==
             catch_throw(
               Eflatbuffers.write!(map, Eflatbuffers.parse_schema!(load_schema(:error)))
             )

    map = %{foo: true, tables_field: 123}

    assert {:error, {:wrong_type, :vector, 123, [{:tables_field}]}} ==
             catch_throw(
               Eflatbuffers.write!(map, Eflatbuffers.parse_schema!(load_schema(:error)))
             )
  end
end
