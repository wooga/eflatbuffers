defmodule EflatbuffersTest.Fuzz do
  use ExUnit.Case
  import TestHelpers

  test "fuzz based on doge schemas" do
    fuzz_schema({:doge, :game_state})
  end

  def fuzz_schema(schema_type) do
    map = Eflatbuffers.Generator.generate_from_schema(load_schema(schema_type))
    assert {:ok, fb} = Eflatbuffers.write(map, load_schema(schema_type))
    assert {:ok, map_re} = Eflatbuffers.read(:erlang.iolist_to_binary(fb), load_schema(schema_type))

    assert [] = compare(round_floats(map), round_floats(map_re))

    fb_flatc = reference_fb(schema_type,  map)
    #assert [] == compare(map, reference_map(schema_type, fb_flatc))


    assert_full_circle(schema_type, map)
  end

end
