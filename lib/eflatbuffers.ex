defmodule Eflatbuffers do

  def write_fb(map, {tables, %{root_type: root_type}} = schema) do
    root_table = [<< vtable_offset :: little-size(16) >> | _] =
    write({:table, root_type}, map, schema)
    [<< (vtable_offset + 6) :: little-size(16) >>, << 0, 0, 0, 0 >>, root_table]
  end

  def read_fb(data, {tables, %{root_type: root_type}} = schema) do
    read({:table, root_type}, 0, data, schema)
  end

  def write(_, nil, _) do
    <<>>
  end

  def write(:bool, true, _) do
    << 1 >>
  end

  def write(:bool, false, _) do
    << 0 >>
  end

  def read(:bool, vtable_pointer, data, _) do
    case read_from_data_buffer(vtable_pointer, data, 8) do
      << 0 >> -> false
      << 1 >> -> true
    end
  end

  def write(:byte, byte, _) when is_integer(byte) and byte >= -128 and byte <= 127 do
    << byte :: signed-size(8) >>
  end

  def read(:byte, vtable_pointer, data, _) do
    << value :: signed-size(8) >> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def write(:ubyte, byte, _) when is_integer(byte) and byte >= 0 and byte <= 255 do
    << byte :: unsigned-size(8) >>
  end

  def read(:ubyte, vtable_pointer, data, _) do
    << value :: unsigned-size(8) >> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def write(:short, integer, _) when is_integer(integer) and integer <= 32_767 and integer >= -32_768 do
    << integer :: signed-little-size(16) >>
  end

  def read(:short, vtable_pointer, data, _) do
    << value :: signed-little-size(16) >> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def write(:ushort, integer, _) when is_integer(integer) and integer >= 0 and integer <= 65536 do
    << integer :: unsigned-little-size(16) >>
  end

  def read(:ushort, vtable_pointer, data, _) do
    << value :: unsigned-little-size(16) >> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def write(:int, integer, _) when is_integer(integer) and integer >= -2_147_483_648 and integer <= 2_147_483_647 do
    << integer :: signed-little-size(32) >>
  end

  def read(:int, vtable_pointer, data, _) do
    << value :: signed-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:uint, integer, _) when is_integer(integer) and integer >= 0 and integer <= 4_294_967_295 do
    << integer :: unsigned-little-size(32) >>
  end

  def read(:uint, vtable_pointer, data, _) do
    << value :: unsigned-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:float, float, _) when (is_float(float) or is_integer(float)) and float >= -3.4E+38 and float <= +3.4E+38 do
    << float :: float-little-size(32) >>
  end

  def read(:float, vtable_pointer, data, _) do
    << value :: float-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:long, integer, _) when is_integer(integer) and integer >= -9_223_372_036_854_775_808 and integer <= 9_223_372_036_854_775_807 do
    << integer :: signed-little-size(64) >>
  end

  def read(:long, vtable_pointer, data, _) do
    << value :: signed-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def write(:ulong, integer, _) when is_integer(integer) and integer >= 0 and integer <= 18_446_744_073_709_551_615 do
    << integer :: unsigned-little-size(64) >>
  end

  def read(:ulong, vtable_pointer, data, _) do
    << value :: unsigned-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def write(:double, float, _) when (is_float(float) or is_integer(float)) and float >= -1.7E+308 and float <= +1.7E+308 do
    << float :: float-little-size(64) >>
  end

  def read(:double, vtable_pointer, data, _) do
    << value :: float-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  # complex types

  def write(:string, string, _) when is_binary(string) do
    << byte_size(string) :: unsigned-little-size(32) >> <> string
  end

  def read(:string, vtable_pointer, data, _) do
    << string_offset :: unsigned-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    string_pointer = vtable_pointer + string_offset
    << _ :: binary-size(string_pointer), string_length :: unsigned-little-size(32), string :: binary-size(string_length), _ :: binary >> = data
    string
  end

  def write({:vector, type}, values, schema) when is_list(values) do
    vector_length = length(values)
    types = Enum.map(1..vector_length, fn(_) -> type end)
    [ << vector_length :: little-little-size(32) >>, data_buffer_and_data(types, values, schema) ]
  end

  def read({:vector, type}, vtable_pointer, data, schema) do
    << vector_offset :: unsigned-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    vector_pointer = vtable_pointer + vector_offset
    << _ :: binary-size(vector_pointer), vector_count :: unsigned-little-size(32), _ :: binary >> = data
    is_scalar = scalar?(type)
    read_vector_elements(type, is_scalar, vector_pointer + 4, vector_count, data, schema)
  end

  def read_vector_elements(_, _, _, 0, _, _) do
    []
  end

  def read_vector_elements(type, true, vector_pointer, vector_count, data, schema) do
    value  = read(type, vector_pointer, data, schema)
    offset = scalar_size(type)
    [value | read_vector_elements(type, true, vector_pointer + offset, vector_count - 1, data, schema)]
  end

  def read_vector_elements(type, false, vector_pointer, vector_count, data, schema) do
    value  = read(type, vector_pointer, data, schema)
    offset = 4
    [value | read_vector_elements(type, false, vector_pointer + offset, vector_count - 1, data, schema)]
  end


  # write a complete table
  def write({:table, table_name}, map, {tables, _options} = schema) when is_map(map) and is_atom(table_name) do
    {:table, fields}    = Map.get(tables, table_name)
    {types, values}     = Enum.reduce(Enum.reverse(fields), {[], []}, fn({name, type}, {type_acc, value_acc}) -> {[type | type_acc], [Map.get(map, name) | value_acc]} end)
    [data_buffer, data] = data_buffer_and_data(types, values, schema)
    vtable              = vtable(data_buffer)
    springboard         = << (:erlang.iolist_size(vtable) + 4) :: little-size(32) >>
    data_buffer_length  = << :erlang.iolist_size([springboard, data_buffer]) :: little-size(16) >>
    vtable_length       = << :erlang.iolist_size([vtable, springboard])      :: little-size(16) >>
    [vtable_length, data_buffer_length, vtable, springboard, data_buffer, data]
  end

  # read a complete table, given a pointer to the springboard
  def read({:table, table_name}, table_pointer_pointer, data, {tables, _options} = schema) when is_atom(table_name) do
    << _ :: binary-size(table_pointer_pointer), table_offset :: little-size(16), _ :: binary >> = data
    table_pointer = table_pointer_pointer + table_offset
    {:table, fields} = Map.get(tables, table_name)
    << _ :: binary-size(table_pointer), vtable_offset :: little-size(32), _ :: binary >> = data
    vtable_pointer = table_pointer - vtable_offset
    << _ :: binary-size(vtable_pointer), vtable_length :: little-size(16), _data_buffer_length :: little-size(16), _ :: binary >> = data
    vtable_fields_pointer = vtable_pointer + 4
    vtable_fields_length  = vtable_length  - 4
    << _ :: binary-size(vtable_fields_pointer), _ :: binary >> = data
    << _ :: binary-size(vtable_fields_pointer), vtable :: binary-size(vtable_fields_length), _ :: binary >> = data
    data_buffer_pointer = table_pointer
    read_table_fields(fields, vtable, data_buffer_pointer, data, schema)
  end

  def read_table_fields(fields, vtable, data_buffer_pointer, data, schema) do
    read_table_fields(fields, vtable, data_buffer_pointer, data, schema, %{})
  end

  def read_table_fields([], _, _, _, _, map) do
    map
  end

  def read_table_fields([{name, type} | fields], << data_offset :: little-size(16), vtable :: binary >>, data_buffer_pointer, data, schema, map) do
    data_pointer = data_buffer_pointer + data_offset
    value = read(type, data_pointer, data, schema)
    map_new = Map.put(map, name, value)
    read_table_fields(fields, vtable, data_buffer_pointer, data, schema, map_new)
  end

  # fail of nothing matches
  def write(type, data, _) do
    throw({:error, {:wrong_type, type, data}})
  end

  # fail of nothing matches
  def read(type, _, _, _) do
    throw({:error, {:unknown_type, type}})
  end

  # this is a utility that just reads data_size bytes from data after data_pointer
  def read_from_data_buffer(data_pointer, data, data_size) do
    << _ :: binary-size(data_pointer), value :: bitstring-size(data_size), _ :: binary >> = data
    value
  end

  # build up [data_buffer, data]
  # as part of a table or vector
  def data_buffer_and_data(types, values, schema) do
    data_buffer_and_data(types, values, schema, {[], [], 0})
  end
  def data_buffer_and_data([], [], _schema, {data_buffer, data, _}) do
    [adjust_for_length(data_buffer), Enum.reverse(data)]
  end

  def data_buffer_and_data([type | types], [value | values], schema, {scalar_and_pointers, data, data_offset}) do
    case scalar?(type) do
      true ->
        scalar_data = write(type, value, schema)
        data_buffer_and_data(types, values, schema, {[scalar_data | scalar_and_pointers], data, data_offset})
      false ->
        complex_data = write(type, value, schema)
        complex_data_length = :erlang.iolist_size(complex_data)
        # for a table we do not point to the start but to the springboard
        data_pointer =
        case type do
          {:table, _} ->
            [vtable_length, data_buffer_length, vtable | _] = complex_data
            table_header_offset = :erlang.iolist_size([vtable_length, data_buffer_length, vtable])
            data_offset + table_header_offset
          _ ->
            data_offset
        end
        data_buffer_and_data(types, values, schema, {[data_pointer | scalar_and_pointers], [complex_data | data], complex_data_length + data_offset})
    end
  end

  # so this is a mix of scalars (binary)
  # and unadjusted pointers (integers)
  # we adjust the pointers to account
  # for their poisition in the buffer
  def adjust_for_length(data_buffer) do
    adjust_for_length(data_buffer, {[], 0})
  end

  def adjust_for_length([], {acc, _}) do
    acc
  end

  # this is a scalar, we just pass the data
  def adjust_for_length([scalar | data_buffer], {acc, offset}) when is_binary(scalar) do
    adjust_for_length(data_buffer, {[scalar | acc], offset + byte_size(scalar)})
  end

  # referenced data, we get it and recurse
  def adjust_for_length([pointer | data_buffer], {acc, offset}) when is_integer(pointer) do
    offset_new = offset + 4
    pointer_bin = << (pointer + offset_new) :: little-size(32) >>
    adjust_for_length(data_buffer, {[pointer_bin | acc], offset_new})
  end

  # we get a nested structure so we pass it untouched
  def adjust_for_length([iolist | data_buffer], {acc, offset}) when is_list(iolist) do
    adjust_for_length(data_buffer, {[iolist | acc], offset + 4})
  end


  def vtable(data_buffer) do
    Enum.reverse(vtable(data_buffer, {[], 4}))
  end

  def vtable([], {acc, _offset}) do
    acc
  end
  def vtable([data | data_buffer], {acc, offset}) do
    case data do
      "" ->
        # this is an undefined value, we put a null pointer
        # and leave the offset untouched
        vtable(data_buffer, {[<< 0 :: little-size(16) >> | acc ], offset })
      scalar_or_pointer ->
        vtable(data_buffer, {[<< offset :: little-size(16) >> | acc ], offset + byte_size(scalar_or_pointer) })
    end
  end

  def flatten_intermediate_data_buffer(data_buffer) do
    Enum.reverse(flatten_intermediate_data_buffer(data_buffer, []))
  end
  def flatten_intermediate_data_buffer([], acc) do
    acc
  end
  def flatten_intermediate_data_buffer([{_name, value} | data_buffer], acc) do
    flatten_intermediate_data_buffer(data_buffer, [value | acc])
  end

  def scalar?(:string),      do: false
  def scalar?({:vector, _}), do: false
  def scalar?({:table,  _}), do: false
  def scalar?(_),            do: true

  def scalar_size(:byte ), do: 1
  def scalar_size(:ubyte), do: 1
  def scalar_size(:bool ), do: 1

  def scalar_size(:short ), do: 2
  def scalar_size(:ushort), do: 2

  def scalar_size(:int  ), do: 4
  def scalar_size(:uint ), do: 4
  def scalar_size(:float), do: 4

  def scalar_size(:long  ), do: 8
  def scalar_size(:ulong ), do: 8
  def scalar_size(:double), do: 8

  def scalar_size(type), do: throw({:error, {:unknown_scalar, type}})

end
