%{

#include <stdio.h>

int depth=0;
int doind=0;

int indent(int tabs)
{
    for(int i=0; i<tabs; i++)
    {
	printf("\t");
    }
    return 0;
}

%}


%%

"\$["|"["	{
	    printf("\n");
	    indent(depth);
	    printf("%s\n", yytext);
	    doind = 1;
	    depth++;
	}

"]"	{
	    printf("\n");
	    doind = 1;
	    depth--;
	    indent(depth);
	    printf("]");
	}

"\""[^\"]*"\"" {
	    if (doind)
	    {
		indent(depth);
		doind = 0;
	    }
	    printf("%s", yytext);
	}

[,][ ]*	{
	    printf(",\n");
	    doind = 1;
	}

.	{
	    if (doind)
	    {
		indent(depth);
	    }
	    printf("%s", yytext);
	    doind = 0;
	}

%%


int main(int argc, char** argv)
{
    ++argv, --argc;  /* skip over program name */
    if ( argc > 0 )
	yyin = fopen( argv[0], "r" );
    else
        yyin = stdin;
    yylex();
    return 0;
}

