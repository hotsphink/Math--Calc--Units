package Math::Calc::Units::Convert::Base;
use strict;

sub major_pref {
    return 0;
}

sub major_variants {
    return ();
}

# singular : unitName -> unitName
#
sub singular {
    my $self = shift;
    local $_ = shift;

    return $_ unless /s$/;
    return $1 if /^(.*[^e])s/;  # doesn't end in es => just chop off the s
    return $1 if /^(.*ch)es/;   # eg inches -> inch
    return $1 if /^(.*[aeiou][^aeiou]e)s/; # scales -> scale
    chop; return $_; # Chop off the s
}

sub unit_map {
    return {};
}

sub variants {
    my ($self, $base) = @_;
    my $map = $self->unit_map();
    return ($base, keys %$map);
}

# unit x unit -> boolean
sub same {
    my ($self, $u, $v) = @_;
    return 0 if keys %$u != keys %$v;
    while (my ($name, $power) = each %$u) {
	return 0 if $v->{$name} != $power;
    }
    return 1;
}

# simple_convert : unitName x unitName -> multiple:number
#
# Second unit name must be canonical.
#
sub simple_convert {
    my ($self, $from, $to) = @_;
    return 1 if $from eq $to;

    {
	my $canon_unit = $self->canonical_unit();
	$DB::single = 1 if $canon_unit && $to ne $canon_unit;
    }

    my $map = $self->unit_map();
    my $w = $map->{$from} || $map->{lc($from)};
    if (! $w) {
	$from = $self->singular($from);
	$w = $map->{$from} || $map->{lc($from)};
    }
    return if ! $w; # Failed

    # We might have only gotten one step closer (hour -> minute -> sec)
    if ($w->[1] ne $to) {
	my $submult = $self->simple_convert($w->[1], $to);
	return if ! defined $submult;
	return $w->[0] * $submult;
    } else {
	return $w->[0];
    }
}

# to_canonical : unitName -> amount x unitName
#
sub to_canonical {
    my ($self, $unitName) = @_;
    my $canon = $self->canonical_unit();
    if ($canon) {
	my $mult = $self->simple_convert($unitName, $canon);
	return if ! defined $mult;
	return ($mult, $canon);
    } else {
	return (1, $self->singular($unitName));
    }
}

sub canonical_unit {
    return;
}

#################### RANKING, SCORING, DISPLAYING ##################

# spread : magnitude x base unit x units to spread over
#  -> ( <mag,unit> )
#
# @$units MUST BE SORTED, LARGER UNITS FIRST!
#
my $THRESHOLD = 0.01;
sub spread {
    my ($self, $mag, $base, $start, $units) = @_;
    die if $mag < 0; # Must be given a positive value!
    return [ 0, $base ] if $mag == 0;

    my $orig = $mag;

    my @desc;
    my $started = 0;
    foreach my $unit (@$units) {
	$started = 1 if $unit eq $start;
	next unless $started;

	last if ($mag / $orig) < $THRESHOLD;
	my $mult = $self->simple_convert($unit, $base);
	my $n = int($mag / $mult);
	next if $n == 0;
	$mag -= $n * $mult;
	push @desc, [ $n, $unit ];
    }

    return @desc;
}

# range_score : amount x unitName -> score
#
sub range_score {
    my ($self, $val, $unitName, $allow_out_of_range) = @_;
    if ($allow_out_of_range) {
	return $self->norm_range_score($val, $unitName);
    }
    my $ranges = $self->get_ranges();
    my $range = $ranges->{$unitName} || $ranges->{default};
    return 0 if $val < $range->[0];
    return 1 if ! defined $range->[1];
    return 0 if $val > $range->[1];
    return 1;
}

sub _sillylog {
    my $x = shift;
    return log($x) if $x;
    return log(1e-50);
}

# norm_range_score : amount x unitName -> score
#
# This is for use when nothing is found in range, and you want to pick
# the best of the bad. For no good reason, I convert to log space (so
# 1/400 is just as far away from 1 as 400), and use a normal
# distribution where the allowed range is the 1 standard deviation
# range.
#
# Oh, and now I add in a bonus 0.1 to give the preference multiplier
# something to work with. Does wonders for shooting down centiseconds.
#
sub norm_range_score {
    my ($self, $val, $unitName) = @_;
    my $ranges = $self->get_ranges();
    my $range = $ranges->{$unitName} || $ranges->{default};

    # Return 1 if it's in range
    if ($val >= $range->[0]) {
	if (! defined $range->[1] || ($val <= $range->[1])) {
	    return 1;
	}
    }

    $val = _sillylog($val);

    my $r0 = _sillylog($range->[0]);
    my $r1;
    if (defined $range->[1]) {
	$r1 = _sillylog($range->[1]);
    } else {
	$r1 = 4;
    }

    my $width = $r1 - $r0;
    my $mean = ($r0 + $r1) / 2;
    my $stddev = $width / 2;

    my $n = ($val - $mean) / $stddev; # Normalized value

    return exp(-$n**2/2) + 0.1;
}

# pref_score : unitName -> score
#
sub pref_score {
    my ($self, $unitName) = @_;
    my $prefs = $self->get_prefs();
    return $prefs->{$unitName} || $prefs->{default};
}

sub get_prefs {
    return { default => 0.1 };
}

sub get_ranges {
    return { default => [ 1, undef ] };
}

sub render_unit {
    my ($self, $name, $power) = @_;
    if ($power == 1) {
	return $name;
    } else {
	return "$name**$power";
    }
}

sub render {
    my ($self, $val, $name, $power) = @_;
    return sprintf("%.4g ",$val).$self->render_unit($name, $power);
}

1;
