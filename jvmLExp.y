%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Flex Declarations
/* Just for being able to show the line number were the error occurs.*/
extern int line;
extern FILE *yyout;
int yylex();
/* Error Related Functions and Macros*/
int yyerror(const char *);
int no_errors;
/* Error Messages Macros*/
#define ERR_VAR_DECL(VAR,LINE) fprintf(stderr,"Variable :: %s on line %d. ",VAR,LINE); yyerror("Var already defined")
#define ERR_VAR_MISSING(VAR,LINE) fprintf(stderr,"Variable %s NOT declared, n line %d.",VAR,LINE); yyerror("Variable Declation fault")

// Type Definitions and JVM command related Functions
#include "jvmLangTypesFunctions.h"
// Symbol Table definitions and Functions
#include "symbolTable.h"
/* Defining the Symbol table. A simple linked list. */
ST_TABLE_TYPE symbolTable;
#include "codeFacilities.h"

%}
/* Output informative error messages (bison Option) */
%define parse.error verbose

%union{
   char *lexical;
   struct {
	    ParType type;
	    char * place;} se;
  RelationType relopIndex;
  struct {
       NUMBER_LIST_TYPE trueLbl;
       NUMBER_LIST_TYPE falseLbl;
    } condLabels;

}

/* Token declarations and their respective types */

%token <lexical> T_num
%token <lexical> T_real
%token '('
%token ')'
%token <lexical> T_id
%token <lexical> T_FuncUnary
%token T_start "start"
%token T_end "end"
%token T_print "print"



%%
program: "start" T_id {create_preample($2); symbolTable=NULL; }
			stmts "end"
			{insertINSTRUCTION("return");
       insertINSTRUCTION(".end method\n");}
	;
/* A simple (very) definition of a list of statements.*/
stmts:  '(' stmt ')' {/* nothing */}
     |  '(' stmt ')' stmts 	{/* nothing */}
     |  '(' error ')' stmts
	;

stmt:  asmt	{/* nothing */}
	| printcmd {/* nothing */}
	;

printcmd: "print" expr  {
			   	insertINSTRUCTION("getstatic java/lang/System/out Ljava/io/PrintStream;");
			    insertINSTRUCTION("swap");
          insertINVOKEVITRUAL("java/io/PrintStream/println",$2.type,type_void);
				}
		   	;

asmt: T_id expr
    {
			/* Add code here*/
		}
	;



%%



/* The usual yyerror */
int yyerror (const char * msg)
{
  fprintf(stderr, "PARSE ERROR: %s.on line %d.\n ", msg,line);
  no_errors++;
}

/* Other error Functions*/
/* The lexer... */
#include "jvmLExp.lex.c"

/* Main */
int main(int argc, char **argv ){

   ++argv, --argc;  /* skip over program name */
   if ( argc > 0 && (yyin = fopen( argv[0], "r")) == NULL)
    {
      fprintf(stderr,"File %s NOT FOUND in current directory.\n Using stdin.\n",argv[0]);
      yyin = stdin;
    }
   if ( argc > 1) {yyout = fopen(argv[1], "w");}
   else {
      fprintf(stderr,"No second argument defined. Output to screen.\n\n");
      yyout = stdout;
    }

    // Calling the parser
   int result = yyparse();

   fprintf(stderr,"Errors found %d.\n",no_errors);
   if (no_errors == 0)
      {print_int_code(yyout);}
   fclose(yyout);
   /// Need to remove even empty file.
   if (no_errors != 0 && yyout != stdout) {
     remove(argv[1]);
      fprintf(stderr,"No Code Generated.\n");}
   print_symbol_table(symbolTable); /* uncomment for debugging. */

  return result;
}