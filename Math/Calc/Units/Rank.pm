package Math::Calc::Units::Rank;
use base 'Exporter';
use vars qw(@EXPORT_OK);
BEGIN { @EXPORT_OK = qw(choose_juicy_ones render render_unit); }

use Math::Calc::Units::Convert qw(convert canonical);
use Math::Calc::Units::Convert::Multi qw(variants major_variants major_pref pref_score range_score get_class);
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

# choose_juicy_ones : value -> ( value )
#
sub choose_juicy_ones {
    my ($v, $verbose) = @_;
    my @variants = rank_variants($v, 0, $verbose); # ( < {old=>new}, score > )
    my %variants; # To remove duplicates: { id => [ {old=>new}, score ] }
    for my $variant (@variants) {
	my $id = join(";;", values %{ $variant->[0] });
	$variants{$id} = $variant;
    }

    my @juicy;

    for my $variant (values %variants) {
	my ($map, $score) = @$variant;
	my %copy;
	while (my ($unit, $count) = each %{ $v->[1] }) {
	    $copy{$map->{$unit}} = $count;
	}
	push @juicy, [ $score, convert($v, \%copy) ];
    }

    return map { $_->[1] } sort { $b->[0] <=> $a->[0] } @juicy;
}

# rank_variants : <amount,unit> -> ( < map, score > )
# where map : {original unit => new unit}
#
sub rank_variants {
    my ($v, $keepall, $verbose) = @_;

    # I. Convert to canonical form
    $v = canonical($v);

    # II. Reduce unit down to the atomic component units and their powers
    # eg mb / sec / sec -> <mb,1>, <sec,-2>
    my ($mag, $count) = @$v;

    my @rangeable = grep { $count->{$_} > 0 } keys %$count;
    if (@rangeable == 0) {
	@rangeable = keys %$count;
    }

    return rank_power_variants($mag, \@rangeable, $count, $keepall, $verbose);
}

sub choose_major {
    my (@possibilities) = @_;
    my @majors = map { [ major_pref($_), $_ ] } @possibilities;
    return (sort { $a->[0] <=> $b->[0] } @majors)[-1]->[1];
}

# rank_power_variants : value x [unit] x {unit=>power} x keepall_flag ->
#  ( <map,score> )
#
# $top is the set of units that should be range checked.
#
sub rank_power_variants {
    my ($mag, $top, $power, $keepall, $verbose) = @_;

    # Recursive case: we have multiple units left, so pick one to be
    # the "major" unit and select the best combination of the other
    # units for each major variant on the major unit.

    if (keys %$power > 1) {
	# Choose the major unit class (this will return the best
	# result for each of the major variants)
	my $major = choose_major(keys %$power);
	my $majorClass = get_class($major);

	my %powerless = %$power;
	delete $powerless{$major};

	my @ranked;

	# Try every combination of each major variant and the other units
	foreach my $variant (major_variants($major)) {
	    my $mult = $majorClass->simple_convert($variant, $major);
	    my $cval = $mag / $mult ** $power->{$major};

	    print "\n --- for $variant ---\n" if $verbose;
	    my @r = rank_power_variants($cval, $top, \%powerless, $keepall, $verbose);
	    next if @r == 0;

	    my $best = $r[0];
	    $best->[0]->{$major} = $variant;
	    push @ranked, $best;
	}

	if (@ranked == 0) {
	    return rank_power_variants($mag, $top, $power, 1, $verbose);
	}

	# Update scores to reflect preferences

	return @ranked;
    }

    # Base case: have a single unit left. Go through all possible
    # variants of that unit.

    if (keys %$power == 0) {
	# Special case: we don't have any units at all
	return [ {}, 'unit' ];
    }

    my $unit = (keys %$power)[0];
    $power = $power->{$unit}; # Now it's just the power of this unit
    my $class = get_class($unit);
    my (undef, $canon) = $class->to_canonical($unit);
    my $mult = $class->simple_convert($unit, $canon);
    $mag *= $mult ** $power;

    my @choices;
    foreach my $variant (variants($canon)) {
	# Convert from $old to $variant
	# Input: 4 / ms
	# 1 ms -> 1000 us
	# 4 * 1000 ** -1 = .04 / us
	my $mult = $class->simple_convert($variant, $canon);
	$DB::single = 1 if not $mult;
	my $minimag = $mag / $mult ** $power;

	my $score = score($minimag, $variant, $top);
	print "($mag $unit) score $score:\t $minimag $variant\n"
	    if $verbose;
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

    my @top;
    my @bottom;
    while (my ($name, $power) = each %$u) {
	if ($power > 0) {
	    push @top, $name;
	} else {
	    push @bottom, $name;
	}
    }

    my $str = '';
    foreach my $name (@top) {
	if ($u->{$name} == 1) {
	    $str .= "$name ";
#  	} elsif ($u->{$name} == 2) {
#  	    $str .= "square $name ";
#  	} elsif ($u->{$name} == 3) {
#  	    $str .= "cubic $name ";
	} else {
	    $str .= "$name**$u->{$name} ";
	}
    }

    if (@bottom == 0) { chop($str); return $str; }

    my %dummy;
    @dummy{@bottom} = @$u{@bottom};
    $dummy{$_} *= -1 for (keys %dummy);
    my $botstr = render_unit(\%dummy);

    if (@bottom > 1) {
	$str .= "/ ($botstr)";
    } else {
	$str .= "/ $botstr";
    }

    return $str;
}

# render : <value,unit> -> string
sub render {
    my $v = shift;
    my $u = render_unit($v->[1]);

    my $mag = sprintf("%.4g", $v->[0]);
    if ($u eq '') {
	return $mag;
    } else {
	return "$mag $u";
    }
}

# pref(nonref unit) = ...
# pref(dot(a,b...)) = MIN(pref(a),pref(b),...)
# pref(per(a,b)) = 75% pref(a) + 25% pref(b)
sub get_pref {
    my $unit = shift;

    my $pref;
    if (! ref $unit) {
	return pref_score($unit);
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

# max_range_score : amount x [ unit ] -> score
#
# Takes max score for listed units.
#
sub max_range_score {
    my ($mag, $units) = @_;
    my $score = 0;

    foreach my $name (@$units) {
	my $uscore = range_score($mag, $name);
	$score = $uscore if $score < $uscore;
    }

    return $score;
}

sub score {
    my ($mag, $unit, $top) = @_;
    my @rangeable = @$top ? @$top : ($unit);
    my $pref = get_pref($unit);
    my $range_score = max_range_score($mag, \@rangeable);
    return $pref * $range_score;
}

1;
