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

void insertFINC(int position, double value);
/* Error Messages Macros*/
#define ERR_VAR_DECL(VAR,LINE) fprintf(stderr,"Variable :: %s on line %d. ",VAR,LINE); yyerror("Var already defined")
#define ERR_VAR_MISSING(VAR,LINE) fprintf(stderr,"Variable %s NOT declared, n line %d.",VAR,LINE); yyerror("Variable Declaration fault")

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
       NUMBER_LIST_TYPE nextLbl;
    } condLabels;

}

/* Token declarations and their respective types */

%token <lexical> T_num
%token <lexical> T_real
%token '('
%token ')'
%token ':'
%token <lexical> T_id
%token <lexical> T_FuncUnary
%token T_start "start"
%token T_end "end"
%token T_print "print"
%token T_int "int"
%token T_float "float"
%token T_abs "abs"

%type<se> expr
%type<condLabels> bool
%type<relopIndex> relop

%left '+' '-' '*' '/'

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
    };

asmt: T_id expr {
  if (!lookup(symbolTable,$1))
    addvar(&symbolTable,$1,$2.type);
  else
    typeDefinition(lookup_type(symbolTable,$1), $2.type);
  insertSTORE($2.type,lookup_position(symbolTable,$1));
};

expr: '(' expr ')' {$$.type = $2.type;}
  | T_num {$$.type = type_integer; pushInteger(atoi($1));}
  | T_real {$$.type = type_real; insertLDC($1);}
  | T_id {
      if (!($$.type = lookup_type(symbolTable,$1))) {
        ERR_VAR_MISSING($1,line);
      }
      insertLOAD($$.type,lookup_position(symbolTable,$1));
    }
  | expr expr '+' {
      $$.type = typeDefinition($1.type, $2.type);
      insertOPERATION($$.type,"add");
    }
  | expr expr '-' {
      $$.type = typeDefinition($1.type, $2.type);
      insertOPERATION($$.type,"sub");
    }
  | expr expr '*' {
      $$.type = typeDefinition($1.type, $2.type);
      insertOPERATION($$.type,"mul");
    }
  | expr expr '/' {
      $$.type = typeDefinition($1.type, $2.type);
      insertOPERATION($$.type,"div");
    }
  | T_id '+' '+' {
      if (!($$.type = lookup_type(symbolTable,$1))) {
        ERR_VAR_MISSING($1,line);
      }
      int position = lookup_position(symbolTable,$1);
      insertLOAD($$.type, position);
      if ($$.type == type_integer)
        insertIINC(position, 1);
      else if ($$.type == type_real)
        insertFINC(position, 1.0);
    }
  | '+' '+' T_id {
      if (!($$.type = lookup_type(symbolTable,$3))) {
        ERR_VAR_MISSING($3,line);
      }
      int position = lookup_position(symbolTable,$3);
      if ($$.type == type_integer)
        insertIINC(position, 1);
      else if ($$.type == type_real) {
        insertFINC(position, 1.0);
      }
      insertLOAD($$.type, position);
    }
  | "int" expr {
      $$.type = type_integer;
      if ($2.type == type_integer)
        printf("Warning: value is already int, in line %d.\n",line);
      else
        insertOPERATION($2.type,"2i");
    }
  | "float" expr {
      $$.type = type_real;
      if ($2.type == type_real)
        printf("Warning: value is already real, in line %d.\n",line);
      else
        insertOPERATION($2.type,"2f");
    }
  | expr "abs" {
      $$.type = $1.type;
      insertINVOKESTATIC("java/lang/Math/abs",$1.type,$1.type);
    }
  | bool ':' {
      backpatch($1.trueLbl,currentLabel());
      insertLabel(Label());
    }
    expr ':' {
      backpatch($1.falseLbl,currentLabel());
      $1.nextLbl = makelist(nextInstruction());
      insertGOTO(UNKNOWN);
      insertLabel(Label());
    }
    expr {
      $$.type = typeDefinition($4.type,$7.type);
      backpatch($1.nextLbl,currentLabel());
      insertLabel(Label());
    };

bool: expr relop expr {
  typeDefinition($1.type, $3.type);
  if ($1.type == type_integer) {
    $$.trueLbl = makelist(nextInstruction());
    insertICMPOP($2,UNKNOWN);
  }
  if ($1.type == type_real) {
    insertINSTRUCTION("fcmpl");
    $$.trueLbl = makelist(nextInstruction());
    insertIFOP($2,UNKNOWN);
  }
  $$.falseLbl = makelist(nextInstruction());
  insertGOTO(UNKNOWN);};

relop: '>' 	{$$=OP_GT;}
  | '<' {$$=OP_LT;}
  | '=' {$$=OP_EQ;};

%%

void insertFINC(int position, double value) {
  char str_value[MAX_INST_LEN];
  sprintf(str_value, "%f", value);

  insertLOAD(type_real, position);
  insertLDC(str_value);
  insertOPERATION(type_real, "add");
  insertSTORE(type_real,position);
}

/* The usual yyerror */
int yyerror (const char * msg)
{
  fprintf(stderr, "PARSE ERROR: %s on line %d.\n", msg,line);
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

  /* Return non-zero if there were any errors, so that compile_and_run won't run previous code*/
  return result || no_errors;
}
