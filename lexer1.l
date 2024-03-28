%{
#include "FunctionStruct.hpp"
#include <stdio.h>
#include <stdlib.h> // For atof
#include "parser1.hpp"


%}
%option noyywrap

%%

'[^\']' {
    yylval.string = strdup(yytext);
    return CHAR_LITERAL;
}

"+" { return '+'; }
"-" { return '-'; }
"*" { return '*'; }
"/" { return '/'; }
"(" { return '('; }
")" { return ')'; }
"[" { return '['; }
"]" { return ']'; }
"," { return ',';}
"function" { return FUNCTION;}
"int"|"float"|"char"|"string"|"bool" {
    yylval.string = strdup(yytext);
    return TYPE;
}

"true"|"false" {
    yylval.string = strdup(yytext);
    return BOOL_LITERAL;
}

[a-zA-Z][a-zA-Z0-9]* {
    yylval.string = strdup(yytext);
    return ID;
}

":=" { return ASSIGN; }

[0-9]+(\.[0-9]+) {
    yylval.value = atof(yytext); 
    return NR_F; 
}
[0-9]+ {
    yylval.value = atof(yytext); 
    return NR_INT; 
}
\"[^\"]*\" {
    yylval.string = strdup(yytext);
    return STRING_LITERAL;
}

";" { return ';'; }

	"<" { return '<'; }
	">" { return '>'; }
	"==" { return EQ; }
	"!=" { return NEQ; }
	"<=" { return LEQ; }
	">=" { return GEQ; }
	"&&" { return AND; }
	"||" { return OR; }
	"!" { return NEG; }

[ \t] ;

\n { yylineno++; }

%%
