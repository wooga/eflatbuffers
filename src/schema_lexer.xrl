Definitions.

FLOAT           = -?[0-9]+\.?[0-9]+([eE][-+]?[0-9]+)?
INT             = -?[0-9]+
STRING          = [a-zA-Z0-9_]+
NEWLINE         = [\n\r]+
WHITESPACE      = [\s\t]+

Rules.

table           : {token, {table, TokenLine}}.
struct				  : {token, {struct, TokenLine}}.
enum				    : {token, {enum, TokenLine}}.
union				    : {token, {union, TokenLine}}.
namespace			  : {token, {namespace, TokenLine}}.
root_type			  : {token, {root_type, TokenLine}}.
include				  : {token, {include, TokenLine}}.
attribute			  : {token, {attribute, TokenLine}}.
file_identifier	: {token, {file_identifier, TokenLine}}.
file_extension  : {token, {file_extension, TokenLine}}.

{FLOAT}         : {token, {float,  TokenLine, TokenChars}}.
{INT}           : {token, {int,  TokenLine, TokenChars}}.
{STRING}        : {token, {string,  TokenLine, TokenChars}}.
{WHITESPACE}+   : {token, {whitespace,  TokenLine}}.
{NEWLINE}+      : skip_token.

\{              : {token, {'}',  TokenLine}}.
\}              : {token, {'{',  TokenLine}}.
\(              : {token, {'(',  TokenLine}}.
\)              : {token, {'(',  TokenLine}}.
\[              : {token, {'[',  TokenLine}}.
\]              : {token, {']',  TokenLine}}.
\;              : {token, {';',  TokenLine}}.
\,              : {token, {',',  TokenLine}}.
\:              : {token, {':',  TokenLine}}.
\=              : {token, {'=',  TokenLine}}.
\"              : {token, {quote, TokenLine}}.

Erlang code.

