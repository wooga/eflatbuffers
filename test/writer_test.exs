defmodule EflatbuffersWriterTest do
  use ExUnit.Case

  ### 8 bit types

  test "write bytes" do
    assert << 255 >> == write(:byte, -1)
    assert {:error, {:wrong_type, :byte, 1000, []}} == catch_throw(write(:byte, 1000))
    assert {:error, {:wrong_type, :byte, "x", []}}  == catch_throw(write(:byte, "x"))
  end

  test "write ubytes" do
    assert << 42 >> == write(:ubyte, 42)
  end

  test "write bools" do
    assert << 1 >> == write(:bool, true)
    assert << 0 >> == write(:bool, false)
  end

  ### 16 bit types

  test "write ushort" do
    assert << 255, 255 >> == write(:ushort, 65_535)
    assert << 42,  0 >> == write(:ushort, 42)
    assert << 0, 0 >>     == write(:ushort, 0)
    assert {:error, {:wrong_type, :ushort, 65536123, []}} == catch_throw(write(:ushort, 65_536_123))
    assert {:error, {:wrong_type, :ushort, -1, []}}    == catch_throw(write(:ushort, -1))
  end

  test "write short" do
    assert << 255, 127 >> == write(:short, 32_767)
    assert << 0, 0 >>     == write(:short, 0)
    assert << 0, 128 >>     == write(:short, -32_768)
    assert {:error, {:wrong_type, :short, 32_768, []}}  == catch_throw(write(:short, 32_768))
    assert {:error, {:wrong_type, :short, -32_769, []}} == catch_throw(write(:short, -32_769))
  end

  ### 32 bit types
  ### 64 bit types


  ### complex types

  test "write strings" do
    assert << 3, 0, 0, 0 >> <> "max" == write(:string, "max")
    assert {:error, {:wrong_type, :byte, "max", []}} == catch_throw(write(:byte, "max"))
  end

  test "write vectors" do
    assert(
      [<<3, 0, 0, 0>>, [[<<1>>, <<1>>, <<0>>], []], ] ==
      Eflatbuffers.Writer.write({:vector, %{ type: { :bool, %{ default: 0 } } }}, [true, true, false], [], {%{}, %{}})
    )
    assert(
      [<<2, 0, 0, 0>>, [[<<8, 0, 0, 0>>, <<11, 0, 0, 0>>], [<<3, 0, 0, 0, 102, 111, 111>>, <<3, 0, 0, 0, 98, 97, 114>>]]] ==
      Eflatbuffers.Writer.write({:vector, %{ type: { :string, %{} } }}, ["foo", "bar"], [], {%{}, %{}})
    )
  end

  def write(type, data) do
    Eflatbuffers.Writer.write({type, %{}}, data, [], {%{}, %{}})
  end

  ### intermediate data

  test "data buffer" do
    data_buffer =  [
      [<<1>>, <<8, 0, 0, 0>>, <<11, 0, 0, 0>>, []],
      [<<3, 0, 0, 0, 109, 97, 120>>, <<7, 0, 0, 0, 109, 105, 110, 105, 109, 117, 109>>]
    ]
    reply = Eflatbuffers.Writer.data_buffer_and_data(
      [{:the_bool, {:bool, %{}}}, {:the_string, {:string, %{}}}, {:the_string2, {:string, %{}}}, {:the_bool2, {:bool, %{}}}],
      [true, "max", "minimum", nil],
      [],
      '_'
    )
    assert( data_buffer == reply)
  end

end
