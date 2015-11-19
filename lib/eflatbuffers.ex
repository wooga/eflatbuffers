defmodule Eflatbuffers do

  def write_fb(map, {tables, %{root_type: root_type}}) do
    root_table = [<< vtable_offset :: little-size(16) >> | _] =
    write(Map.get(tables, root_type), map)
    [<< (vtable_offset + 6) :: little-size(16) >>, << 0, 0, 0, 0 >>, root_table]
  end

  def read_fb(<< root_table_pointer :: little-size(16), _ :: binary >> = data, {tables, %{root_type: root_type}}) do
    read(Map.get(tables, root_type), root_table_pointer, data)
  end

  def write(_, nil) do
    <<>>
  end

  def write(:bool, true) do
    << 1 >>
  end

  def write(:bool, false) do
    << 0 >>
  end

  def write(:byte, byte) when is_integer(byte) and byte >= -128 and byte <= 127 do
    << byte :: signed-size(8) >>
  end

  def write(:ubyte, byte) when is_integer(byte) and byte >= 0 and byte <= 255 do
    << byte :: unsigned-size(8) >>
  end

  def write(:short, integer) when is_integer(integer) and integer <= 32_767 and integer >= -32_768 do
    << integer :: little-size(16) >>
  end

  def write(:ushort, integer) when is_integer(integer) and integer >= 0 and integer <= 65536 do
    << integer :: little-size(16) >>
  end

  def write(:int, integer) when is_integer(integer) and integer >= -2_147_483_648 and integer <= 2_147_483_647 do
    << integer :: signed-little-size(32) >>
  end

  def write(:uint, integer) when is_integer(integer) and integer >= 0 and integer <= 4_294_967_295 do
    << integer :: little-size(32) >>
  end

  def write(:float, float) when (is_float(float) or is_integer(float)) and float >= -3.4E+38 and float <= +3.4E+38 do
    << float :: float-little-size(32) >>
  end

  def write(:long, integer) when is_integer(integer) and integer >= -9_223_372_036_854_775_808 and integer <= 9_223_372_036_854_775_807 do
    << integer :: signed-little-size(64) >>
  end

  def write(:ulong, integer) when is_integer(integer) and integer >= 0 and integer <= 18_446_744_073_709_551_615 do
    << integer :: unsigned-little-size(64) >>
  end

  def write(:double, float) when (is_float(float) or is_integer(float)) and float >= -1.7E+308 and float <= +1.7E+308 do
    << float :: float-little-size(64) >>
  end

  def write(:string, string) when is_binary(string) do
    << byte_size(string) :: little-little-size(32) >> <> string
  end

  def write({:vector, type}, list) when is_list(list) do
    [ << length(list) :: little-little-size(32) >>, Enum.map(list, fn(e) -> write(type, e) end)]
  end


  def write({:table, fields}, map) when is_map(map) and is_list(fields) do
    [intermediate_data_buffer, data] = data_buffer_and_data(fields, map)
    vtable              = vtable(fields, intermediate_data_buffer)
    data_buffer         = flatten_intermediate_data_buffer(intermediate_data_buffer)
    springboard         = << (:erlang.iolist_size(vtable) + 4) :: little-size(32) >>
    data_buffer_length  = << :erlang.iolist_size([springboard, data_buffer]) :: little-size(16) >>
    vtable_length       = << :erlang.iolist_size([vtable, springboard])      :: little-size(16) >>
    [vtable_length, data_buffer_length, vtable, springboard, data_buffer, data]
  end

  def read({:table, fields}, table_pointer, data) do
    << _ :: binary-size(table_pointer), vtable_offset :: little-size(32), _ :: binary >> = data
    vtable_pointer = table_pointer - vtable_offset
    << _ :: binary-size(vtable_pointer), vtable_length :: little-size(16), _ :: binary >> = data
    vtable_content_pointer = vtable_pointer + 2
    vtable_content_length  = vtable_length  - 2
    read_fields(fields, vtable_content_pointer, data)
  end

  def read_fields(fields, vtable_content_pointer, data) do
    read_fields(fields, vtable_content_pointer, data, %{})
  end

  def read_fields([], _, _, map) do
    map
  end

  def read_fields([{name, type} | fields], vtable_pointer, data, map) do
    value = read(type, vtable_pointer, data)
    map_new = Map.put(map, name, value)
    read_fields(fields, vtable_pointer + 2, data, map_new)
  end


  def read(:short, vtable_pointer, data) do
    << _ :: binary-size(vtable_pointer), data_offset :: little-size(16), _ :: binary >> = data
    data_pointer = vtable_pointer + data_offset + 2
    << _ :: binary-size(data_pointer), value :: little-size(16), _ :: binary >> = data
    value
  end

  def write(type, data) do
    throw({:error, {:wrong_type, type, data}})
  end

  def data_buffer_and_data(fields, map) do
    data_buffer_and_data(fields, map, {[], [], 0})
  end
  def data_buffer_and_data([], _, {data_buffer, data, _}) do
    [adjust_for_length(data_buffer), Enum.reverse(data)]
  end

  def data_buffer_and_data([{name, type} | fields], map, {scalar_and_pointers, data, data_offset}) do
    case scalar?(type) do
      true ->
        scalar_data = write(type, Map.get(map, name))
        data_buffer_and_data(fields, map, {[{name, scalar_data} | scalar_and_pointers], data, data_offset})
      false ->
        complex_data = write(type, Map.get(map, name))
        complex_data_length = :erlang.iolist_size(complex_data)
        data_buffer_and_data(fields, map, {[{name, data_offset} | scalar_and_pointers], [complex_data | data], complex_data_length + data_offset})
    end
  end

  # so this is a mix of scalars (binary)
  # and unadjusted pointers (integers)
  def adjust_for_length(data_buffer) do
    adjust_for_length(data_buffer, {[], 0})
  end

  def adjust_for_length([], {acc, _}) do
    acc
  end

  def adjust_for_length([{name, scalar} | data_buffer], {acc, offset}) when is_binary(scalar) do
    adjust_for_length(data_buffer, {[{name, scalar} | acc], offset + byte_size(scalar)})
  end

  def adjust_for_length([{name, pointer} | data_buffer], {acc, offset}) when is_integer(pointer) do
    offset_new = offset + 4
    pointer_bin = << (pointer + offset_new) :: little-size(32) >>
    adjust_for_length(data_buffer, {[{name, pointer_bin} | acc], offset_new})
  end

  def vtable(fields, data_buffer) do
    Enum.reverse(vtable(fields, data_buffer, {[], 4}))
  end

  def vtable([], [], {acc, _offset}) do
    acc
  end
  def vtable([{name_field, _type} | fields], [{name_data, data} | data_buffer], {acc, offset}) do
    name_field = name_data
    case data do
      "" ->
        # this is an undefined value, we put a null pointer
        # and leave the offset untouched
        vtable(fields, data_buffer, {[<< 0 :: little-size(16) >> | acc ], offset })
      scalar_or_pointer ->
        vtable(fields, data_buffer, {[<< offset :: little-size(16) >> | acc ], offset + byte_size(scalar_or_pointer) })
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
  def scalar?(_),            do: true

end
