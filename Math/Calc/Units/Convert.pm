package Units::Calc::Convert;
use base 'Exporter';
use strict;

use vars qw(@Registry @EXPORT_OK);
@EXPORT_OK = qw(convert reduce);

sub add_unitSet {
    my $package = shift;
    eval "use $package";
    push @Registry, $package;
    print STDERR "Registering $package\n";
}

use Units::Calc::Convert::Time register => \&add_unitSet;
#use Units::Calc::Convert::Distance register => \&add_unitSet;
use Units::Calc::Convert::Byte register => \&add_unitSet;
use Units::Calc::Convert::Multi register => \&add_unitSet;

sub apply_all ($) {
    my $sub = shift;
    foreach my $unitType (@Registry) {
	$sub->($unitType);
    }
}

sub apply_until ($) {
    my $sub = shift;
    foreach my $unitType (@Registry) {
	if (my $tmp = $sub->($unitType)) {
	    return $tmp;
	}
    }

    return;
}

# Use the Orcish Maneuver to memoize canonical units, computed by
# attempting to convert the given unit to each unit class's canonical
# unit type.
use vars qw(%CANON_UNIT_MAP);
sub canonical_unit {
    my ($u) = @_;
    $CANON_UNIT_MAP{$u} ||= apply_until(sub { shift()->to_canonical($u); });
    return $CANON_UNIT_MAP{$u};
}

sub singular {
    local $_ = shift;
    apply_until(sub { shift()->singular($_); });

    # Enough rules to handle common units
    # Move this into Units::Calc::Convert::User?
    return $_ unless /s$/;
    return $1 if /^(.*[^e])s/;  # doesn't end in es => just chop off the s
    return $1 if /^(.*ch)es/;   # eg inches -> inch
    return $1 if /^(.*[aeiou][^aeiou]e)s/; # scales -> scale
    chop; return $_; # Chop off the s
}

#    return { bps => [ 1, [ 'per', 'bit', 'sec' ] ] };

# dot() -> unit
# dot(a) -> a
# dot(a,b,...) -> [ 'dot', a, b, ... ]
#
sub dot {
    return 'unit' if @_ == 0;
    return $_[0] if @_ == 1;
    return [ 'dot', @_ ];
}

sub simple_convert {
    my ($u, $v) = @_;
    return apply_until(sub { shift()->simple_convert($u, $v) });
}

sub get_dot {
    my $ref = shift;
    return @$ref[1..$#$ref];
}

sub get_per {
    my $ref = shift;
    return @$ref[1..2];
}

# $unit and $v->[1] are now both guaranteed to be of canonical form
#
# This is really a recursion through the unit graph, with
# simple_convert handling the base case by iterating through all known
# unit classes.
sub canon_convert {
    my ($self, $v, $unit) = @_;
    my ($val, $from) = @$v;

    if (ref($from) && $from->[0] eq 'dot') {
	return if $unit->[0] ne 'dot';
	return if @$from != @$unit;

	for my $i (1..$#$from) {
	    my $conv = canon_convert([ 1, $from->[$i] ], $unit->[$i]);
	    return if ! $conv;
	    $val *= $conv->[0];
	}
    } elsif (ref($from) && $from->[0] eq 'per') {
	return if $unit->[0] ne 'per';

	my ($top, $bottom);
	my $resultUnit = [ @$unit ];
	if (!($top = canon_convert([ 1, $from->[1] ], $unit->[1]))) {
	    $resultUnit->[1] = $from->[1];
	    $top = [ 1, $from->[1] ];
	}
	if (!($bottom = canon_convert([ 1, $from->[2] ], $unit->[2]))) {
	    $resultUnit->[2] = $from->[2];
	    $bottom = [ 1, $from->[2] ];
	}
	return [ $val * $top->[0] / $bottom->[0], $resultUnit ];
    } else {
	return simple_convert($v, $unit);
    }
}

# convert : value x unit -> value
#
# The lower-level conversion routines really only know how to convert
# things to canonical units. But this routine may be called with eg
# 120 minutes -> hours. So we convert both the current and target to
# canonical units, and divide the first by the second. (It'll be a
# pain when I need to add units that aren't just multiples of each
# other, but that's not what this tool is for anyway...)
sub convert {
    my ($v, $unit) = @_;

    my $from = [ $v->[0], canonical_form($v->[1]) ];
    my $to = [ 1, canonical_form($unit) ];

    my $canon_from = canonical($from);
    my $canon_to = canonical($to);

    return [ $canon_from->[0] / $canon_to->[0], $unit ];
}

sub _find_top ($;$) {
    my ($unit, $invert) = @_;
    if (! ref $unit) {
        return $unit unless $invert;
        return;
    } elsif ($unit->[0] eq 'dot') {
        my @dots = @$unit;
        shift(@dots);
        return map { _find_top($_, $invert) } @dots;
    } elsif ($unit->[0] eq 'per') {
        return _find_top($unit->[1], $invert),
               _find_top($unit->[2], ! $invert);
    } else {
        die "Unknown unit ".Dumper($unit);
    }
}

# canonical : value -> value
#
# Takes [ amount, units ] and replaces all simple units within the
# given units to the canonical unit, when valid, and adjusts the
# amount accordingly.
#
sub canonical {
    my ($v, $do_reduce) = @_;

    # 1. Reduce it to unit * unit * ... * unit / (unit * unit * ... * unit)
    # or equivalently [ 'per', [ 'dot', ... ], [ 'dot', ... ] ]
    #                 or [ 'dot', ... ]
    #                 or unit

    my @top = _find_top($v->[1]);
    my @bottom = _find_top($v->[1], 'invert');

    # 2. Canonicalize to PROD(M)/PROD(N)
    my $val = $v->[0];
    my $unit = 'unit';
    foreach my $u (@top) {
        my $c = simple_convert([ 1, $u ], canonical_unit($u));
	$c ||= [ 1, $u ];
	$val *= $c->[0];
	$unit = _unit_mult($unit, $c->[1]);
    }
    foreach my $u (@bottom) {
        my $c = simple_convert([ 1, $u ], canonical_unit($u));
	$c ||= [ 1, $u ];
	$val /= $c->[0];
	$unit = _unit_divide($unit, $c->[1], $do_reduce);
    }

    return [ $val, $unit ];
}

sub reduce {
    my ($v) = @_;
    return canonical($v, 'reduce, please');
}

# Similar to canonical(), above, except none of the units should be
# changed, only the structure.
sub canonical_form {
    my ($unit) = @_;

    my @top = _find_top($unit);
    my @bottom = _find_top($unit, 'invert');

    return _canonical_reciprocal(\@top, \@bottom);
}

sub _canonical_reciprocal {
    my ($top, $bottom, $do_reduce) = @_;

    my @top;
    my @bottom;

    if ($do_reduce) {
	my %count;
	$count{$_}++ foreach @$top;
	$count{$_}-- foreach @$bottom;
	delete $count{unit};
	while (my ($unit, $count) = each %count) {
	    if ($count > 0) {
		push @top, ($unit) x $count;
	    } elsif ($count < 0) {
		push @bottom, ($unit) x -$count;
	    }
	}
	@top = sort @top;
	@bottom = sort @bottom;
    } else {
	@top = grep { $_ ne 'unit' } sort @$top;
	@bottom = grep { $_ ne 'unit' } sort @$bottom;
    }

    if (@bottom == 0 && @top == 0) {
	return 'unit';
    } elsif (@bottom == 0) {
	return dot(@top);
    } else {
	return [ 'per', dot(@top), dot(@bottom) ];
    }
}

# Multiplies two canonical units together to form a canonical unit.
sub _unit_mult ($$;$) {
    my ($u, $v, $do_reduce) = @_;
    my @top = _find_top($u);
    my @bottom = _find_top($u, 'invert');
    push @top, _find_top($v);
    push @bottom, _find_top($v, 'invert');
    return _canonical_reciprocal(\@top, \@bottom, $do_reduce);
}

sub _unit_divide ($$;$) {
    my ($u, $v, $do_reduce) = @_;
    return _unit_mult($u, ['per', 'unit', $v], $do_reduce);
}

################################### OUTPUT ###################################

# describe : value -> ( value )
sub describe {
    my ($self, $v) = @_;
    my @equivs = $self->variants();
    my @descs;
    foreach my $unit (@equivs) {
	my $w = $self->convert($v, $unit);
	my $score = $self->score($w);
	push @descs, [ $w, $score ];
    }
    return map { $_->[0] } sort { $b->[1] <=> $a->[1] } @descs;
}

sub score {
    my $v = shift;
    return 1 if ($v->[0] > 1 && $v->[0] <= 999);
    return 0.5;
}

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

1;
