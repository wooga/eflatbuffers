defmodule EflatbuffersTest do
  use ExUnit.Case
  doctest Eflatbuffers

  def before_test do
    flush_port_commands
  end

  test "creating test data" do
    expected = {:ok, <<12, 0, 0, 0, 8, 0, 8, 0, 6, 0, 0, 0, 8, 0, 0, 0, 0, 0, 17, 0>>}
    assert expected == reference_fb(:simple_table, %{field_a: 17})
  end

  ### 8 bit types

  test "write bytes" do
    assert << 255 >> == Eflatbuffers.write(:byte, -1, '_')
    assert {:error, {:wrong_type, :byte, 1000}} == catch_throw(Eflatbuffers.write(:byte, 1000, '_'))
    assert {:error, {:wrong_type, :byte, "x"}}  == catch_throw(Eflatbuffers.write(:byte, "x", '_'))
  end

  test "write ubytes" do
    assert << 42 >> == Eflatbuffers.write(:ubyte, 42, '_')
  end

  test "write bools" do
    assert << 1 >> == Eflatbuffers.write(:bool, true, '_')
    assert << 0 >> == Eflatbuffers.write(:bool, false, '_')
  end

  ### 16 bit types

  test "write ushort" do
    assert << 255, 255 >> == Eflatbuffers.write(:ushort, 65_535, '_')
    assert << 42,  0 >> == Eflatbuffers.write(:ushort, 42, '_')
    assert << 0, 0 >>     == Eflatbuffers.write(:ushort, 0, '_')
    assert {:error, {:wrong_type, :ushort, 65536123}} == catch_throw(Eflatbuffers.write(:ushort, 65_536_123, '_'))
    assert {:error, {:wrong_type, :ushort, -1}}    == catch_throw(Eflatbuffers.write(:ushort, -1, '_'))
  end

  test "write short" do
    assert << 255, 127 >> == Eflatbuffers.write(:short, 32_767, '_')
    assert << 0, 0 >>     == Eflatbuffers.write(:short, 0, '_')
    assert << 0, 128 >>     == Eflatbuffers.write(:short, -32_768, '_')
    assert {:error, {:wrong_type, :short, 32_768}}  == catch_throw(Eflatbuffers.write(:short, 32_768, '_'))
    assert {:error, {:wrong_type, :short, -32_769}} == catch_throw(Eflatbuffers.write(:short, -32_769, '_'))
  end

  ### 32 bit types
  ### 64 bit types


  ### complex types

  test "write strings" do
    assert << 3, 0, 0, 0 >> <> "max" == Eflatbuffers.write(:string, "max", '_')
    assert {:error, {:wrong_type, :byte, "max"}} == catch_throw(Eflatbuffers.write(:byte, "max", '_'))
  end

  test "write vectors" do
    assert [<<3, 0, 0, 0>>, [<<1>>, <<1>>, <<0>>]] == Eflatbuffers.write({:vector, :bool}, [true, true, false], '_')
    assert(
      [<< 2, 0, 0, 0 >>, [<< 3, 0, 0, 0 >> <> "foo", << 3, 0, 0, 0 >> <> "bar"]] ==
      Eflatbuffers.write({:vector, :string}, ["foo", "bar"], '_')
    )
  end

  test "table intermediate" do
    map = %{my_string: "max", my_second_string: "minimum", my_bool: true}
    intermediate =  [
            [my_bool: <<1>>, my_string: <<8, 0, 0, 0>>, my_second_string: <<11, 0, 0, 0>>, my_omitted_bool: ""],
            [<<3, 0, 0, 0, 109, 97, 120>>, <<7, 0, 0, 0, 109, 105, 110, 105, 109, 117, 109>>]
    ]
    reply = Eflatbuffers.data_buffer_and_data(
      [{:my_bool, :bool}, {:my_string, :string}, {:my_second_string, :string}, {:my_omitted_bool, :bool}],
      map,
      {[], [], 0}
    )
    assert( intermediate == reply)
  end

  test "table of scalars" do
    table = {:table,
      [
        my_byte: :byte,
        my_ubyte: :ubyte,
        my_bool: :bool,
        my_short: :short,
        my_ushort: :ushort,
        my_int: :int,
        my_uint: :uint,
        my_float: :float,
        my_long: :long,
        my_ulong: :ulong,
        my_double: :double,
      ]}
    schema = { %{scalars: table}, %{root_type: :scalars} }
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
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:all_my_scalars, map, reply)
    # reading
    assert(Map.merge(map, %{my_float: 3.124000072479248}) == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
  end

  test "read simple table" do
    table = {:table,
      [
        field_a: :short,
        field_b: :short,
      ]}
    schema = { %{table_a: table}, %{root_type: :table_a} }
    map = %{
      field_a: 42,
      field_b: 23,
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:simple_table, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
  end

  test "table with scalar vector" do
    table = {:table,
      [
        int_vector: {:vector, :int},
      ]}
    schema = { %{table_a: table}, %{root_type: :table_a} }
    map = %{
      int_vector: [23, 42, 666],
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:int_vector, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
  end

  test "fb with string" do
    table = {:table,
      [
        my_string: :string,
        my_bool: :bool,
      ]}
    schema = { %{string_table: table}, %{root_type: :string_table} }
    map = %{
      my_string: "hello",
      my_bool: true,
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:string_table, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))

  end

  test "read nested table" do
    outer = {:table,
      [
        value_outer: :short,
        inner: {:table, :inner},
      ]}

    inner = {:table,
      [
        value_inner: :short,
      ]}
    schema = { %{outer: outer, inner: inner}, %{root_type: :outer} }
    map = %{
      value_outer: 42,
      inner: %{ value_inner: 23 }
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    # reading
    assert_eq(:nested, map, reply)
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
  end

  test "write fb" do
    map = %{my_bool: true, my_string: "max", my_second_string: "minimum"}
    table = {:table, [
        {:my_bool, :bool},
        {:my_string, :string},
        {:my_second_string, :string},
        {:my_omitted_bool, :bool}
    ]}
    schema = {%{table_a: table}, %{root_type: :table_a}}
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:table_bool_string_string, map, reply)
  end

  def assert_eq(schema, map, binary) do
    map_looped = reference_map(schema, :erlang.iolist_to_binary(binary))
    assert( map == map_looped )
  end

  def reference_fb(schema, data) when is_map(data) do
    json  = Poison.encode!(data)
    port  = FlatbufferPort.open_port()
    :true = FlatbufferPort.load_schema(port, load_schema(schema))
    :ok   = port_response(port)
    :true = FlatbufferPort.json_to_fb(port, json)
    port_response(port)
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

  def load_schema(type) do
     File.read!("test/" <> Atom.to_string(type) <> ".fbs")
  end

  def flush_port_commands do
    receive do
      {_port, {:data, _}}  ->
        flush_port_commands
    after 0 ->
      :ok
    end
  end


end
