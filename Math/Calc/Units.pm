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

__END__

my %printable = ( default => [ 1, 300 ],
		  millisec => [ 1, 999 ],
		  sec => [ 1, 200 ],
		  minute => [ 2, 100 ],
		  hour => [ 1, 80 ],
		  day => [ 1, undef ],
		  week => [ 1, 4 ],
		);

# Take a value with canonical units, and return an array of nice
# printable forms
#
# Theory: You have a point in some strange dimensional space. It's
# associated with a magnitude. By changing one of your units, you can
# move to another point. There are spheroidish regions in space
# considered to be "acceptable". Try all possibilities and score each,
# returning all of the acceptable ones. Or something like that; I
# haven't written it yet.
#
sub printable {
    my $v = shift;
    my ($val, $units) = @$v;

    my @results;
    for my $u (equivalents($units)) {
	my $canon = canonical([ 1, $u ]);
	my $v = [ $val / $canon->[0], $u ];
	my $score = score($v);
	push @results, [ $score, $v ] if $score > 0;
    }

    return sort { $b->[0] <=> $a->[0] } @results;
}

sub display_printable {
    my ($v, $max) = @_;
    my $printed = 0;
    for (printable($v)) {
	my ($score, $pv) = @$_;
	print render($pv) . " (score=".score($pv).")\n";
	last if $max && ++$printed > $max;
    }
}

sub render_unit {
    my $u = shift;
    if ($u eq 'unit') {
	return "";
    } elsif (! ref $u) {
	return $u;
    } elsif ($u->[0] eq 'dot') {
	my @list = @$u;
	shift(@list);
	my %count;
	$count{$_}++ for (@list);
	my $str;
	for my $unit (sort keys %count) {
	    my $count = $count{$unit};
	    if ($count == 1) {
		$str .= $unit . " ";
	    } elsif ($count == 2) {
		$str .= "square $unit ";
	    } elsif ($count == 3) {
		$str .= "cubic $unit ";
	    } else {
		$str .= "$unit**$count ";
	    }
	}
	chop($str);
	return $str;
    } else {
	return render_unit($u->[1]) . " / " . render_unit($u->[2]);
    }
}

sub render {
    my $v = shift;
    my $u = render_unit($v->[1]);
    my $val = sprintf("%.2f", $v->[0]);
    if (int($val) / $val > 0.99) {
	$val = int($val);
    }
    if ($u eq '') {
	return $val;
    } else {
	return "$val $u";
    }
}

sub equivalents {
    my $units = shift;

    if (! ref $units) {
	if ($units eq 'byte') {
	    return $units, map { $_ . "byte" } keys %metric_base2;
	} elsif ($units eq 'sec') {
	    my @small = map { $_ . "sec" } keys %niceSmallMetric;
	    my @big = keys %time_units;
	    return $units, @small, @big;
	} elsif ($units eq 'meter') {
	    return $units,
	           (map { $_ . "meter" } keys %metric),
	           keys %distance_units;
	} else {
	    return ( $units );
	}
    } elsif ($units->[0] eq 'dot') {
	my @list = @$units;
	shift(@list);

	my %count;
	foreach my $u (@list) {
	    $count{$u}++;
	}

	my @count;
	my @equivs;
	my $i = 0;
	foreach my $u (sort keys %count) {
	    $count[$i] = $count{$u};
	    @{ $equivs[$i++] } = equivalents($u);
	}

	my @result;
	for my $combination (allCombinations(@equivs)) {
	    my $unit = [ 'dot' ];
	    for $i (0 .. @$combination) {
		push @$unit, ( $combination->[$i] ) x $count[$i];
	    }
	    push @result, $unit;
	}
	
	return @result;
    } elsif ($units->[0] eq 'per') {
	my @equivs;
	my $i = 0;
	foreach my $u ($units->[1], $units->[2]) {
	    @{ $equivs[$i++] } = equivalents($u);
	}

	my @result;
	for my $combination (allCombinations([ equivalents($units->[1]) ],
					     [ equivalents($units->[2]) ]))
	{
	    push @result, [ 'per', @$combination ];
	}
	
	return @result;
    }
}

# ( [ a1..aM ], [ b1..bN ] ] ) -> ( [ a1,b1 ], [ a1,b2 ], ..., [ a1, bN ],
#                                   [ a2,b1 ], [ a2,b2 ], ..., [ a2, bN ],
#                                   .
#                                   .
#                                   [ aM,b1 ], [ aM,b2 ], ..., [ aM, bN ])
#
# (cross product of K lists, not just two as shown above)
#
sub allCombinations {
    my @sets = @_;
    if (@sets == 1) {
	return map { [ $_ ] } @{ $sets[0] };
    } else {
	my @combinations = allCombinations(@sets[1..$#sets]);
	my @result;
	for my $first (@{ $sets[0] }) {
	    push @result, map { [ $first, @$_ ] } @combinations;
	}
	return @result;
    }
}

# pref(nonref unit) = ...
# pref(dot(a,b...)) = MIN(pref(a),pref(b),...)
# pref(per(a,b)) = 75% pref(a) + 25% pref(b)
sub get_pref {
    my $unit = shift;

    my $pref;
    if (! ref $unit) {
	return $pref if defined($pref = $time_pref{$unit});
	return $pref if defined($pref = $distance_pref{$unit});
	return $pref if defined($pref = $size_pref{$unit});
	if ($unit =~ $metric_prefix_test) {
	    my ($prefix, $tail) = ($1, $2);
	    $pref = get_pref($tail) || 1;
	    $pref *= $metric_pref{$prefix};
	    return $pref;
	}
	return 0.5;
    } elsif ($unit->[0] eq 'dot') {
	my @list = @$unit;
	shift(@list);
	foreach (@list) {
	    my $termpref = get_pref($_);
	    if (!defined $pref) {
		$pref = $termpref;
	    } elsif ($pref > $termpref) {
		$pref = $termpref;
	    }
	}
	return $pref;
    } elsif ($unit->[0] eq 'per') {
	return get_pref($unit->[1]) * 0.75 + get_pref($unit->[2]);
    } else {
	die;
    }
}

# score(nonref unit) = 1 if it's within range, 0 otherwise.
# score('per', top, bottom) = score(top)
# score('dot', unit1, unit2, ...) = MAX(score(unit1), score(unit2), ...)
#
sub range_score {
    my $v = shift;
    my ($val, $units) = @$v;
    if (! ref $units) {
	my $range = $printable{$units} || $printable{default};
	return 0 if ($val < $range->[0]); # Too low
	return 0 if defined $range->[1] && $val > $range->[1]; # Too high
	return 1;
    } elsif ($units->[0] eq 'per') {
	return range_score([ $val, $units->[1]]);
    } elsif ($units->[0] eq 'dot') {
	my $score = 0;
	my @list = @$units;
	shift(@list);
	for (@list) {
	    my $subscore = range_score([ $val, $_ ]);
	    $score = $subscore if $score < $subscore;
	}
	return $score;
    } else {
	die;
    }
}

sub score {
    my $v = shift;
    my $pref = get_pref($v->[1]);
    my $range_score = range_score($v);
    return $pref * $range_score; # Simple gate for now
}

1;
