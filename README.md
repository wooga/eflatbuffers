# Eflatbuffers

This is a [flatbuffers](https://google.github.io/flatbuffers/) implementation in Elixir.

In contrast to existing implementations there is no need to compile code from a schema. Instead, data and schemas are processed dynamically at runtime, offering greater flexibility.

## Using Eflatbuffers

Schema file:
```
table Root {
  foreground:Color;
  background:Color;
}

table Color {
  red:   ubyte;
  green: ubyte;
  blue:  ubyte;
}
root_type Root;
```

Parsing the schema:
```elixir
iex(1)> schema = File.read!(path_to_schema) |> Eflatbuffers.Schema.parse!()
{%{Color: {:table,
    %{fields: [red: {:ubyte, %{default: 0}}, green: {:ubyte, %{default: 0}},
       blue: {:ubyte, %{default: 0}}],
      indices: %{blue: {2, {:ubyte, %{default: 0}}},
        green: {1, {:ubyte, %{default: 0}}},
        red: {0, {:ubyte, %{default: 0}}}}}},
   Root: {:table,
    %{fields: [foreground: {:table, %{name: :Color}},
       background: {:table, %{name: :Color}}],
      indices: %{background: {1, {:table, %{name: :Color}}},
        foreground: {0, {:table, %{name: :Color}}}}}}}, %{root_type: :Root}}
```

Serializing data:

```elixir
iex(2)> color_scheme = %{foreground: %{red: 128, green: 20, blue: 255}, background: %{red: 0, green: 100, blue: 128}}
iex(3)> color_scheme_fb = Eflatbuffers.write!(color_scheme, schema)
<<16, 0, 0, 0, 0, 0, 0, 0, 8, 0, 12, 0, 4, 0, 8, 0, 8, 0, 0, 0, 18, 0, 0, 0, 31,
  0, 0, 0, 10, 0, 7, 0, 4, 0, 5, 0, 6, 0, 10, 0, 0, 0, 128, 20, 255, 10, 0, 6,
  0, 0, ...>>
```

So we can `read` the whole thing which converts it back into a map:

```elixir
iex(4)> Eflatbuffers.read!(color_scheme_fb, schema)
%{background: %{blue: 128, green: 100, red: 0},
  foreground: %{blue: 255, green: 20, red: 128}}
```

Or we can `get` a portion with means it seeks into the flatbuffer and only deserializes the part below the path:
```elixir
iex(5)> Eflatbuffers.get!(color_scheme_fb, [:background], schema)
%{blue: 128, green: 100, red: 0}
iex(6)> Eflatbuffers.get!(color_scheme_fb, [:background, :green], schema)
100
```

## Comparing Eflatbufers to flatc

### features both in Eflatbufers and flatc

* tables
* scalars
* strings
* vectors
* unions
* enums
* defaults
* json to fb
* fb to json
* file identifier + validation
* random access
* validate file identifiers

### features only in Eflatbuffers

* vectors of enums

### features only in flatc

* shared strings
* shared vtables
* includes
* alignment
* additional attributes
* structs

### deviation of Eflatbuffers from flatc

* default values are written to json
