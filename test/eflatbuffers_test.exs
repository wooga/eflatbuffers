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

  test "read table with missing values" do
    table = {:table,
      [
        field_a: :short,
        field_b: :string,
        #field_c: {:table, :table_a}
      ]}
    schema = { %{table_a: table}, %{root_type: :table_a} }
    map = %{}
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    # reading
    assert_eq(:simple_table, map, reply)
    # flatc sets the internal defaults
    # for scalars
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

  test "table with string vector" do
    table = {:table,
      [
        string_vector: {:vector, :string},
      ]}
    schema = { %{string_vector_table: table},  %{root_type: :string_vector_table} }
    map = %{
      string_vector: ["foo", "bar", "baz"],
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:string_vector, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
  end

  test "table with enum" do
    tables = %{
      :enum_inner =>
        {{:enum, :int}, %{0 => :Red, 1 => :Green, 2 => :Blue, :Blue => 2, :Green => 1, :Red => 0}},
      :table_outer =>
        {:table, [enum_field: {:enum, :enum_inner}]}
    }
    schema = { tables, %{root_type: :table_outer} }
    map = %{
      enum_field: "Green",
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:enum_field, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
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
    reply = Eflatbuffers.write_fb(map, schema)
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
    # reading
  end

  test "table with table vector" do
    outer_table = {:table,
      [
        inner: {:vector, {:table, :inner}},
      ]}
    inner_table = {:table,
      [
        value_inner: :string,
      ]}
    schema = { %{outer: outer_table, inner: inner_table}, %{root_type: :outer} }
    map = %{
      inner: [%{value_inner: "aaa"}, %{value_inner: "bbbb"}, %{value_inner: "ccc"}],
    }
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert_eq(:table_vector, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
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
    reply = Eflatbuffers.write_fb(map, schema)
    #assert_eq(:table_vector, map, reply)
    # reading
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
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
    reply = Eflatbuffers.write_fb(map, schema)
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

  test "config debug fb" do
    {:ok, schema} = Eflatbuffers.Schema.parse(load_schema(:config_path))
    map = %{technologies: [%{category: "aaa"}, %{}]}
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    assert(map == Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema))
    assert_eq(:config_path, map, reply)
    # reading
  end

  test "config fb" do
    {:ok, schema} = Eflatbuffers.Schema.parse(load_schema({:doge, :config}))
    map = Poison.decode!(File.read!("test/doge_schemas/config.json"), [keys: :atoms])
    # writing
    reply = Eflatbuffers.write_fb(map, schema)
    reply_map  = Eflatbuffers.read_fb(:erlang.iolist_to_binary(reply), schema)

    assert round_floats(map) == round_floats(reply_map)

    looped_fb = Eflatbuffers.write_fb(reply_map, schema)
    assert looped_fb == reply

    assert_eq({:doge, :config}, map, reply)
  end

  test "fb with string" do
    table = {:table,
      [
        my_mood: "good",
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

  test "file identifier" do
    schema = {%{foo: {:table, [a: :bool]}}, %{root_type: :foo, file_identifier: "helo"}}
    reply = Eflatbuffers.write_fb(%{}, schema)
    assert << _ :: size(32) >> <> "helo" <> << _ :: binary >> = :erlang.iolist_to_binary(reply)
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

  def load_schema({:doge, type}) do
    File.read!("test/doge_schemas/" <> Atom.to_string(type) <> ".fbs")
  end

  def load_schema(type) do
     File.read!("test/schemas/" <> Atom.to_string(type) <> ".fbs")
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
