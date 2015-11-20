Nonterminals root definition option fields field default.
Terminals  table struct enum union namespace root_type include attribute file_identifier file_extension float int bool string '}' '{' '(' ')' '[' ']' ';' ',' ':' '=' quote.
Rootsymbol root.

root -> definition : {'$1', #{}}.
root -> option     : {#{}, '$1'}.
root -> root definition : add_def('$1', '$2').
root -> root option     : add_opt('$1', '$2').

% options (non-quoted)
option -> namespace string ';' : #{get_name('$1') => get_value_atom('$2')}.
option -> root_type string ';' : #{get_name('$1') => get_value_atom('$2')}.

% options (quoted)
option -> include quote string quote ';'         : #{get_name('$1') => get_value_bin('$3')}.
option -> attribute quote string quote ';'       : #{get_name('$1') => get_value_bin('$3')}.
option -> file_identifier quote string quote ';' : #{get_name('$1') => get_value_bin('$3')}.
option -> file_extension quote string quote ';'  : #{get_name('$1') => get_value_bin('$3')}.

% definitions
definition -> table string '{' fields '}'  : #{get_value_atom('$2') => {table, '$4'} }.

fields -> field ';' : [ '$1' ].
fields -> field ';' fields : [ '$1' | '$3' ].

field -> string ':' string              : { get_value_atom('$1'), get_value_atom('$3') }.
field -> string ':' '[' string ']'      : { get_value_atom('$1'), {vector, get_value_atom('$4')}}.
field -> string ':' string '=' default  : { get_value_atom('$1'), {get_value_atom('$3'), '$5' }}.

default -> int      : get_value('$1').
default -> float    : get_value('$1').
default -> bool     : get_value('$1').
default -> string   : get_value_bin('$1').

Erlang code.

get_value_atom({_Token, _Line, Value}) -> list_to_atom(Value).
get_value_bin({_Token, _Line, Value})  -> list_to_binary(Value).
get_value({_Token, _Line, Value})      -> Value.

get_name({Token, _Line, _Value})  -> Token;
get_name({Token, _Line})          -> Token.

add_def({Defs, Opts}, Def) -> {maps:merge(Defs, Def), Opts}.
add_opt({Defs, Opts}, Opt) -> {Defs, maps:merge(Opts, Opt)}.