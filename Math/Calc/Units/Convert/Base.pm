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

sub to_canonical {
    my ($self, $unit) = @_;
    my $canon = $self->canonical_unit();
    return $canon if $self->simple_convert([ 1, $unit ], $canon);
    return;
}

1;
