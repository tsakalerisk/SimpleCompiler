/*
Grammar with semantics and type checking.
Lexical Analyser
*/

%{
#include <stdlib.h>
#include <string.h>
int line = 1;
%}

D [0-9]
LETTER [a-zA-Z]
VARIABLE {LETTER}({LETTER}|{D}|_)*
FLOAT {D}+\.{D}*
COMP_OP >|=|<
newline \n|\x0A|\x0D\x0A
%%
"start" {return T_start;}
"end" {return T_end;}
"print" {return T_print;}
"int" {return T_int;}
"float" {return T_float;}
"abs" {return T_abs;}

"(" {return '(';}
")" {return ')';}
":" {return ':';}

("-")?{D}+ {yylval.lexical = strdup(yytext);  return T_num;}
("-")?{FLOAT} {yylval.lexical = strdup(yytext); return T_real;}
{VARIABLE} {yylval.lexical = strdup(yytext); return T_id;}
{COMP_OP} {yylval.lexical = strdup(yytext); return T_comp_op;}

"+" {return '+';}
"*" {return '*';}

{newline}  { line++;}
[ \t] { /* nothing */ }
. {
	printf("Lexical Analysis: Unexpected String! :: %s. in line %d. \n",yytext,yylineno); }

%%
