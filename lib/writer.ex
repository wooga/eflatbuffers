defmodule Eflatbuffers.Writer do
  alias Eflatbuffers.Utils

  def write({_, %{default: same}}, same, _, _) do
    []
  end

  def write({_, _}, nil, _, _) do
    []
  end

  def write({:bool, _options}, true, _, _) do
    <<1>>
  end

  def write({:bool, _options}, false, _, _) do
    <<0>>
  end

  def write({:byte, _options}, byte, _, _)
      when is_integer(byte) and byte >= -128 and byte <= 127 do
    <<byte::signed-size(8)>>
  end

  def write({:ubyte, _options}, byte, _, _) when is_integer(byte) and byte >= 0 and byte <= 255 do
    <<byte::unsigned-size(8)>>
  end

  def write({:short, _options}, integer, _, _)
      when is_integer(integer) and integer <= 32_767 and integer >= -32_768 do
    <<integer::signed-little-size(16)>>
  end

  def write({:ushort, _options}, integer, _, _)
      when is_integer(integer) and integer >= 0 and integer <= 65536 do
    <<integer::unsigned-little-size(16)>>
  end

  def write({:int, _options}, integer, _, _)
      when is_integer(integer) and integer >= -2_147_483_648 and integer <= 2_147_483_647 do
    <<integer::signed-little-size(32)>>
  end

  def write({:uint, _options}, integer, _, _)
      when is_integer(integer) and integer >= 0 and integer <= 4_294_967_295 do
    <<integer::unsigned-little-size(32)>>
  end

  def write({:float, _options}, float, _, _)
      when (is_float(float) or is_integer(float)) and float >= -3.4e+38 and float <= +3.4e+38 do
    <<float::float-little-size(32)>>
  end

  def write({:long, _options}, integer, _, _)
      when is_integer(integer) and integer >= -9_223_372_036_854_775_808 and
             integer <= 9_223_372_036_854_775_807 do
    <<integer::signed-little-size(64)>>
  end

  def write({:ulong, _options}, integer, _, _)
      when is_integer(integer) and integer >= 0 and integer <= 18_446_744_073_709_551_615 do
    <<integer::unsigned-little-size(64)>>
  end

  def write({:double, _options}, float, _, _)
      when (is_float(float) or is_integer(float)) and float >= -1.7e+308 and float <= +1.7e+308 do
    <<float::float-little-size(64)>>
  end

  # complex types

  def write({:string, _options}, string, _, _) when is_binary(string) do
    <<byte_size(string)::unsigned-little-size(32)>> <> string
  end

  def write({:vector, options}, values, path, schema) when is_list(values) do
    {type, type_options} = options.type
    vector_length = length(values)
    # we are putting the indices as [i] as a type
    # so if something goes wrong it's easy to see
    # that it was a vector index
    type_options_without_default = Map.put(type_options, :default, nil)

    index_types =
      for i <- :lists.seq(0, vector_length - 1), do: {[i], {type, type_options_without_default}}

    [<<vector_length::little-size(32)>>, data_buffer_and_data(index_types, values, path, schema)]
  end

  def write({:enum, options = %{name: enum_name}}, value, path, {tables, _} = schema)
      when is_binary(value) do
    {:enum, enum_options} = Map.get(tables, enum_name)
    members = enum_options.members
    {type, type_options} = enum_options.type
    # if we got handed some defaults from outside,
    # we put them in here
    type_options = Map.merge(type_options, options)
    value_atom = :erlang.binary_to_existing_atom(value, :utf8)
    index = Map.get(members, value_atom)

    case index do
      nil -> throw({:error, {:not_in_enum, value_atom, members}})
      _ -> write({type, type_options}, index, path, schema)
    end
  end

  # write a complete table
  def write({:table, %{name: table_name}}, map, path, {tables, _options} = schema)
      when is_map(map) and is_atom(table_name) do
    {:table, options} = Map.get(tables, table_name)
    fields = options.fields

    {names_types, values} =
      Enum.reduce(
        Enum.reverse(fields),
        {[], []},
        fn
          {name, {:union, %{name: union_name}}}, {type_acc, value_acc} ->
            {:union, options} = Map.get(tables, union_name)
            members = options.members

            case Map.get(map, String.to_atom(Atom.to_string(name) <> "_type")) do
              nil ->
                type_acc_new = [{{name}, {:byte, %{default: 0}}} | type_acc]
                value_acc_new = [0 | value_acc]
                {type_acc_new, value_acc_new}

              union_type ->
                union_type = String.to_atom(union_type)
                union_index = Map.get(members, union_type)

                type_acc_new = [
                  {{name}, {:byte, %{default: 0}}}
                  | [{name, {:table, %{name: union_type}}} | type_acc]
                ]

                value_acc_new = [union_index + 1 | [Map.get(map, name) | value_acc]]
                {type_acc_new, value_acc_new}
            end

          {name, type}, {type_acc, value_acc} ->
            {[{{name}, type} | type_acc], [Map.get(map, name) | value_acc]}
        end
      )

    # we are putting the keys as {key} as a type
    # so if something goes wrong it's easy to see
    # that it was a map key
    [data_buffer, data] = data_buffer_and_data(names_types, values, path, schema)
    vtable = vtable(data_buffer)
    springboard = <<:erlang.iolist_size(vtable) + 4::little-size(32)>>
    data_buffer_length = <<:erlang.iolist_size([springboard, data_buffer])::little-size(16)>>
    vtable_length = <<:erlang.iolist_size([vtable, springboard])::little-size(16)>>
    [vtable_length, data_buffer_length, vtable, springboard, data_buffer, data]
  end

  # fail if nothing matches
  def write({type, _options}, data, path, _) do
    throw({:error, {:wrong_type, type, data, Enum.reverse(path)}})
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
  def data_buffer_and_data(
        [_type | types],
        [nil | values],
        path,
        schema,
        {scalar_and_pointers, data, data_offset}
      ) do
    data_buffer_and_data(
      types,
      values,
      path,
      schema,
      {[[] | scalar_and_pointers], data, data_offset}
    )
  end

  def data_buffer_and_data(
        [{name, type} | types],
        [value | values],
        path,
        schema,
        {scalar_and_pointers, data, data_offset}
      ) do
    # for clean error reporting we
    # need to accumulate the names of tables (depth)
    # but not the indices for vectors (width)
    case Utils.scalar?(type) do
      true ->
        scalar_data = write(type, value, [name | path], schema)

        data_buffer_and_data(
          types,
          values,
          path,
          schema,
          {[scalar_data | scalar_and_pointers], data, data_offset}
        )

      false ->
        complex_data = write(type, value, [name | path], schema)
        complex_data_length = :erlang.iolist_size(complex_data)
        # for a table we do not point to the start but to the springboard
        data_pointer =
          case type do
            {:table, _} ->
              [vtable_length, data_buffer_length, vtable | _] = complex_data

              table_header_offset =
                :erlang.iolist_size([vtable_length, data_buffer_length, vtable])

              data_offset + table_header_offset

            _ ->
              data_offset
          end

        data_buffer_and_data(
          types,
          values,
          path,
          schema,
          {[data_pointer | scalar_and_pointers], [complex_data | data],
           complex_data_length + data_offset}
        )
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
    adjust_for_length(data_buffer, {[[] | acc], offset})
  end

  # this is a scalar, we just pass the data
  def adjust_for_length([scalar | data_buffer], {acc, offset}) when is_binary(scalar) do
    adjust_for_length(data_buffer, {[scalar | acc], offset + byte_size(scalar)})
  end

  # referenced data, we get it and recurse
  def adjust_for_length([pointer | data_buffer], {acc, offset}) when is_integer(pointer) do
    offset_new = offset + 4
    pointer_bin = <<pointer + offset_new::little-size(32)>>
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
        vtable(data_buffer, {[<<0::little-size(16)>> | acc], offset})

      scalar_or_pointer ->
        vtable(
          data_buffer,
          {[<<offset::little-size(16)>> | acc], offset + :erlang.iolist_size(scalar_or_pointer)}
        )
    end
  end

  def scalar?(:string), do: false
  def scalar?({:vector, _}), do: false
  def scalar?({:table, _}), do: false
  def scalar?({:enum, _}), do: true
  def scalar?(_), do: true
end
