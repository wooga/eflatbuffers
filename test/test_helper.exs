ExUnit.start()

defmodule TestHelpers do
  use ExUnit.Case

  def load_schema({:doge, type}) do
    File.read!("test/complex_schemas/" <> Atom.to_string(type) <> ".fbs")
  end

  def load_schema(type) do
    File.read!("test/schemas/" <> Atom.to_string(type) <> ".fbs")
  end

  def assert_full_circle(schema_reference, input) do
    assert_full_circle(schema_reference, schema_reference, input)
  end

  def assert_full_circle(schema_reference, fbp_schema_reference, input) do
    schema = Eflatbuffers.Schema.parse!(load_schema(schema_reference))

    fbp_write = flatbuffer_port_write(fbp_schema_reference, input)

    # IO.inspect(fbp_write, label: "FBP WRITE")

    eflat_write = Eflatbuffers.write!(input, schema)

    # IO.inspect(eflat_write, label: "EFLAT WRITE")

    # IO.inspect(Eflatbuffers.read!(eflat_write, schema), label: "EFLAT READ OF EFLAT WRITE")

    fbp_read = flatbuffer_port_read(fbp_schema_reference, eflat_write)

    # IO.inspect(fbp_read, label: "FBP READ OF EFLAT WRITE")

    eflat_read = Eflatbuffers.read!(fbp_write, schema)

    # IO.inspect(eflat_read, label: "EFLAT READ OF FBP WRITE")

    # FBP READ OF EFLAT WRITE == EFLAT READ OF FBP WRITE
    diff = compare_with_defaults(round_floats(fbp_read), round_floats(eflat_read), schema)

    # IO.inspect(diff, label: "DIFF")

    assert [] == diff
  end

  def assert_eq(schema, map, binary) do
    map_looped = flatbuffer_port_read(schema, binary)

    assert [] ==
             compare_with_defaults(
               round_floats(map),
               round_floats(map_looped),
               Eflatbuffers.Schema.parse!(load_schema(schema))
             )
  end

  def flatbuffer_port_write(schema, data) when is_map(data) do
    json = Poison.encode!(data)
    port = FlatbufferPort.open_port()
    true = FlatbufferPort.load_schema(port, load_schema(schema))
    :ok = port_response(port)
    true = FlatbufferPort.json_to_fb(port, json)
    {:ok, reply} = port_response(port)
    reply
  end

  def flatbuffer_port_read(schema, data) do
    port = FlatbufferPort.open_port()
    true = FlatbufferPort.load_schema(port, load_schema(schema))
    :ok = port_response(port)
    true = FlatbufferPort.fb_to_json(port, data)
    {:ok, json} = port_response(port)

    Poison.decode!(json, [:return_maps, keys: :atoms])
  end

  def port_response(port) do
    receive do
      {^port, {:data, data}} ->
        FlatbufferPort.parse_reponse(data)
    after
      3000 ->
        :timeout
    end
  end

  def flush_port_commands do
    receive do
      {_port, {:data, _}} ->
        flush_port_commands()
    after
      0 ->
        :ok
    end
  end

  def round_floats(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {k, round_floats(v)} end)
    |> Enum.into(%{})
  end

  def round_floats(list) when is_list(list), do: Enum.map(list, &round_floats/1)
  def round_floats(float) when is_float(float), do: round(float)
  def round_floats(other), do: other

  def compare_with_defaults(a, b, schema) do
    {tables, _} = schema

    default_enums =
      case Map.values(tables)
           |> Enum.filter(fn {type, _} -> type == :enum end)
           |> Enum.map(fn {:enum, options} -> options.members end) do
        [] -> []
        members -> Enum.map(members, fn e -> Atom.to_string(Map.get(e, 0)) end)
      end

    default_scalars =
      Map.values(tables)
      |> Enum.filter(fn {type, _} -> type == :table end)
      |> Enum.map(fn {:table, options} ->
        Enum.map(options.fields, fn
          {_, {_, %{default: default}}} -> default
          _ -> nil
        end)
      end)

    defaults = Enum.uniq(List.flatten(default_enums ++ default_scalars ++ [0.0, 0, false]))
    diff = compare(a, b)
    # since we write defaults to the json and flatc doesn't
    # we have to account for that
    Enum.reduce(
      diff,
      [],
      fn {path, {eflat, cflat}}, acc ->
        case {eflat, cflat} do
          {:undefined, value} ->
            case Enum.member?(defaults, value) do
              true -> acc
              false -> [{path, {eflat, cflat}} | acc]
            end

          _ ->
            [{path, {eflat, cflat}} | acc]
        end
      end
    )
  end

  def compare(a, b) do
    List.flatten(compare(a, b, []))
  end

  def compare(same, same, _) do
    []
  end

  def compare(a, b, path) when is_map(a) and is_map(b) do
    keys = Enum.uniq(Map.keys(a) ++ Map.keys(b))

    Enum.map(
      keys,
      fn key ->
        compare(Map.get(a, key, :undefined), Map.get(b, key, :undefined), path ++ [{key}])
      end
    )
    |> List.flatten()
  end

  def compare(a, b, path) when is_list(a) and is_list(b) do
    max_index = Enum.max([length(a), length(b)]) - 1

    Enum.map(
      0..max_index,
      fn index ->
        compare(Enum.at(a, index, :undefined), Enum.at(b, index, :undefined), path ++ [[index]])
      end
    )
    |> List.flatten()
  end

  def compare(a, b, path) do
    {path, {a, b}}
  end
end
