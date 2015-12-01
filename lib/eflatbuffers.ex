defmodule Eflatbuffers do

  ##############################################################################
  ## public API
  ##############################################################################

  def parse_schema(schema_str) do
    Eflatbuffers.Schema.parse(schema_str)
  end

  def parse_schema!(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema}   -> schema
      error           -> throw error
    end
  end

  def write_fb!(map, schema_str) when is_binary(schema_str) do
    write_fb!(map, parse_schema!(schema_str))
  end

  def write_fb!(map, {_, %{root_type: root_type} = options} = schema) do
    root_table = [<< vtable_offset :: little-size(16) >> | _] = write({:table, root_type}, map, [], schema)

    file_identifier =
      case Map.get(options, :file_identifier) do
        << bin :: size(32) >> -> << bin :: size(32) >>
        _                     -> << 0   :: size(32) >>
      end

    [<< (vtable_offset + 8) :: little-size(32) >>, file_identifier, root_table]
  end

  def write_fb(map, schema_str) when is_binary(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema} -> write_fb(map, schema)
      error         -> error
    end
  end

  def write_fb(map, schema) do
    try do
      {:ok, write_fb!(map, schema)}
    catch
      error -> error
    rescue
      error -> {:error, error}
    end
  end

  def read_fb!(data, schema_str) when is_binary(schema_str) do
    read_fb!(data, parse_schema!(schema_str))
  end

  def read_fb!(data, {_, %{root_type: root_type}} = schema) do
    read({:table, root_type}, 0, data, schema)
  end

  def read_fb(data, schema_str) when is_binary(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema} -> read_fb(data, schema)
      error         -> error
    end
  end

  def read_fb(data, schema) do
    try do
      {:ok, read_fb!(data, schema)}
    catch
      error -> error
    rescue
      error -> {:error, error}
    end
  end

  ##############################################################################
  ## private
  ##############################################################################

  def write(_, nil, _, _) do
    <<>>
  end

  def write(:bool, true, _, _) do
    << 1 >>
  end

  def write(:bool, false, _, _) do
    << 0 >>
  end

  def read(:bool, vtable_pointer, data, _) do
    case read_from_data_buffer(vtable_pointer, data, 8) do
      << 0 >> -> false
      << 1 >> -> true
    end
  end

  def write(:byte, byte, _, _) when is_integer(byte) and byte >= -128 and byte <= 127 do
    << byte :: signed-size(8) >>
  end

  def read(:byte, vtable_pointer, data, _) do
    << value :: signed-size(8) >> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def write(:ubyte, byte, _, _) when is_integer(byte) and byte >= 0 and byte <= 255 do
    << byte :: unsigned-size(8) >>
  end

  def read(:ubyte, vtable_pointer, data, _) do
    << value :: unsigned-size(8) >> = read_from_data_buffer(vtable_pointer, data, 8)
    value
  end

  def write(:short, integer, _, _) when is_integer(integer) and integer <= 32_767 and integer >= -32_768 do
    << integer :: signed-little-size(16) >>
  end

  def read(:short, vtable_pointer, data, _) do
    << value :: signed-little-size(16) >> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def write(:ushort, integer, _, _) when is_integer(integer) and integer >= 0 and integer <= 65536 do
    << integer :: unsigned-little-size(16) >>
  end

  def read(:ushort, vtable_pointer, data, _) do
    << value :: unsigned-little-size(16) >> = read_from_data_buffer(vtable_pointer, data, 16)
    value
  end

  def write(:int, integer, _, _) when is_integer(integer) and integer >= -2_147_483_648 and integer <= 2_147_483_647 do
    << integer :: signed-little-size(32) >>
  end

  def read(:int, vtable_pointer, data, _) do
    << value :: signed-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:uint, integer, _, _) when is_integer(integer) and integer >= 0 and integer <= 4_294_967_295 do
    << integer :: unsigned-little-size(32) >>
  end

  def read(:uint, vtable_pointer, data, _) do
    << value :: unsigned-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:float, float, _, _) when (is_float(float) or is_integer(float)) and float >= -3.4E+38 and float <= +3.4E+38 do
    << float :: float-little-size(32) >>
  end

  def read(:float, vtable_pointer, data, _) do
    << value :: float-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    value
  end

  def write(:long, integer, _, _) when is_integer(integer) and integer >= -9_223_372_036_854_775_808 and integer <= 9_223_372_036_854_775_807 do
    << integer :: signed-little-size(64) >>
  end

  def read(:long, vtable_pointer, data, _) do
    << value :: signed-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def write(:ulong, integer, _, _) when is_integer(integer) and integer >= 0 and integer <= 18_446_744_073_709_551_615 do
    << integer :: unsigned-little-size(64) >>
  end

  def read(:ulong, vtable_pointer, data, _) do
    << value :: unsigned-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  def write(:double, float, _, _) when (is_float(float) or is_integer(float)) and float >= -1.7E+308 and float <= +1.7E+308 do
    << float :: float-little-size(64) >>
  end

  def read(:double, vtable_pointer, data, _) do
    << value :: float-little-size(64) >> = read_from_data_buffer(vtable_pointer, data, 64)
    value
  end

  # complex types

  def write(:string, string, _, _) when is_binary(string) do
    << byte_size(string) :: unsigned-little-size(32) >> <> string
  end

  def read(:string, vtable_pointer, data, _) do
    << string_offset :: unsigned-little-size(32) >> = read_from_data_buffer(vtable_pointer, data, 32)
    string_pointer = vtable_pointer + string_offset
    << _ :: binary-size(string_pointer), string_length :: unsigned-little-size(32), string :: binary-size(string_length), _ :: binary >> = data
    string
  end

  def write({:vector, type}, values, path, schema) when is_list(values) do
    vector_length = length(values)
    index_types = for i <- :lists.seq(0, (vector_length - 1)), do: {i, type}
    [ << vector_length :: little-size(32) >>, data_buffer_and_data(index_types, values, path, schema) ]
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
    offset = scalar_size(extract_scalar_type(type, schema))
    [value | read_vector_elements(type, true, vector_pointer + offset, vector_count - 1, data, schema)]
  end

  def read_vector_elements(type, false, vector_pointer, vector_count, data, schema) do
    value  = read(type, vector_pointer, data, schema)
    offset = 4
    [value | read_vector_elements(type, false, vector_pointer + offset, vector_count - 1, data, schema)]
  end

  def write({:enum, enum_name}, value, path, {tables, _} = schema) when is_binary(value) do
    {{:enum, type}, options} =  Map.get(tables, enum_name)
    value_atom = :erlang.binary_to_existing_atom(value, :utf8)
    index = Map.get(options, value_atom)
    case index do
      nil -> throw({:error, {:not_in_enum, value_atom, options}})
      _   -> write(type, index, path, schema)
    end
  end

  def read({:enum, enum_name}, vtable_pointer, data, {tables, _options} = schema) do
    {{:enum, type}, options} =  Map.get(tables, enum_name)
    index = read(type, vtable_pointer, data, schema)
    value_atom = Map.get(options, index)
    Atom.to_string(value_atom)
  end

  # write a complete table
  def write({:table, table_name}, map, path, {tables, _options} = schema) when is_map(map) and is_atom(table_name) do
    {:table, fields} = Map.get(tables, table_name)
    {names_types, values} =
      Enum.reduce(
        Enum.reverse(fields),
        {[], []},
        fn({name, {:union, union_name}}, {type_acc, value_acc}) ->
            {:union, union_options} = Map.get(tables, union_name)
            union_type              = Map.get(map, String.to_atom(Atom.to_string(name) <> "_type")) |> String.to_atom
            union_index             = Map.get(union_options, union_type)
            type_acc_new  = [{name, :byte}   | [{name, {:table, union_type}} | type_acc]]
            value_acc_new = [union_index + 1 | [Map.get(map, name)   | value_acc]]
            {type_acc_new, value_acc_new}
          ({name, type}, {type_acc, value_acc}) ->
            {[{name, type} | type_acc], [Map.get(map, name) | value_acc]}
        end
      )
    [data_buffer, data] = data_buffer_and_data(names_types, values, path, schema)
    vtable              = vtable(data_buffer)
    springboard         = << (:erlang.iolist_size(vtable) + 4) :: little-size(32) >>
    data_buffer_length  = << :erlang.iolist_size([springboard, data_buffer]) :: little-size(16) >>
    vtable_length       = << :erlang.iolist_size([vtable, springboard])      :: little-size(16) >>
    [vtable_length, data_buffer_length, vtable, springboard, data_buffer, data]
  end

  # read a complete table, given a pointer to the springboard
  def read({:table, table_name}, table_pointer_pointer, data, {tables, _options} = schema) when is_atom(table_name) do
    << _ :: binary-size(table_pointer_pointer), table_offset :: little-size(32), _ :: binary >> = data
    table_pointer = table_pointer_pointer + table_offset
    {:table, fields} = Map.get(tables, table_name)
    << _ :: binary-size(table_pointer), vtable_offset :: little-signed-size(32), _ :: binary >> = data
    vtable_pointer = table_pointer - vtable_offset
    << _ :: binary-size(table_pointer), inspect :: binary >> = data
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

  # we might still have more fields but we ran out of vtable slots
  # this happens if the schema has more fields than the data (schema evolution)
  def read_table_fields(_, <<>>, _, _, _, map) do
    map
  end

  def read_table_fields([{name, {:union, union_type}} | fields], << data_offset :: little-size(16), vtable :: binary >>, data_buffer_pointer, data, {tables, _options} = schema, map) do
    # for a union an int field named $fieldname$_type is prefixed
    union_index = read(:byte, data_buffer_pointer + data_offset, data, schema)
    {:union, options} = Map.get(tables, union_type)
    union_type        = Map.get(options, union_index - 1)
    union_type_key    = String.to_atom(Atom.to_string(name) <> "_type")
    map_new           = Map.put(map, union_type_key, Atom.to_string(union_type))
    read_table_fields([{name, {:table, union_type}} | fields], vtable, data_buffer_pointer, data, schema, map_new)
  end
  # we find a null pointer
  # so we don't set the value
  def read_table_fields([{_, _} | fields], << 0, 0, vtable :: binary >>, data_buffer_pointer, data, schema, map) do
    read_table_fields(fields, vtable, data_buffer_pointer, data, schema, map)
  end
  def read_table_fields([{name, type} | fields], << data_offset :: little-size(16), vtable :: binary >>, data_buffer_pointer, data, schema, map) do
    map_new =
    case data_offset do
      0 ->
        map
      _ ->
        value = read(type, data_buffer_pointer + data_offset, data, schema)
        Map.put(map, name, value)
    end
    read_table_fields(fields, vtable, data_buffer_pointer, data, schema, map_new)
  end

  # fail if nothing matches
  def write(type, data, path, _) do
    throw({:error, {:wrong_type, type, data, Enum.reverse(path)}})
  end

  # fail if nothing matches
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
  def data_buffer_and_data(types, values, path, schema) do
    data_buffer_and_data(types, values, path, schema, {[], [], 0})
  end
  def data_buffer_and_data([], [], _path, _schema, {data_buffer, data, _}) do
    [adjust_for_length(data_buffer), Enum.reverse(data)]
  end

  # value is nil so we put a null pointer
  def data_buffer_and_data([_type | types], [nil | values], path, schema, {scalar_and_pointers, data, data_offset}) do
    data_buffer_and_data(types, values, path, schema, {[[] | scalar_and_pointers], data, data_offset})
  end
  def data_buffer_and_data([{name, type} | types], [value | values], path, schema, {scalar_and_pointers, data, data_offset}) do
    # for clean error reporting we
    # need to accumulate the names of tables (depth)
    # but not the indices for vectors (width)
    recurse_path =
      case is_integer(name) do
        true  -> path
        false -> [name|path]
      end
    case scalar?(type) do
      true ->
        scalar_data = write(type, value, [name|path], schema)
        data_buffer_and_data(types, values, recurse_path, schema, {[scalar_data | scalar_and_pointers], data, data_offset})
      false ->
        complex_data = write(type, value, [name|path], schema)
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
        data_buffer_and_data(types, values, recurse_path, schema, {[data_pointer | scalar_and_pointers], [complex_data | data], complex_data_length + data_offset})
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

  # this is null pointers, we pass
  def adjust_for_length([[] | data_buffer], {acc, offset}) do
    adjust_for_length(data_buffer, {[[]|acc], offset})
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
      [] ->
        # this is an undefined value, we put a null pointer
        # and leave the offset untouched
        vtable(data_buffer, {[<< 0 :: little-size(16) >> | acc ], offset })
      scalar_or_pointer ->
        vtable(data_buffer, {[<< offset :: little-size(16) >> | acc ], offset + :erlang.iolist_size(scalar_or_pointer) })
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

  def extract_scalar_type({:enum, enum_name}, {tables, _options}) do
    {{:enum, type}, _options} =  Map.get(tables, enum_name)
    type
  end

  def extract_scalar_type(type, _), do: type


  def scalar?(:string),      do: false
  def scalar?({:vector, _}), do: false
  def scalar?({:table,  _}), do: false
  def scalar?({:enum,  _}),  do: true
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


