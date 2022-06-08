defmodule Eflatbuffers.Generator do
  @defaults %{
    max_string_len: 100,
    max_vector_len: 15,
    skip_key_probability: 0.1,
    default_probability: 0.1
  }

  def map_from_schema(schema_str, opts \\ %{}) when is_binary(schema_str) do
    {:ok, {schema, %{root_type: root_type}}} =
      schema_str
      |> Eflatbuffers.Schema.lexer()
      |> :schema_parser.parse()

    gen_type(schema, root_type, Map.merge(@defaults, opts))
  end

  def gen_type(_schema, :byte, opts), do: random_num_signed(1) |> maybe_default(0, opts)
  def gen_type(_schema, :ubyte, opts), do: random_num_unsigned(1) |> maybe_default(0, opts)

  def gen_type(_schema, :short, opts), do: random_num_signed(2) |> maybe_default(0, opts)
  def gen_type(_schema, :ushort, opts), do: random_num_unsigned(2) |> maybe_default(0, opts)

  def gen_type(_schema, :int, opts), do: random_num_signed(4) |> maybe_default(0, opts)
  def gen_type(_schema, :uint, opts), do: random_num_unsigned(4) |> maybe_default(0, opts)

  def gen_type(_schema, :long, opts), do: random_num_signed(8) |> maybe_default(0, opts)
  def gen_type(_schema, :ulong, opts), do: random_num_signed(8) |> maybe_default(0, opts)

  def gen_type(_schema, :float, opts), do: random_float(4) |> maybe_default(0.0, opts)
  def gen_type(_schema, :double, opts), do: random_float(8) |> maybe_default(0.0, opts)

  def gen_type(_schema, :bool, opts), do: random_bool() |> maybe_default(false, opts)

  def gen_type(_schema, :string, opts), do: random_string(:rand.uniform(opts.max_string_len))

  def gen_type(schema, {:vector, type}, opts) do
    1..opts.max_vector_len
    |> Enum.map(fn _ -> gen_type(schema, type, opts) end)
  end

  def gen_type(_schema, {{:enum, _type}, enum_options}, _opts) do
    [elem] = Enum.take_random(enum_options, 1)
    Atom.to_string(elem)
  end

  def gen_type(schema, {:union, types}, opts) do
    [type] = Enum.take_random(types, 1)
    [Atom.to_string(type), gen_type(schema, type, opts)]
  end

  def gen_type(schema, {:table, types}, opts) do
    types
    |> Enum.filter(fn _ -> :rand.uniform() > opts.skip_key_probability end)
    |> Enum.map(fn {name, type} ->
      case gen_type(schema, type, opts) do
        [union_type, union_data] ->
          [{String.to_atom(Atom.to_string(name) <> "_type"), union_type}, {name, union_data}]

        data ->
          {name, data}
      end
    end)
    |> List.flatten()
    |> Enum.into(%{})
  end

  def gen_type(schema, {type, _default}, opts) do
    gen_type(schema, type, opts)
  end

  def gen_type(schema, type, opts) do
    case Map.get(schema, type) do
      nil -> throw("type not found: #{inspect(type)}")
      type_def -> gen_type(schema, type_def, opts)
    end
  end

  ### random generators ###

  def random_num_signed(size) do
    bit_size = size * 8
    <<num::signed-size(bit_size)>> = random_bytes(size)
    num
  end

  def random_num_unsigned(size) do
    bit_size = size * 8
    <<num::unsigned-size(bit_size)>> = random_bytes(size)
    num
  end

  def random_float(_) do
    :rand.uniform()
  end

  def random_bool() do
    case :rand.uniform(2) do
      1 -> false
      2 -> true
    end
  end

  def random_string(size) do
    alphabet =
      "abcdefghijklmnopqrstuvwxyz" <>
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" <>
        "0123456789"

    alphabet_length = alphabet |> String.length()
    Enum.map_join(1..size, fn _ -> alphabet |> String.at(:rand.uniform(alphabet_length) - 1) end)
  end

  def random_bytes(size) do
    :crypto.strong_rand_bytes(size)
  end

  def maybe_default(value, default, opts) do
    prob = opts.default_probability

    case :rand.uniform() do
      x when x < prob -> default
      _ -> value
    end
  end
end
