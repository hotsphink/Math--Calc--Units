package Units::Calc::Rank;
use base 'Exporter';
use vars qw(@EXPORT_OK);
BEGIN { @EXPORT_OK = qw(choose_juicy_ones render); }

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

sub major_variants {
    my $base = shift;
    return Units::Calc::Convert::Multi->major_variants($base);
}

sub major_pref {
    my $unit = shift;
    return Units::Calc::Convert::Multi->major_pref($unit);
}

sub to_powerform {
    my $unit = shift;
    my @top = find_top($unit);
    my @bottom = find_top($unit, 'invert');
    my %count;
    $count{$_}++ for (@top);
    $count{$_}-- for (@bottom);
    delete $count{unit};

    return \%count;
}

# Powerform: { unit => count }
sub from_powerform {
    my $power = shift;
    my @top;
    my @bottom;
    while (my ($type, $power) = each %$power) {
	if ($power > 0) {
	    push @top, ($type) x $power;
	} elsif ($power < 0) {
	    push @bottom, ($type) x -$power;
	}
    }

    return Units::Calc::Convert::_canonical_reciprocal(\@top, \@bottom);
}

# choose_juicy_ones : value -> ( value )
#
sub choose_juicy_ones {
    my ($v) = @_;
    my @variants = rank_variants($v); # ( < {old=>new}, score > )
    my %variants; # To remove duplicates: { id => [ {old=>new}, score ] }
    for my $variant (@variants) {
	my $id = join(";;", values %{ $variant->[0] });
	$variants{$id} = $variant;
    }

    my $power = to_powerform($v->[1]);

    my @juicy;

    for my $variant (values %variants) {
	my ($map, $score) = @$variant;
	my %copy;
	while (my ($unit, $count) = each %$power) {
	    $copy{$map->{$unit}} = $count;
	}
	push @juicy, [ $score, convert($v, from_powerform(\%copy)) ];
    }

    return map { $_->[1] } sort { $b->[0] <=> $a->[0] } @juicy;
}

# rank_variants : <amount,unit> -> ( < map, score > )
# where map : [original unit => new unit]
#
sub rank_variants {
    my ($v, $keepall) = @_;

    # I. Convert to canonical form
    $v = canonical($v);

    # II. Reduce unit down to the atomic component units and their powers
    # eg mb / sec / sec -> <mb,1>, <sec,-2>
    my $count = to_powerform($v->[1]);

    my @top = grep { $count->{$_} > 0 } keys %$count;

    $DB::single = 1;
    return rank_power_variants($v->[0], \@top, $count, $keepall);
}

# rank_power_variants : value x [unit] x {unit=>power} x keepall_flag ->
#  ( <map,score> )
#
# $top is the set of units that should be range checked.
#
sub rank_power_variants {
    my ($val, $top, $power, $keepall) = @_;

    if (keys %$power > 1) {
	# Choose the major unit class (this will return the best
	# result for each of the major variants)
	my @majors = map { [ major_pref($_), $_ ] } keys %$power;
	my $major = (sort { $a->[0] <=> $b->[0] } @majors)[-1]->[1];

	my %powerless = %$power;
	delete $powerless{$major};

	my @ranked;

	# Try every combination of each major variant and the other units
	foreach my $variant (major_variants($major)) {
	    my $c = convert([ 1, $major ], $variant);
	    my $cval = $val * $c->[0] ** $power->{$major};

	    print "\n --- for $variant ---\n";
	    my @r = rank_power_variants($cval, $top, \%powerless, 0);
	    if (@r == 0) {
		@r = rank_power_variants($cval, $top, \%powerless, 1);
	    }

	    my $best = $r[0];
	    $best->[0]->{$major} = $variant;
	    push @ranked, $best;
	}

	# Update scores to reflect preferences

	return @ranked;
    }

    # Have a single unit left. Go through all possible variants of that unit.
    my $unit = (keys %$power)[0];
    $power = $power->{$unit}; # Now it's just the power of this unit

    my $old = $unit;
    my @choices;
    foreach my $variant (variants($unit)) {
	# Convert from $old to $variant
	# Input: 4 / ms
	# 1 ms -> 1000 us
	# 4 * 1000 ** -1 = .04 / us
	my $c = convert([ 1, $old ], $variant);
	$val *= $c->[0] ** $power;
	$old = $variant;

	my $score = score($val, $variant, $top);
	print "Variant($unit)=$val $variant score=$score\n";
	next if (! $keepall) && ($score == 0);
	push @choices, [ $score, $variant ];
    }

    @choices = sort { $b->[0] <=> $a->[0] } @choices;
    return () if @choices == 0;
    @choices = ($choices[0]) if not $keepall; # Single best one

    return map { [ {$unit => $_->[1]}, $_->[0] ] } @choices;
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

# render : <value,unit> -> string
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
    my ($val, $unit, $top) = @_;
    my $pref = get_pref($unit);
    return $pref if @$top == 0; # 782/sec
    my $range_score = range_score([ $val, [ 'dot', @$top ] ]);
    return $pref * $range_score;
}

1;
