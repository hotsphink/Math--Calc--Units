package Units::Calc::Convert::Multi;
use base 'Units::Calc::Convert::Base2Metric';
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

# to_canonical : unit -> unit
#
# This depends on only having canonical units as keys for the three hashes.
sub to_canonical {
    my ($self, $unit) = @_;
    $DB::single = 1;
    foreach (keys %units, keys %metric_units, keys %prefixable_metric_units) {
	if (my $c = $self->simple_convert([ 1, $unit ], $_)) {
	    return $c->[1];
	}
    }
    return;
}

1;
