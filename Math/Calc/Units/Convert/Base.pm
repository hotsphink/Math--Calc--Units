package Units::Calc::Convert::Base;
use strict;

sub import {
    my $pkg = shift;
    my %actions = @_;
    if (my $sub = $actions{register}) {
	$sub->($pkg);
    }
}

# Enough rules to handle common units
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
    return { bps => [ 1, [ 'per', 'bit', 'sec' ] ] };
}

sub dot {
    return 'unit' if @_ == 0;
    return $_[0] if @_ == 1;
    return [ 'dot', @_ ];
}

# simple_convert : value x unit -> value
#
# Only handles nonreference units
#
sub simple_convert {
    my ($self, $v, $unit) = @_;

    my ($val, $from) = @$v;

    die if ref $from;
    die if ref $unit;

    my $map = $self->unit_map();
    my $w = $map->{$from} || $map->{lc($from)};
    if (! $w) {
	$from = $self->singular($from);
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

sub get_dot {
    my $ref = shift;
    return @$ref[1..$#$ref];
}

sub get_per {
    my $ref = shift;
    return @$ref[1..2];
}

# $unit and $v->[1] are now both guaranteed to be of canonical form
# with respect to the current unit type.
sub canon_convert {
    my ($self, $v, $unit) = @_;
    my ($val, $from) = @$v;

    if (ref($from) && $from->[0] eq 'dot') {
	return if $unit->[0] ne 'dot';
	return if @$from != @$unit;

	for my $i (1..$#$from) {
	    my $conv = $self->canon_convert([ 1, $from->[$i] ], $unit->[$i]);
	    return if ! $conv;
	    $val *= $conv->[0];
	}
    } elsif (ref($from) && $from->[0] eq 'per') {
	return if $unit->[0] ne 'per';

	my ($top, $bottom);
	my $resultUnit = [ @$unit ];
	if (!($top = $self->canon_convert([ 1, $from->[1] ], $unit->[1]))) {
	    $resultUnit->[1] = $from->[1];
	    $top = [ 1, $from->[1] ];
	}
	if (!($bottom = $self->canon_convert([ 1, $from->[2] ], $unit->[2]))) {
	    $resultUnit->[2] = $from->[2];
	    $bottom = [ 1, $from->[2] ];
	}
	return [ $val * $top->[0] / $bottom->[0], $resultUnit ];
    } else {
	return $self->simple_convert($v, $unit);
    }
}

sub output_unit {
    my ($self, $from, $to, $canon_to) = @_;
    if (ref $from) {
	my $out = [ $from->[0] ];
	for my $i (1..$#$from) {
	    push @$out, $self->output_unit($from->[$i], $to->[$i], $canon_to->[$i]);
	}
	return $out;
    } else {
	return $to if ($to eq $self->canonical_unit());
	return $to if ($to ne $canon_to);
	return $from;
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
    my ($self, $v, $unit) = @_;

    my $from = [ $v->[0], $self->canonical_form($v->[1]) ];
    my $to = [ 1, $self->canonical_form($unit) ];

    my $canon_from = $self->canonical($from);
    my $canon_to = $self->canonical($to);

    # Output unit: for each leaf in the tree,
    #  $to    if $to is the canonical unit
    #  $to    if $to gets changed during canonicalization
    #  $from  otherwise

    return [ $canon_from->[0] / $canon_to->[0],
	     $self->output_unit($from->[1], $to->[1], $canon_to->[1]) ];

    # What unit to return?? Well, can't use $unit, because it is the
    # ultimate final unit (including conversions from things that
    # $self knows nothing about.) And we certainly can't use $v->[1],
    # because that's what we started with. And not $from->[1], because
    # it is always canonical and the caller may have requested a
    # non-canonical unit (eg, hours).
    #
    # So what we really want is $unit with all unknown units replaced
    # with their original values from $v->[1]. But the noncanonical
    # form of $unit makes it impossible to figure out which is which,
    # so we cheat and give the user globs if they ask for 1/(1/globs),
    # by canonicalizing the form of the units passed in before doing
    # anything else.
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

sub is_canonical_form {
    my ($self, $unit) = @_;
    return 1 if ! ref $unit;
    if ($unit->[0] eq 'dot') {
	return 0 if @$unit < 3;
	my $last;
	for (@$unit[1..$#$unit]) {
	    return 0 if ref $_;
	    return 0 if $last && ($last cmp $_ > 0); # Must be sorted
	    $last = $_;
	}
    } elsif ($unit->[0] eq 'per') {
	for ($unit->[1], $unit->[2]) {
	    return 0 if ($_->[0] ne 'dot');
	    return 0 if ! $self->is_canonical_form($_);
	}
    } else {
	$DB::single = 1;
	die "Huh? ($unit->[0])";
    }

    return 1;
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
# Example:
# [ 10, [ 'per', 'kilobytes', 'minute' ] ]
#     when processed by the Time converter produces
# [ ??, [ 'per', 'kilobytes', 'sec' ] ]
#
sub canonical {
    my ($self, $v, $do_reduce) = @_;

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
        my $c = $self->simple_convert([ 1, $u ], $self->canonical_unit());
	$c ||= [ 1, $u ];
	$val *= $c->[0];
	$unit = _unit_mult($unit, $c->[1]);
    }
    foreach my $u (@bottom) {
        my $c = $self->simple_convert([ 1, $u ], $self->canonical_unit());
	$c ||= [ 1, $u ];
	$val /= $c->[0];
	$unit = _unit_divide($unit, $c->[1], $do_reduce);
    }

    return [ $val, $unit ];
}

# Similar to the above, except none of the units should be changed,
# only the structure.
sub canonical_form {
    my ($self, $unit) = @_;

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
