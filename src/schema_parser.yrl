Nonterminals root definition option fields field key_def value attribute_def attributes atoms atom.
Terminals  table enum union namespace root_type include attribute file_identifier file_extension float int bool string '}' '{' '(' ')' '[' ']' ';' ',' ':' '=' quote.
Rootsymbol root.

root -> definition      : {'$1', #{}}.
root -> option          : {#{}, '$1'}.
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
definition -> table string '{' fields '}'           : #{get_value_atom('$2') => {table, '$4'} }.
definition -> table string '{' '}'                  : #{get_value_atom('$2') => {table, []} }.
definition -> enum string ':' string '{' atoms '}'  : #{get_value_atom('$2') => {{enum, get_value_atom('$4')}, '$6' }}.
definition -> union string '{' atoms '}'            : #{get_value_atom('$2') => {union, '$4'} }.

% tables
fields -> field ';'         : [ '$1' ].
fields -> field ';' fields  : [ '$1' | '$3' ].

field -> key_def                    : '$1'.
field -> key_def '(' attributes ')' : '$1'.

key_def -> string ':' string              : { get_value_atom('$1'), get_value_atom('$3') }.
key_def -> string ':' '[' string ']'      : { get_value_atom('$1'), {vector, get_value_atom('$4')}}.
key_def -> string ':' string '=' value    : { get_value_atom('$1'), {get_value_atom('$3'), '$5' }}.

attributes -> attributes ',' attribute_def. %ignore
attributes -> attribute_def.                %ignore
attribute_def -> string ':' value.          %ignore
attribute_def -> string.                    %ignore

value -> int      : get_value('$1').
value -> float    : get_value('$1').
value -> bool     : get_value('$1').
value -> string   : get_value_bin('$1').

% enums + unions
atoms -> atom             : [ '$1' ].
atoms -> atom ',' atoms   : [ '$1' | '$3'].

atom -> string : get_value_atom('$1').

Erlang code.

get_value_atom({_Token, _Line, Value}) -> list_to_atom(Value).
get_value_bin({_Token, _Line, Value})  -> list_to_binary(Value).
get_value({_Token, _Line, Value})      -> Value.

get_name({Token, _Line, _Value})  -> Token;
get_name({Token, _Line})          -> Token.

add_def({Defs, Opts}, Def) -> {maps:merge(Defs, Def), Opts}.
add_opt({Defs, Opts}, Opt) -> {Defs, maps:merge(Opts, Opt)}.