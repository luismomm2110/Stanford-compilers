/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{

#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int commentLevel = 0;
static int nullChar;
static std::string currentString;
%}

/*
 * Define names for regular expressions here.
 */

NEWLINE		\n
ESCAPE		\\
DARROW          =>
ASSIGN 		<-
LE		<= 
NUMBER		[0-9]+
ALPHANUM	[a-zA-Z0-9_]
SINGLE_TOKENS	[:+\-*/=)(}{~.,;<@]
NULL		\0
TYPE_ID		[A-Z]{ALPHANUM}*
OBJECT_ID	[a-z]{ALPHANUM}*
CLASS		(?i:class)
ELSE		(?i:else)
FI		(?i:fi)
IF		(?i:if)
IN		(?i:in)	
INHERITS	(?i:inherits)
ISVOID		(?i:isvoid)
LET		(?i:let)
LOOP		(?i:loop)
POOL		(?i:pool)
THEN		(?i:then)
WHILE		(?i:while)
CASE		(?i:case)
ESAC		(?i:esac)
NEW		(?i:new)
OF		(?i:of)
NOT		(?i:not)
TRUE            t(?i:rue)
FALSE           f(?i:alse)
WHITESPACE	[ \t\r\f\v]
QUOTE 		\"
BEGIN_COMMENT 	"(*"
END_COMMENT 	"*)"
COMMENT_IN_LINE	--

%x COMMENT COMMENT_IN_LINE STRING

%%


 /*
  *  Nested comments
  */

{END_COMMENT} {
	cool_yylval.error_msg = "Unmatched *)";
	return (ERROR);	
}

{BEGIN_COMMENT}		{ 
	commentLevel++;
	BEGIN(COMMENT); 
}

<COMMENT>{BEGIN_COMMENT} {
	commentLevel++;
} 

<COMMENT>{END_COMMENT} {
	commentLevel--;
	if (commentLevel == 0) {
		BEGIN INITIAL;
	}
} 

<COMMENT>{NEWLINE} {
	curr_lineno++;
}

<COMMENT><<EOF>> { 
	BEGIN INITIAL;
	cool_yylval.error_msg = "EOF in comment";
        return ERROR;
}

<COMMENT>. ;   

 /*
  *  The multiple-character operators.
  */

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{DARROW}		{ return (DARROW); }
{ASSIGN} 		{ return (ASSIGN); }
{LE} 			{ return (LE); } 
{CLASS}			{ return (CLASS); } 
{ELSE}			{ return (ELSE); } 
{IF}			{ return (IF); } 
{FI}			{ return (FI); } 
{IN}			{ return (IN); } 
{INHERITS}		{ return (INHERITS); } 
{ISVOID} 		{ return (ISVOID); }
{LET}   		{ return (LET); }
{LOOP}   		{ return (LOOP); }
{POOL}   		{ return (POOL); }
{THEN}   		{ return (THEN); }
{WHILE}   		{ return (WHILE); }
{CASE}   		{ return (CASE); }
{ESAC}   		{ return (ESAC); }
{NEW}   		{ return (NEW); } 
{OF}    		{ return (OF); }
{NOT}   		{ return (NOT); }

{WHITESPACE}		;	

{COMMENT_IN_LINE} { 
    BEGIN COMMENT_IN_LINE;
}

{TRUE}	{
    cool_yylval.boolean = 1;
    return BOOL_CONST;
}

{FALSE} {
    cool_yylval.boolean = 0;
    return BOOL_CONST;
}

{NUMBER}+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}

{TYPE_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{OBJECT_ID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

{QUOTE} {
    BEGIN STRING;
    currentString = ""; 
}

{SINGLE_TOKENS} {
    return int(yytext[0]);
}

{NEWLINE} {
    curr_lineno++;
}

<COMMENT_IN_LINE><<EOF>> { 
    BEGIN INITIAL;
}

<COMMENT_IN_LINE>{NEWLINE} { 
    curr_lineno++;
    BEGIN INITIAL;
}

<COMMENT_IN_LINE>.	;

<STRING>{ESCAPE}. {
    char ch;
    switch((ch = yytext[1])) {
        case 'b':
	    currentString += '\b';
	    break;
	case 't':
	    currentString += '\t';
	    break;
	case 'n':
	    currentString += '\n';
	    break;
	case 'f':
	    currentString += '\f';
	    break;
	case '\0':
	    nullChar = 1;
	    break;
	default:
	    currentString += ch;
            break;
    }
}

<STRING>{NEWLINE} {
    BEGIN INITIAL;
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<STRING>{ESCAPE}{NEWLINE} {
    currentString += "\n";
    curr_lineno++;
}

<STRING>{QUOTE} {
    BEGIN INITIAL;

    if (currentString.size() >= MAX_STR_CONST) {
       cool_yylval.error_msg = "String constant too long";
       return ERROR;
    } 
    if (nullChar) { 
       cool_yylval.error_msg = "String contains escaped null character";
       return ERROR;
    } 
    cool_yylval.symbol = stringtable.add_string((char *)currentString.c_str());
    return STR_CONST;
} 

<STRING>{NULL} {
   nullChar = 1;
}

<STRING><<EOF>> {
   BEGIN INITIAL;
   cool_yylval.error_msg = "EOF in string constant";
   return ERROR;
}

<STRING>. {
   currentString += yytext;
}

. {
    cool_yylval.error_msg = yytext;
    return ERROR;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


