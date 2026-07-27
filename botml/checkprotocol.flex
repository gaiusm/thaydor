%{
/* Copyright (C) 2025-2026 Free Software Foundation, Inc.
   This file is part of GNU Modula-2.

GNU Modula-2 is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2, or (at your option) any later
version.

GNU Modula-2 is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with gm2; see the file COPYING.  If not, write to the Free Software
Foundation, 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <ctype.h>

  /*
   *  adv.flex - provides a lexical analyser for thaydor checkpointing.
   */

  struct lineInfo {
    char            *linebuf;          /* line contents */
    int              linelen;          /* length */
    int              tokenpos;         /* start position of token within line */
    int              toklen;           /* a copy of yylen (length of token) */
    int              nextpos;          /* position after token */
    int              actualline;       /* line number of this line */
  };

  static int                  lineno      =1;   /* a running count of the file line number */
  static char                *filename    =NULL;
  static struct lineInfo     *currentLine =NULL;
  static bool seenEOF = false;

        void advflex_error      (const char *);
static  void finishedLine       (void);
static  void resetpos           (void);
static  void consumeLine        (void);
static  void updatepos          (void);
static  void skippos            (void);
static  void poperrorskip       (const char *);
	bool advflex_OpenSource (char *s);
	int  advflex_GetLineNo  (void);
	void advflex_CloseSource(void);
	char *advflex_GetToken  (void);
        void _M2_advflex_init   (int, char *, char *);
        void _M2_advflex_finish (int, char *, char *);
        void _M2_advflex_ctor   (void);
extern  void  yylex             (void);
static char *word (char *line, unsigned int count);
static void protocolVersion (char *version);

#define YY_DECL void yylex (void)
%}

%%

^protocol.*version.*\n    { consumeLine (); updatepos (); protocolVersion (word (currentLine->linebuf, 2)); return; }
^\<newroom\>              { consumeLine (); printf ("<newroom>: %s\n", currentLine->linebuf); return; }
^\<\/newroom\>            { consumeLine (); printf ("</newroom>: %s\n", currentLine->linebuf); return; }
^\<kill\>                 { consumeLine (); printf ("<kill>: %s\n", currentLine->linebuf); return; }
^\<\/kill\>               { consumeLine (); printf ("</kill>: %s\n", currentLine->linebuf); return; }
^\<died\>                 { consumeLine (); printf ("<died>: %s\n", currentLine->linebuf); return; }
^\<\/died\>               { consumeLine (); printf ("</died>: %s\n", currentLine->linebuf); return; }
^clear                    { consumeLine (); printf ("clear: %s\n", currentLine->linebuf); return; }
^playerid                 { consumeLine (); printf ("playerid: %s\n", currentLine->linebuf); return; }
^dCMD                     { exit (0); consumeLine (); printf ("dCMD: %s\n", currentLine->linebuf); return; }
^dw                       { consumeLine (); printf ("dw: %s\n", currentLine->linebuf); return; }
^dA                       { consumeLine (); printf ("dA: %s\n", currentLine->linebuf); return; }
^dF                       { consumeLine (); printf ("dF: %s\n", currentLine->linebuf); return; }
^dN                       { consumeLine (); printf ("dN: %s\n", currentLine->linebuf); return; }
^dM                       { consumeLine (); printf ("dM: %s\n", currentLine->linebuf); return; }
^dT                       { consumeLine (); printf ("dT: %s\n", currentLine->linebuf); return; }
^eL                       { consumeLine (); printf ("eL: %s\n", currentLine->linebuf); return; }
^fl                       { consumeLine (); printf ("fl: %s\n", currentLine->linebuf); return; }
^sman                     { consumeLine (); printf ("sman: %s\n", currentLine->linebuf); return; }
^sync                     { consumeLine (); printf ("sync: %s\n", currentLine->linebuf); return; }
<<EOF>>                   { seenEOF = true; return; }

%%


static char *
word (char *line, unsigned int count)
{
  int start = 0;
  int end = 0;
  int len = strlen (line);
  while (count > 0) {
    while ((line[start] != (char)0) && (line[start] != ' '))
      start++;
    while (line[start] == ' ')
      start++;
    count--;
  }
  if (start < len)
    {
       end = start;
       while ((line[end] != (char)0) && (line[end] != ' '))
         end++;
       char *copy = (char *)malloc (end-start+1);
       strncpy (copy, &line[start], end-start);
       copy[end-start] = (char)0;
       return copy;
     }
  return NULL;
}

static int
integer (char *line, unsigned int count)
{
  int start = 0;
  int end = 0;
  int len = strlen (line);
  while (count > 0) {
    while ((line[start] != (char)0) && (line[start] != ' '))
      start++;
    while (line[start] == ' ')
      start++;
    count--;
  }
  if (start < len)
    {
       end = start;
       while ((line[end] != (char)0) && (line[end] != ' '))
         end++;
       int result = 0;
       while ((start < end) && (isdigit (line[start])))
         {
            result = ((int)line[start]) - ((int)'0');
	    start++;
         }
       return result;
     }
  advflex_error ("failed to read an integer");
  exit (1);
}

static void
protocolVersion (char *version)
{
  printf ("version number %s seen\n", version);
}

/*
 *  consumeLine - reads a line into a buffer, it then pushes back the whole
 *                line except the initial \n.
 */

static void consumeLine (void)
{
  if (currentLine->linelen<yyleng) {
    currentLine->linebuf = (char *)realloc (currentLine->linebuf, yyleng);
    currentLine->linelen = yyleng;
  }
  strcpy(currentLine->linebuf, yytext);  /* Copy all.  */
  lineno++;
  currentLine->actualline = lineno;
  currentLine->tokenpos=0;
  currentLine->nextpos=0;
  yyless (1);                  /* push back all but the \n */
}

/*
 *  updatepos - updates the current token position.
 *              Should be used when a rule matches a token.
 */

static void updatepos (void)
{
  currentLine->nextpos = currentLine->tokenpos+yyleng;
  currentLine->toklen  = yyleng;
}

/*
 *  skippos - skips over this token. This function should be called
 *            if we are not returning and thus not calling getToken.
 */

static void skippos (void)
{
  currentLine->tokenpos = currentLine->nextpos;
}

/*
 *  initLine - initializes a currentLine
 */

static void initLine (void)
{
  currentLine = (struct lineInfo *)malloc (sizeof(struct lineInfo));

  if (currentLine == NULL)
    perror("malloc");
  currentLine->linebuf    = NULL;
  currentLine->linelen    = 0;
  currentLine->tokenpos   = 0;
  currentLine->toklen     = 0;
  currentLine->nextpos    = 0;
  currentLine->actualline = lineno;
}

/*
 *  resetpos - resets the position of the next token to the start of the line.
 */

static void resetpos (void)
{
  if (currentLine != NULL)
    currentLine->nextpos = 0;
}

/*
 *  advflex_GetToken - returns a new token.
 */

char *advflex_GetToken (void)
{
  if (currentLine == NULL)
    initLine();
  currentLine->tokenpos = currentLine->nextpos;
  yylex();
}

void advflex_error (const char *s)
{
  if (currentLine != NULL) {
    printf("%s:%d:%s\n", filename, currentLine->actualline, s);
    printf("%s\n", currentLine->linebuf);
# if 0
    printf("%*s%*s\n", currentLine->nextpos, " ", currentLine->toklen, "^");
# endif
  }
}

/*
 *  OpenSource - returns true if file, s, can be opened and
 *               all tokens are taken from this file.
 */

bool advflex_OpenSource (char *s)
{
  FILE *f = fopen (s, "r");

  if (f == NULL)
    return false;
  else {
    yy_delete_buffer (YY_CURRENT_BUFFER);
    yy_switch_to_buffer (yy_create_buffer (f, YY_BUF_SIZE));
    filename = strdup (s);
    lineno = 1;
    if (currentLine != NULL)
      currentLine->actualline = lineno;
    return true;
  }
}

/*
 *  CloseSource - provided for semantic sugar
 */

void advflex_CloseSource (void)
{
}

/*
 *  advflex_GetLineNo - returns the current line number.
 */

int advflex_GetLineNo (void)
{
  if (currentLine != NULL)
    return currentLine->actualline;
  else
    return 0;
}

/*
 *  yywrap is called when end of file is seen. We push an eof token
 *         and tell the lexical analysis to stop.
 */

int yywrap (void)
{
  updatepos(); return 1;
}

void _M2_advflex_init (int, char *, char *)
{
}

void _M2_advflex_finish (int, char *, char *)
{
}

void _M2_advflex_ctor (void)
{
}
#define TEST_UNIT

#if defined(TEST_UNIT)
void
main () {
  char *s;

  if (advflex_OpenSource("../build/checkpoint/000015.cpt")) {
    do {
      s = (char *)advflex_GetToken ();
    } while (! seenEOF);
  }
}
#endif
