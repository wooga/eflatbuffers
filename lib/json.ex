defmodule Eflatbuffers.Json do

  def parse(json) do
    atomify(:jiffy.decode(json, [:return_maps]))
  end

  def atomify(list) when is_list(list) do
    Enum.map(list, &atomify/1)
  end

  def atomify(map) when is_map(map) do
    Enum.reduce(
      map,
      %{},
      fn({k, v}, acc) ->
        Map.put(acc, String.to_atom(k), atomify(v))
      end
    )
  end

  def atomify(any) do
    any
  end


end
