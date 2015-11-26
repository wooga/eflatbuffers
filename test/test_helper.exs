defmodule TestHelpers do
  def load_schema({:doge, type}) do
    File.read!("test/doge_schemas/" <> Atom.to_string(type) <> ".fbs")
  end

  def load_schema(type) do
     File.read!("test/schemas/" <> Atom.to_string(type) <> ".fbs")
  end
end

ExUnit.start()
