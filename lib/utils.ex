defmodule Eflatbuffers.Utils do
  def scalar?({type, _options}), do: scalar?(type)
  def scalar?(:string), do: false
  def scalar?(:vector), do: false
  def scalar?(:table), do: false
  def scalar?(:enum), do: true
  def scalar?(_), do: true

  def scalar_size({type, _options}), do: scalar_size(type)
  def scalar_size(:byte), do: 1
  def scalar_size(:ubyte), do: 1
  def scalar_size(:bool), do: 1
  def scalar_size(:short), do: 2
  def scalar_size(:ushort), do: 2
  def scalar_size(:int), do: 4
  def scalar_size(:uint), do: 4
  def scalar_size(:float), do: 4
  def scalar_size(:long), do: 8
  def scalar_size(:ulong), do: 8
  def scalar_size(:double), do: 8
  def scalar_size(type), do: throw({:error, {:unknown_scalar, type}})

  def extract_scalar_type({:enum, %{name: enum_name}}, {tables, _options}) do
    {:enum, %{type: type}} = Map.get(tables, enum_name)
    type
  end

  def extract_scalar_type(type, _), do: type
end
