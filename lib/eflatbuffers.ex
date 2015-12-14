defmodule Eflatbuffers do

  def parse_schema(schema_str) do
    Eflatbuffers.Schema.parse(schema_str)
  end

  def parse_schema!(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema}   -> schema
      error           -> throw error
    end
  end

  def write!(map, schema_str) when is_binary(schema_str) do
    write!(map, parse_schema!(schema_str))
  end

  def write!(map, {_, %{root_type: root_type} = options} = schema) do
    root_table = [<< vtable_offset :: little-size(16) >> | _] = Eflatbuffers.Writer.write({:table, %{ name: root_type }}, map, [], schema)

    file_identifier =
      case Map.get(options, :file_identifier) do
        << bin :: size(32) >> -> << bin :: size(32) >>
        _                     -> << 0   :: size(32) >>
      end

    [<< (vtable_offset + 8) :: little-size(32) >>, file_identifier, root_table]
  end

  def write(map, schema_str) when is_binary(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema} -> write(map, schema)
      error         -> error
    end
  end

  def write(map, schema) do
    try do
      {:ok, write!(map, schema)}
    catch
      error -> error
    rescue
      error -> {:error, error}
    end
  end

  def read!(data, schema_str) when is_binary(schema_str) do
    read!(data, parse_schema!(schema_str))
  end

  def read!(data, {_, %{root_type: root_type}} = schema) do
    Eflatbuffers.Reader.read({:table, %{ name: root_type }}, 0, data, schema)
  end

  def read(data, schema_str) when is_binary(schema_str) do
    case parse_schema(schema_str) do
      {:ok, schema} -> read(data, schema)
      error         -> error
    end
  end

  def read(data, schema) do
    try do
      {:ok, read!(data, schema)}
    catch
      error -> error
    rescue
      error -> {:error, error}
    end
  end

end


