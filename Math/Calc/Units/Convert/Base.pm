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

# 837473sec -> 12 weeks, 4 days, 2 hours, 3 sec
# @units MUST BE SORTED, LARGER UNITS FIRST!
sub spread {
    my ($self, $v, @units) = @_;

    my $orig = $v;

    my @desc;
    foreach my $unit (@units) {
	last if $v->[0] == 0;
	my $w = $self->convert($v, $unit);
	if ($self->score($w) >= 1) {
	    my $round = int($w->[0]);
	    push @desc, [ $round, $w->[1] ];
	    $w->[0] -= $round;
	    $v = $w;
	    # (check remainder's percentage of original)
	}
    }

    # TODO: Cut off the spreading when the smaller units contribute
    # inconsequential amounts

    return @desc;
}

# range_score : amount x unitName -> score
#
sub range_score {
    my ($self, $val, $unitName) = @_;
    my $ranges = $self->get_ranges();
    my $range = $ranges->{$unitName} || $ranges->{default};
    return 0 if $val < $range->[0];
    return 1 if ! defined $range->[1];
    return 0 if $val > $range->[1];
    return 1;
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

1;
