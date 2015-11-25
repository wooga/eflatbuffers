defmodule Eflatbuffers.Schema do

  @scalars [
    :string,
    :byte,  :ubyte, :bool,
    :short, :ushort,
    :int,   :uint,  :float,
    :long,  :ulong, :double,
  ]

  def lexer(schema_str) do
    {:ok, tokens, _} =
      to_char_list(schema_str)
      |> :schema_lexer.string
    tokens
  end

  def parse(schema_str) when is_binary(schema_str) do
    tokens = lexer(schema_str)
    case :schema_parser.parse(tokens) do
      {:ok, data} ->
        {:ok, correlate(data)}
      error ->
        error
    end
  end

  def correlate({entities, options}) do
    entities_corr =
    Enum.reduce(
      entities,
      %{},
      # for a tables we transform
      # the types to explicityl signify
      # vectors, tables, and enums
      fn({key, {:table, fields}}, acc) ->
        Map.put(
          acc,
          key,
          {
            :table,
            Enum.map(fields,
            fn({field_name, field_value}) -> {field_name, substitute_field(field_value, entities)} end)
          }
        )
        # for enums we change the list of options
        # into a map for faster lookup when
        # writing and reading
        ({key, {{:enum, type}, fields}}, acc) ->
          hash = Enum.reduce(
            Enum.with_index(fields),
            %{},
            fn({field, index}, hash_acc) ->
              Map.put(hash_acc, field, index) |> Map.put(index, field)
            end
          )
          Map.put(acc, key, {{:enum, type}, hash})
        # for scalars we keep
        # things as they are
        ({key, other}, acc) ->
          Map.put(acc, key, other)
      end
    )
    {entities_corr, options}
  end

  def substitute_field({:vector, field}, entities) do
    {:vector, substitute_field(field, entities)}
  end

  def substitute_field({field, default}, entities) do
    {substitute_field(field, entities), default}
  end

  def substitute_field(field_value, entities) do
    case Enum.member?(@scalars, field_value) do
      true ->
        field_value
      false ->
        substitute_with_entity(field_value, entities)
    end
  end

  def substitute_with_entity(field_value, entities) do
    case Map.get(entities, field_value) do
      nil ->
        throw({:error, {:entity_not_found, field_value}})
      {:table, _} ->
        {:table, field_value}
      {{:enum, _}, _} ->
        {:enum, field_value}
    end
  end

end
