package Units::Calc::Convert::Combo;
use base 'Units::Calc::Convert::Base2Metric';
use strict;
use vars qw(%units %metric_units %prefixable_metric_units %total_unit_map);
use vars qw(%ranges %pref);

%units = (
);

%metric_units = (
);

%prefixable_metric_units = ( bps => [ 1, [ 'per', 'bit', 'sec' ] ],
);

%ranges = ( default => [ 1, 999 ] );

%pref = ( default => 1 );

sub canonical_unit { return; }

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

# to_canonical : unit -> value
#
# This depends on only having canonical units as keys for the three hashes.
sub to_canonical {
    my ($self, $unit) = @_;

    foreach (keys %units, keys %metric_units, keys %prefixable_metric_units) {
	if (my $c = $self->simple_convert([ 1, $unit ], $_)) {
	    my $u = $units{$_}
	         || $metric_units{$_}
	         || $prefixable_metric_units{$_};
	    $u = [ $u->[0] * $c->[0], $u->[1] ];
	    return $u if not ref $u->[1];
	    my ($val, $unit) = @$u;
	    $c = Units::Calc::Convert::Multi->to_canonical($unit);
	    return [ $c->[0] * $val, $c->[1] ];
	}
    }

    return;
}

sub get_ranges {
    return \%ranges;
}

sub get_prefs {
    return \%pref;
}

1;
