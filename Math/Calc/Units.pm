use lib '/home/sfink/units';

package Units::Calc;
use Units::Calc::Grammar;
use Units::Calc::Convert;
use base 'Exporter';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(compute);

use Data::Dumper;
use strict;

# Insert stuff into the grammar package so it can do immediate
# calculations.
package Units::Calc::Grammar;

sub canonical {
    return Units::Calc::Convert::reduce(shift());
}

sub equivalent {
    my ($u, $v) = @_;
    return Units::Calc::Convert::Base->same($u, $v);
}

# All these assume the values are in canonical units.
sub plus {
    my ($u, $v) = @_;
    die "Added incompatible units ".render_unit($u->[1])." and ".render_unit($v->[1])
      if ! equivalent($u->[1], $v->[1]);
    return [ $u->[0] + $v->[0], $u->[1] ];
}

sub minus {
    my ($u, $v) = @_;
    die "Subtract incompatible units ".render_unit($u->[1])." and ".render_unit($v->[1])
      if ! equivalent($u->[1], $v->[1]);
    return [ $u->[0] - $v->[0], $u->[1] ];
}

sub mult {
    my ($u, $v) = @_;
    return canonical([ $u->[0] * $v->[0], dot($u->[1], $v->[1]) ]);
}

sub divide {
    my ($u, $v) = @_;
    return canonical([ $u->[0] / $v->[0], [ 'per', $u->[1], $v->[1] ]]);
}

sub power {
    my ($u, $v) = @_;
    die "Can only raise to unit-less powers" if $v->[1] ne 'unit';
    return canonical([ $u->[0] ** $v->[0], [ 'dot', $u->[1], $v->[0] ] ]);
}

sub dot {
    return 'unit' if @_ == 0;
    return $_[0] if @_ == 1;
    return [ 'dot', @_ ];
}

package Units::Calc;
use Data::Dumper;

# Poor-man's tokenizer
sub tokenize {
    my $data = shift;
    my @tokens = $data =~ m{\s*([\d.]+|\w+|\*\*|[-+*/()])}g;
    my @types = map {      /\d/ ? 'NUMBER'
                      :(   /\w/ ? 'WORD'
                      :(          $_)) } @tokens;
    return \@tokens, \@types;
}

sub compute {
    my ($vals, $types) = tokenize(shift());
    my $lexer = sub {
#        print "TOK($vals->[0]) TYPE($types->[0])\n" if @$vals;
        return shift(@$types), shift(@$vals) if (@$types);
        return ('', undef);
    };

    my $parser = new Units::Calc::Grammar;

    return
        $parser->YYParse(yylex => $lexer,
                         yyerror => sub {
                             my $parser = shift;
                             die "Error: expected ".join(" ", $parser->YYExpect)." got `".$parser->YYCurtok."', rest=".join(" ", @$types)."\nfrom ".join(" ", @$vals)."\n";
                         },
                         yydebug => 0); # 0x1f);
};

if (!(caller)) {
    print Dumper(compute(join('',@ARGV)));
}

1;
