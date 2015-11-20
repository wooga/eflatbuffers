Nonterminals definition definitions fields.
Terminals  table struct enum union namespace root_type include attribute file_identifier file_extension float int string newline whitespace '}' '{' '(' '(' '[' ']' ';' ',' ':' '=' quote.
Rootsymbol definitions.

definitions -> definition : '$1'.
definitions -> definitions definition : maps:merge('$1', '$2').

% non quoted definitions
definition -> namespace whitespace string ';'       : #{get_name('$1') => get_value('$3')}.
definition -> root_type whitespace string ';'       : #{get_name('$1') => get_value('$3')}.

% quoted defintions
definition -> include whitespace quote string quote ';'         : #{get_name('$1') => get_value('$4')}.
definition -> attribute whitespace quote string quote ';'       : #{get_name('$1') => get_value('$4')}.
definition -> file_identifier whitespace quote string quote ';' : #{get_name('$1') => get_value('$4')}.
definition -> file_extension whitespace quote string quote ';'  : #{get_name('$1') => get_value('$4')}.

% definitions with field blocks
% definition -> table whitespace string whitespace




Erlang code.

get_value({_Token, _Line, Value}) -> list_to_binary(Value).

get_name({Token, _Line, _Value})  -> atom_to_binary(Token, utf8);
get_name({Token, _Line})          -> atom_to_binary(Token, utf8).


