# To process: yapp -s -m Units::Calc::Grammar Grammar.y

# Lowest
%nonassoc BARE_UNIT
%nonassoc NUMBER
%left '+' '-'
%left '*' '/'
%left WORD
%left '**'
# Highest

%%

expr : expr '+' expr   { return plus($_[1], $_[3]); }
     | expr '-' expr   { return minus($_[1], $_[3]); }
     | expr '*' expr   { return mult($_[1], $_[3]); }
     | expr '/' expr   { return divide($_[1], $_[3]); }
     | expr '**' expr  { return power($_[1], $_[3]); }
     | '(' expr ')'    { return $_[2]; }
     | value           { return canonical($_[1]); }
     | expr unit       { return mult($_[1], [ 1, $_[2] ]); }
;

value : NUMBER unit
                       { return [ $_[1], $_[2] ] }
      | unit %prec BARE_UNIT
                       { return [ 1, $_[1] ] }
      | NUMBER         { return [ $_[1], 'unit' ] }
;

unit : WORD
     | WORD WORD       { return [ 'dot', $_[1], $_[2] ]; }
;

%%
