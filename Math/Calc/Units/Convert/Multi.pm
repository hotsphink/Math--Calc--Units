package Units::Calc::Convert::Multi;
use base 'Units::Calc::Convert::Base2Metric';
require Units::Calc::Convert::Time;
require Units::Calc::Convert::Byte;
use strict;
use vars qw(%units %metric_units %prefixable_metric_units %total_unit_map);

%units = (
);

%metric_units = (
);

%prefixable_metric_units = ( bps => [ 1, [ 'per', 'bit', 'sec' ] ],
);

sub unit_map {
    my ($self) = @_;
    if (keys %total_unit_map == 0) {
	%total_unit_map = (%{$self->SUPER::unit_map()},
			   %units,
			   %metric_units,
			   %prefixable_metric_units);
    }
    return \%total_unit_map;
}

sub canonical_unit { return; }

# Singular("Mbps") is Mbps, not Mbp
sub singular {
    my ($self, $unit) = @_;
    return $self->SUPER::singular($unit) unless $unit =~ /bps$/;
    return $unit;
}

# demetric : string => [ mult, base ]
#
sub demetric {
    my ($self, $string) = @_;
    if (my $prefix = $self->get_prefix($string)) {
	my $tail = lc($self->singular(substr($string, length($prefix))));
	if ($metric_units{$tail}) {
	    return [ $self->get_metric($prefix), $tail ];
	}
    } elsif (my $abbrev = $self->get_abbrev_prefix($string)) {
	my $tail = lc($self->singular(substr($string, length($abbrev))));
	if ($prefixable_metric_units{$tail}) {
	    my $prefix = $self->get_abbrev($abbrev);
	    return [ $self->get_metric($prefix), $tail ];
	}
    }

    return [ 1, $string ];
}

# simple_convert : value x unit -> value
sub simple_convert {
    my ($self, $v, $unit) = @_;
    my $from = $v->[1];

    if (my $easy = $self->SUPER::simple_convert($v, $unit)) {
	return $easy;
    }

    return; # Failed
}

# to_canonical : unit -> value
#
# This depends on only having canonical units as keys for the three hashes.
sub to_canonical {
    my ($self, $unit, $notTop) = @_;

    if ($notTop) {
	if (ref $unit) {
	    my @terms = map { $self->to_canonical($_, 1) } @$unit[1..$#$unit];
	    # THESE ONLY HANDLE SIMPLE UNITS!!!
	    # This whole thing is a nasty hack. Yuckth.
	    if ($unit->[0] eq 'dot') {
		my $prod = 1;
		$prod *= $_->[0] foreach (@terms);
		return [ $prod, [ 'dot', map { $_->[1] } @terms ] ];
	    } else {
		return [ $terms[0]->[0] / $terms[1]->[0],
			 $terms[0]->[1], $terms[1]->[1] ];
	    }
	} else {
	    if (my $c = Units::Calc::Convert::Time->to_canonical($_)) {
		return $c;
	    }
	    if (my $c = Units::Calc::Convert::Byte->to_canonical($_)) {
		return $c;
	    }
	}
    }

    foreach (keys %units, keys %metric_units, keys %prefixable_metric_units) {
	if (my $c = $self->simple_convert([ 1, $unit ], $_)) {
	    my $u = $units{$_}
	         || $metric_units{$_}
	         || $prefixable_metric_units{$_};
	    $u = [ $u->[0] * $c->[0], $u->[1] ];
	    return $u if not ref $u->[1];
	    my ($val, $unit) = @$u;
	    $c = $self->to_canonical($unit, 1);
	    return [ $c->[0] * $val, $c->[1] ];
	}
    }

    return;
}

1;
