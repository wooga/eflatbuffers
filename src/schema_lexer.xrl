Definitions.

FLOAT           = -?[0-9]+\.[0-9]+([eE][-+]?[0-9]+)?
INT             = -?[0-9]+
STRING          = [a-zA-Z0-9_\.]+
BOOL            = (true|false)
WS              = [\s\t]+
NL              = [\n\r]+

Rules.

table{WS}           : {token, {table, TokenLine}}.
struct{WS}				  : {token, {struct, TokenLine}}.
enum{WS}				    : {token, {enum, TokenLine}}.
union{WS}				    : {token, {union, TokenLine}}.
namespace{WS}		    : {token, {namespace, TokenLine}}.
root_type{WS}			  : {token, {root_type, TokenLine}}.
include{WS}				  : {token, {include, TokenLine}}.
attribute{WS}			  : {token, {attribute, TokenLine}}.
file_identifier{WS}	: {token, {file_identifier, TokenLine}}.
file_extension{WS}  : {token, {file_extension, TokenLine}}.

{FLOAT}         : {Val, _} = string:to_float(TokenChars), {token, {float, TokenLine, Val}}.
{INT}           : {Val, _} = string:to_integer(TokenChars), {token, {int, TokenLine, Val}}.
{BOOL}          : {token, {int, TokenLine, get_bool(TokenChars)}}.
{STRING}        : {token, {string, TokenLine, TokenChars}}.
{WS}            : skip_token.
{NL}            : skip_token.

\{    : {token, {'{',  TokenLine}}.
\}    : {token, {'}',  TokenLine}}.
\(    : {token, {'(',  TokenLine}}.
\)    : {token, {')',  TokenLine}}.
\[    : {token, {'[',  TokenLine}}.
\]    : {token, {']',  TokenLine}}.
\;    : {token, {';',  TokenLine}}.
\,    : {token, {',',  TokenLine}}.
\:    : {token, {':',  TokenLine}}.
\=    : {token, {'=',  TokenLine}}.
\"    : {token, {quote, TokenLine}}.

Erlang code.

get_bool("true") -> true;
get_bool("false") -> false.
