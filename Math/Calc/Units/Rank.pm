package Units::Calc::Rank;
use Units::Calc::Convert qw(convert canonical find_top);
use Units::Calc::Convert::Multi;
use strict;

sub display_printable {
    my ($v, $max) = @_;
    my $printed = 0;
    for (printable($v)) {
	my ($score, $pv) = @$_;
	print render($pv) . " (score=".score($pv).")\n";
	last if $max && ++$printed > $max;
    }
}

sub variants {
    my $base = shift;
    return Units::Calc::Convert::Multi->variants($base);
}

sub choose_juicy_ones {
    my ($v) = @_;

    # I. Convert to canonical form
    $v = canonical($v);

    # II. Reduce unit down to the atomic component units and their powers
    # eg mb / sec / sec -> <mb,1>, <sec,-2>
    my @top = find_top($v->[1]);
    my @bottom = find_top($v->[1], 'invert');
    my %count;
    $count{$_}++ for (@top);
    $count{$_}-- for (@bottom);
    delete $count{unit};

    # III. Try every combination of units

    # Danger of combinatorial explosion: if we have four distinct
    # types of units, and each has 13 different possibilities (which
    # is likely given metric units), then we'd have to try 13^4
    # combinations. Which is less than 30,000, so I won't worry about
    # it for now.

    my @variants; # [ i => [ variants of unit #i ] ]
    my @unitList = keys %count; # Will reuse later
    push @variants, [ variants($_) ] foreach (@unitList);

    # Loop over combinations (watch out, this'll get messy)
    my @comb = map { $_->[0] } @variants; # ( i => unit )
    my @current = (0) x @variants; # ( i => index of @comb's unit in the set of variants )

    my $val = $v->[0];

    my @scored;
    push @scored, [ [@comb], score_comb($val, \@comb) ];

    # Heh. A very fun piece of code follows.

    $DB::single = 1;

  COMBINATION:
    while (1) {
	# Advance to next
	for my $i (0..$#variants) {
	    my $n = @{$variants[$i]};

	    if (++$current[$i] == $n) {
		$current[$i] = 0;
	    }

	    my $old = $comb[$i];
	    my $new = $comb[$i] = $variants[$i]->[$current[$i]];

	    # Change unit $old to $new and update $val accordingly
	    # Input: 4 / ms
	    # 1 ms -> 1000 us
	    # 4 * 1000 ** -1 = .04 / us
	    my $c = convert([ 1, $old ], $new);
	    $val *= $c->[0] ** $count{$unitList[$i]};

	    my $score = score_comb($val, \@comb);
	    if ($current[$i] == 0) {
		push @scored, [ [@comb], $score ];
	    } else {
		# Optimization that's minor in general but pretty significant
		# when small numbers of distinct base units are involved --
		# which is always, at the moment.
		if ($score > $scored[-1]->[1]) {
		    $scored[-1] = [ [@comb], $score ];
		}
	    }

	    next COMBINATION unless $current[$i] == 0;
	}

	last;
    }

    return sort { $b->[1] <=> $a->[1] } @scored;
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
	$count{$_}++ foreach (@list);
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

#  sub equivalents {
#      my $units = shift;

#      if (! ref $units) {
#  	if ($units eq 'byte') {
#  	    return $units, map { $_ . "byte" } keys %metric_base2;
#  	} elsif ($units eq 'sec') {
#  	    my @small = map { $_ . "sec" } keys %niceSmallMetric;
#  	    my @big = keys %time_units;
#  	    return $units, @small, @big;
#  	} elsif ($units eq 'meter') {
#  	    return $units,
#  	           (map { $_ . "meter" } keys %metric),
#  	           keys %distance_units;
#  	} else {
#  	    return ( $units );
#  	}
#      } elsif ($units->[0] eq 'dot') {
#  	my @list = @$units;
#  	shift(@list);

#  	my %count;
#  	foreach my $u (@list) {
#  	    $count{$u}++;
#  	}

#  	my @count;
#  	my @equivs;
#  	my $i = 0;
#  	foreach my $u (sort keys %count) {
#  	    $count[$i] = $count{$u};
#  	    @{ $equivs[$i++] } = equivalents($u);
#  	}

#  	my @result;
#  	for my $combination (allCombinations(@equivs)) {
#  	    my $unit = [ 'dot' ];
#  	    for $i (0 .. @$combination) {
#  		push @$unit, ( $combination->[$i] ) x $count[$i];
#  	    }
#  	    push @result, $unit;
#  	}
	
#  	return @result;
#      } elsif ($units->[0] eq 'per') {
#  	my @equivs;
#  	my $i = 0;
#  	foreach my $u ($units->[1], $units->[2]) {
#  	    @{ $equivs[$i++] } = equivalents($u);
#  	}

#  	my @result;
#  	for my $combination (allCombinations([ equivalents($units->[1]) ],
#  					     [ equivalents($units->[2]) ]))
#  	{
#  	    push @result, [ 'per', @$combination ];
#  	}
	
#  	return @result;
#      }
#  }

#  # ( [ a1..aM ], [ b1..bN ] ] ) -> ( [ a1,b1 ], [ a1,b2 ], ..., [ a1, bN ],
#  #                                   [ a2,b1 ], [ a2,b2 ], ..., [ a2, bN ],
#  #                                   .
#  #                                   .
#  #                                   [ aM,b1 ], [ aM,b2 ], ..., [ aM, bN ])
#  #
#  # (cross product of K lists, not just two as shown above)
#  #
#  sub allCombinations {
#      my @sets = @_;
#      if (@sets == 1) {
#  	return map { [ $_ ] } @{ $sets[0] };
#      } else {
#  	my @combinations = allCombinations(@sets[1..$#sets]);
#  	my @result;
#  	for my $first (@{ $sets[0] }) {
#  	    push @result, map { [ $first, @$_ ] } @combinations;
#  	}
#  	return @result;
#      }
#  }

# pref(nonref unit) = ...
# pref(dot(a,b...)) = MIN(pref(a),pref(b),...)
# pref(per(a,b)) = 75% pref(a) + 25% pref(b)
sub get_pref {
    my $unit = shift;

    my $pref;
    if (! ref $unit) {
	return Units::Calc::Convert::Multi->pref_score($unit);
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
	return Units::Calc::Convert::Multi->range_score($v);
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

sub score_comb {
    my ($val, $units) = @_;
    my $score = range_score([ $val, [ 'dot', @$units ] ]);
    return 0 if ! $score;
    for my $unit (@$units) {
	$score *= get_pref($unit);
    }
    return $score;
}

1;
