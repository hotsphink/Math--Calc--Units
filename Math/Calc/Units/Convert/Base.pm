package Units::Calc::Convert::Base;
use strict;

sub import {
    my $pkg = shift;
    my %actions = @_;
    if (my $sub = $actions{register}) {
	$sub->($pkg);
    }
}

sub singular {
    return; # Could not handle specially
}

sub unit_map {
    return {};
}

sub same {
    my ($self, $u, $v) = @_;
    if (ref $u) {
	return if ! ref $v;
	return if $u->[0] ne $v->[0];
	return if @$u != @$v;
	for my $i (1..$#$u) {
	    return if ! $self->same($u->[$i], $v->[$i]);
	}
	return 1;
    } else {
	return $u eq $v;
    }
}

# simple_convert : value x unit -> value
#
# Only handles nonreference units
#
sub simple_convert {
    my ($self, $v, $unit) = @_;

    my ($val, $from) = @$v;
    return $v if $from eq $unit;

    die if ref $from;
    $DB::single = 1, die if ref $unit;

    my $map = $self->unit_map();
    my $w = $map->{$from} || $map->{lc($from)};
    if (! $w) {
	$from = Units::Calc::Convert::singular($from);
	$w = $map->{$from} || $map->{lc($from)};
    }
    return if ! $w; # Failed

    $w = [ $w->[0] * $val, $w->[1] ];

    # We might have only gotten one step closer (hour -> minute -> sec)
    if ($self->same($w->[1], $unit)) {
	return $w;
    } else {
	return $self->simple_convert($w, $unit);
    }
}

# to_canonical : unit -> value
sub to_canonical {
    my ($self, $unit) = @_;
    my $canon = $self->canonical_unit();
    return $self->simple_convert([ 1, $unit ], $canon);
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

sub range_score {
    my ($self, $v) = @_;
    my ($val, $unit) = @$v;
    my $ranges = $self->get_ranges();
    my $range = $ranges->{$unit} || $ranges->{default};
    return 0 if $val < $range->[0];
    return 1 if ! defined $range->[1];
    return 0 if $val > $range->[1];
    return 1;
}

sub pref_score {
    my ($self, $unit) = @_;
    my $prefs = $self->get_prefs();
    return $prefs->{$unit} || $prefs->{default};
}

1;
