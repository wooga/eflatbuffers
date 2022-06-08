defmodule EflatbuffersRandomAccessTest do
  use ExUnit.Case
  import TestHelpers

  test "fb with string" do
    map = %{
      my_string: "hello",
      my_bool: true
    }

    fb = fb(map, :string_table)
    assert "hello" == get(fb, [:my_string], :string_table)
    assert true == get(fb, [:my_bool], :string_table)
    assert map == get(fb, [], :string_table)
  end

  test "all my scalars" do
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

    fb = fb(map, :all_my_scalars)

    Enum.map(
      Map.keys(map),
      fn key ->
        assert round_float(Map.get(map, key)) == round_float(get(fb, [key], :all_my_scalars))
      end
    )
  end

  test "nested" do
    map = %{
      value_outer: 1,
      inner: %{value_inner: 2}
    }

    fb = fb(map, :nested)
    assert %{value_inner: 2} == get(fb, [:inner], :nested)
    assert 2 == get(fb, [:inner, :value_inner], :nested)
  end

  test "omitted values" do
    map = %{
      value_outer: 1
    }

    fb = fb(map, :nested)
    assert nil == get(fb, [:inner], :nested)
    assert nil == get(fb, [:inner, :value_inner], :nested)
  end

  test "int vector" do
    map = %{
      int_vector: [23, 42, 0]
    }

    fb = fb(map, :int_vector)
    assert [23, 42, 0] == get(fb, [:int_vector], :int_vector)
    assert 42 == get(fb, [:int_vector, 1], :int_vector)
  end

  test "enum fields" do
    map = %{enum_field: "Green"}
    fb = fb(map, :enum_field)
    assert "Green" == get(fb, [:enum_field], :enum_field)
  end

  test "unions" do
    map = %{data: %{salute: "moin"}, data_type: "hello", additions_value: 123}
    fb = fb(map, :union_field)
    assert %{salute: "moin"} == get(fb, [:data], :union_field)
    assert "moin" == get(fb, [:data, :salute], :union_field)
    assert 123 == get(fb, [:additions_value], :union_field)
  end

  test "vector of enums" do
    map = %{enum_fields: ["Red", "Green", "Blue"]}
    fb = fb(map, :vector_of_enums)
    assert ["Red", "Green", "Blue"] == get(fb, [:enum_fields], :vector_of_enums)
    assert "Green" == get(fb, [:enum_fields, 1], :vector_of_enums)
  end

  test "vector of strings" do
    map = %{string_vector: ["Hello", "shiny", "World"]}
    fb = fb(map, :string_vector)
    assert ["Hello", "shiny", "World"] == get(fb, [:string_vector], :string_vector)
    assert "shiny" == get(fb, [:string_vector, 1], :string_vector)
  end

  test "table vector" do
    map = %{inner: [%{value_inner: "one"}, %{value_inner: "two"}, %{value_inner: "three"}]}
    fb = fb(map, :table_vector)

    assert [%{value_inner: "one"}, %{value_inner: "two"}, %{value_inner: "three"}] ==
             get(fb, [:inner], :table_vector)

    assert %{value_inner: "two"} == get(fb, [:inner, 1], :table_vector)
    assert "three" == get(fb, [:inner, 2, :value_inner], :table_vector)
  end

  test "config" do
    map = Poison.decode!(File.read!("test/complex_schemas/config.json"), keys: :atoms)
    fb = fb(map, {:doge, :config})

    assert "townhall" ==
             get(
               fb,
               [:config, :town_sectors, :townSectors, 2, :minLevel, 0, :id],
               {:doge, :config}
             )

    assert "coins" == get(fb, [:config, :quests, :quests, 0, :rewards, 0, :id], {:doge, :config})
  end

  def get(fb, path, schema_type) do
    Eflatbuffers.get!(fb, path, load_schema(schema_type))
  end

  def fb(data, schema_type) do
    Eflatbuffers.write!(data, load_schema(schema_type))
  end

  def round_float(float) when is_float(float) do
    round(float)
  end

  def round_float(other) do
    other
  end
end
