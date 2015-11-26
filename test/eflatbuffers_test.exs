defmodule EflatbuffersTest do
  use ExUnit.Case
  import TestHelpers
  doctest Eflatbuffers

  def before_test do
    flush_port_commands
  end

  test "creating test data" do
    expected = <<12, 0, 0, 0, 8, 0, 8, 0, 6, 0, 0, 0, 8, 0, 0, 0, 0, 0, 17, 0>>
    assert expected == reference_fb(:simple_table, %{field_a: 17})
  end

  ### 8 bit types

  test "write bytes" do
    assert << 255 >> == Eflatbuffers.write(:byte, -1, '_')
    assert {:error, {:wrong_type, :byte, 1000}} == catch_throw(Eflatbuffers.write(:byte, 1000, {%{}, %{}}))
    assert {:error, {:wrong_type, :byte, "x"}}  == catch_throw(Eflatbuffers.write(:byte, "x", {%{}, %{}}))
  end

  test "write ubytes" do
    assert << 42 >> == Eflatbuffers.write(:ubyte, 42, {%{}, %{}})
  end

  test "write bools" do
    assert << 1 >> == Eflatbuffers.write(:bool, true,  {%{}, %{}})
    assert << 0 >> == Eflatbuffers.write(:bool, false, {%{}, %{}})
  end

  ### 16 bit types

  test "write ushort" do
    assert << 255, 255 >> == Eflatbuffers.write(:ushort, 65_535,  {%{}, %{}})
    assert << 42,  0 >> == Eflatbuffers.write(:ushort, 42,  {%{}, %{}})
    assert << 0, 0 >>     == Eflatbuffers.write(:ushort, 0, {%{}, %{}})
    assert {:error, {:wrong_type, :ushort, 65536123}} == catch_throw(Eflatbuffers.write(:ushort, 65_536_123,  {%{}, %{}}))
    assert {:error, {:wrong_type, :ushort, -1}}    == catch_throw(Eflatbuffers.write(:ushort, -1,  {%{}, %{}}))
  end

  test "write short" do
    assert << 255, 127 >> == Eflatbuffers.write(:short, 32_767, {%{}, %{}})
    assert << 0, 0 >>     == Eflatbuffers.write(:short, 0, {%{}, %{}})
    assert << 0, 128 >>     == Eflatbuffers.write(:short, -32_768, {%{}, %{}})
    assert {:error, {:wrong_type, :short, 32_768}}  == catch_throw(Eflatbuffers.write(:short, 32_768,  {%{}, %{}}))
    assert {:error, {:wrong_type, :short, -32_769}} == catch_throw(Eflatbuffers.write(:short, -32_769,  {%{}, %{}}))
  end

  ### 32 bit types
  ### 64 bit types


  ### complex types

  test "write strings" do
    assert << 3, 0, 0, 0 >> <> "max" == Eflatbuffers.write(:string, "max", '_')
    assert {:error, {:wrong_type, :byte, "max"}} == catch_throw(Eflatbuffers.write(:byte, "max", {%{}, %{}}))
  end

  test "write vectors" do
    assert [<<3, 0, 0, 0>>, [[<<1>>, <<1>>, <<0>>], []], ] == Eflatbuffers.write({:vector, :bool}, [true, true, false], '_')
    assert(
      [<<2, 0, 0, 0>>, [[<<8, 0, 0, 0>>, <<11, 0, 0, 0>>], [<<3, 0, 0, 0, 102, 111, 111>>, <<3, 0, 0, 0, 98, 97, 114>>]]] ==
      Eflatbuffers.write({:vector, :string}, ["foo", "bar"], '_')
    )
  end

  ### intermediate data

  test "data buffer" do
    data_buffer =  [
      [<<1>>, <<8, 0, 0, 0>>, <<11, 0, 0, 0>>, []],
      [<<3, 0, 0, 0, 109, 97, 120>>, <<7, 0, 0, 0, 109, 105, 110, 105, 109, 117, 109>>]
    ]
    reply = Eflatbuffers.data_buffer_and_data(
      [:bool, :string, :string, :bool],
      [true, "max", "minimum", nil],
      '_'
    )
    assert( data_buffer == reply)
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
      my_long: -10000000,
      my_ulong: 10000000,
      my_double: 3.141593,
    }
    assert_full_circle(:all_my_scalars, map)
  end

  test "read simple table" do
    map = %{
      field_a: 42,
      field_b: 23,
    }
    assert_full_circle(:simple_table, map)
  end

  test "read table with missing values" do
    map = %{}
    assert_full_circle(:simple_table, map)
  end

  test "table with scalar vector" do
    map = %{
      int_vector: [23, 42, 666],
    }
    assert_full_circle(:int_vector, map)
  end

  test "table with string vector" do
    map = %{
      string_vector: ["foo", "bar", "baz"],
    }
    assert_full_circle(:string_vector, map)
  end

  test "table with enum" do
    map = %{
      enum_field: "Green",
    }
    assert_full_circle(:enum_field, map)
  end

  test "vector of enum" do
    tables = %{
      :enum_inner =>
        {{:enum, :int}, %{0 => :Red, 1 => :Green, 2 => :Blue, :Blue => 2, :Green => 1, :Red => 0}},
      :table_outer =>
        {:table, [enum_fields: {:vector, {:enum, :enum_inner}}]}
    }
    schema = { tables, %{root_type: :table_outer} }
    map = %{
      enum_fields: ["Red", "Green", "Blue"]
    }
    # writing
    reply = Eflatbuffers.write_fb!(map, schema)
    assert(map == Eflatbuffers.read_fb!(:erlang.iolist_to_binary(reply), schema))
  end

  test "table with union" do
    map = %{
      data: %{greeting: 42},
      data_type: "bye",
    }
    assert_full_circle(:union_field, map)
  end

  test "table with table vector" do
    map = %{
      inner: [%{value_inner: "aaa"}],
    }
    assert_full_circle(:table_vector, map)
  end

  test "complex table with table vector" do
    table = {:table,
      [
        value: :string,
        inner: {:vector, {:table, :the_table}},
      ]}
    schema = { %{the_table: table}, %{root_type: :the_table} }
    map = %{
      value: "outer",
      inner: [
        %{
          value: "middle",
          inner: [
          %{value: "inner",
            inner: []
          }
        ]}]
    }
    # writing
    reply = Eflatbuffers.write_fb!(map, schema)
    # reading
    assert(map == Eflatbuffers.read_fb!(:erlang.iolist_to_binary(reply), schema))
  end

  test "nested vectors (not supported by flatc)" do
    table = {:table,
      [
        the_vector: {:vector, {:vector, :int}},
      ]}
    schema = { %{root_table: table}, %{root_type: :root_table} }
    map = %{
      the_vector: [[1,2,3],[4,5,6]],
    }
    # writing
    reply = Eflatbuffers.write_fb!(map, schema)
    assert(map == Eflatbuffers.read_fb!(:erlang.iolist_to_binary(reply), schema))
  end

  test "fb with string" do
    map = %{
      my_string: "hello",
      my_bool: true,
    }
    assert_full_circle(:string_table, map)
  end

  test "config debug fb" do
    map = %{technologies: [%{category: "aaa"}, %{}]}
    assert_full_circle(:config_path, map)
  end

  test "config fb" do
    {:ok, schema} = Eflatbuffers.Schema.parse(load_schema({:doge, :config}))
    map = Poison.decode!(File.read!("test/doge_schemas/config.json"), [keys: :atoms])
    # writing
    reply = Eflatbuffers.write_fb!(map, schema)
    reply_map  = Eflatbuffers.read_fb!(:erlang.iolist_to_binary(reply), schema)

    assert round_floats(map) == round_floats(reply_map)

    looped_fb = Eflatbuffers.write_fb!(reply_map, schema)
    assert looped_fb == reply

    assert_eq({:doge, :config}, map, reply)
  end

  test "commands fb" do
    {:ok, schema} = Eflatbuffers.Schema.parse(load_schema({:doge, :commands}))
    maps = [
      %{data_type: "RefineryStartedCommand",  data: %{} },
      %{data_type: "CraftingFinishedCommand", data: %{} },
      %{data_type: "MoveBuildingCommand",     data: %{from: %{x: 23, y: 11}, to: %{x: 42, y: -1}} },
    ]
    Enum.each(
      maps,
      fn(map) -> assert_full_circle({:doge, :commands}, map) end
    )
  end

  test "fb with string" do
    map = %{
      my_string: "hello",
      my_bool: true,
    }
    assert_full_circle(:string_table, map)
  end

  test "read nested table" do
    map = %{
      value_outer: 42,
      inner: %{ value_inner: 23 }
    }
    assert_full_circle(:nested, map)
  end

  test "write fb" do
    map = %{my_bool: true, my_string: "max", my_second_string: "minimum"}
    assert_full_circle(:table_bool_string_string, map)
  end

  test "file identifier" do
    schema = {%{foo: {:table, [a: :bool]}}, %{root_type: :foo, file_identifier: "helo"}}
    reply = Eflatbuffers.write_fb!(%{}, schema)
    assert << _ :: size(32) >> <> "helo" <> << _ :: binary >> = :erlang.iolist_to_binary(reply)
  end

  def assert_full_circle(schema_type, map) do
    schema_ex = Eflatbuffers.Schema.parse!(load_schema(schema_type))

    fb_ex     = Eflatbuffers.write_fb!(map, schema_ex)
    map_ex_flatc = reference_map(schema_type, :erlang.iolist_to_binary(fb_ex))

    fb_flatc     = reference_fb(schema_type, map)
    map_flatc_ex = Eflatbuffers.read_fb!(fb_flatc, schema_ex)

    assert round_floats(map_ex_flatc) == round_floats(map_flatc_ex)
  end

  def assert_eq(schema, map, binary) do
    map_looped = reference_map(schema, :erlang.iolist_to_binary(binary))
    assert round_floats(map) == round_floats(map_looped)
  end

  def reference_fb(schema, data) when is_map(data) do
    json  = Poison.encode!(data)
    port  = FlatbufferPort.open_port()
    :true = FlatbufferPort.load_schema(port, load_schema(schema))
    :ok   = port_response(port)
    :true = FlatbufferPort.json_to_fb(port, json)
    {:ok, reply} = port_response(port)
    reply
  end

  def reference_json(schema, data) when is_binary(data) do
    port  = FlatbufferPort.open_port()
    :true = FlatbufferPort.load_schema(port, load_schema(schema))
    :ok   = port_response(port)
    :true = FlatbufferPort.fb_to_json(port, data)
    port_response(port)
  end

  def reference_map(schema, data) do
    {:ok, json} =  reference_json(schema, data)
    Poison.decode!(json, [:return_maps, keys: :atoms])
  end


  def port_response(port) do
    receive do
        {^port, {:data, data}}  ->
          FlatbufferPort.parse_reponse(data)
    after
      3000 ->
        :timeout
    end
  end

  def flush_port_commands do
    receive do
      {_port, {:data, _}}  ->
        flush_port_commands
    after 0 ->
      :ok
    end
  end

  def round_floats(map) when is_map(map) do
    map
    |> Enum.map(fn({k,v}) -> {k, round_floats(v)} end)
    |> Enum.into(%{})
  end
  def round_floats(list) when is_list(list), do: Enum.map(list, &round_floats/1)
  def round_floats(float) when is_float(float), do: round(float)
  def round_floats(other), do: other

end
