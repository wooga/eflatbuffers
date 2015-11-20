Nonterminals root definition option fields field.
Terminals  table struct enum union namespace root_type include attribute file_identifier file_extension float int string newline '}' '{' '(' '(' '[' ']' ';' ',' ':' '=' quote.
Rootsymbol root.

root -> definition : {'$1', #{}}.
root -> option     : {#{}, '$1'}.
root -> root definition : add_def('$1', '$2').
root -> root option     : add_opt('$1', '$2').

% options (non-quoted)
option -> namespace string ';' : #{get_name('$1') => get_value('$2')}.
option -> root_type string ';' : #{get_name('$1') => get_value('$2')}.

% options (quoted)
option -> include quote string quote ';'         : #{get_name('$1') => get_value('$3')}.
option -> attribute quote string quote ';'       : #{get_name('$1') => get_value('$3')}.
option -> file_identifier quote string quote ';' : #{get_name('$1') => get_value('$3')}.
option -> file_extension quote string quote ';'  : #{get_name('$1') => get_value('$3')}.

% definitions
definition -> table string '{' fields '}'  : #{get_value('$2') => {table, '$4'} }.

fields -> field ';' : [ '$1' ].
fields -> field ';' fields : [ '$1' | '$3' ].

field -> string ':' string          : { get_value('$1'), get_value('$3') }.
field -> string ':' '[' string ']'  : { get_value('$1'), {vector, get_value('$4')}}.

Erlang code.

get_value({_Token, _Line, Value}) -> list_to_atom(Value).

get_name({Token, _Line, _Value})  -> Token;
get_name({Token, _Line})          -> Token.

add_def({Defs, Opts}, Def) -> {maps:merge(Defs, Def), Opts}.
add_opt({Defs, Opts}, Opt) -> {Defs, maps:merge(Opts, Opt)}.


