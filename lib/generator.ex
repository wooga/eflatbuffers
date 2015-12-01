defmodule Eflatbuffers.Generator do

  @max_string_len 50
  @max_vector_len 10

  def generate_from_schema(schema_str) when is_binary(schema_str) do
    {:ok, {schema, %{root_type: root_type}}} = 
      schema_str
      |> Eflatbuffers.Schema.lexer
      |> :schema_parser.parse
    gen_type(schema, root_type)  
  end

  def gen_type(_schema, :byte) , do: random_num_signed(1)
  def gen_type(_schema, :ubyte), do: random_num_unsigned(1)
  
  def gen_type(_schema, :short), do: random_num_signed(2)
  def gen_type(_schema, :ushort), do: random_num_unsigned(2)

  def gen_type(_schema, :int), do: random_num_signed(4)  
  def gen_type(_schema, :uint), do: random_num_unsigned(4)

  def gen_type(_schema, :long), do: random_num_signed(8)
  def gen_type(_schema, :ulong), do: random_num_signed(8)
  
  def gen_type(_schema, :float), do: random_float(4)
  def gen_type(_schema, :double), do: random_float(8)
  
  def gen_type(_schema, :bool), do: random_bool

  def gen_type(_schema, :string), do: random_string(:random.uniform(@max_string_len))

  def gen_type(schema, {:vector, type}) do
    1..@max_vector_len
    |> Enum.map(fn(_) -> gen_type(schema,type) end)
  end

  def gen_type(_schema, {{:enum, _type}, options}) do
    [elem] = Enum.take_random(options, 1) 
    Atom.to_string(elem)
  end

  def gen_type(schema, {:union, types}) do
    [type] = Enum.take_random(types, 1)
    gen_type(schema, type)
  end

  def gen_type(schema, {:table, types}) do
    types
    |> Enum.map(fn({name, type}) -> {name, gen_type(schema, type)} end)
    |> Enum.into(%{})
  end

  def gen_type(schema, {type, _default}) do
    gen_type(schema, type)
  end

  def gen_type(schema, type) do
    case Map.get(schema, type) do
      nil      -> throw ("type not found: #{inspect(type)}")
      type_def -> gen_type(schema, type_def)
    end
  end

  ### random generators ###  
  
  def random_num_signed(size) do     
    bit_size = size * 8
    << num :: signed-size(bit_size) >> = random_bytes(size)
    num
  end

  def random_num_unsigned(size) do    
    bit_size = size * 8
    << num :: unsigned-size(bit_size) >> = random_bytes(size)
    num
  end

  def random_float(_) do     
    :random.uniform()
  end

  def random_bool() do
    case :random.uniform(2) do
      1 -> false
      2 -> true
    end
  end

  def random_string(size) do
    alphabet =  
      "abcdefghijklmnopqrstuvwxyz"
      <> "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      <> "0123456789"
    alphabet_length = alphabet |> String.length()
    Enum.map_join(1..size, fn(_) -> alphabet |> String.at(:random.uniform( alphabet_length ) - 1) end)
  end

  def random_bytes(size) do
    :crypto.rand_bytes(size)
  end

end