package Units::Calc::Convert::Multi;
require Units::Calc::Convert::Time;
require Units::Calc::Convert::Byte;
require Units::Calc::Convert::Combo;
use strict;
use vars qw(%units %metric_units %prefixable_metric_units %total_unit_map);
use vars qw(@UnitClasses);

@UnitClasses = qw(Units::Calc::Convert::Time
		  Units::Calc::Convert::Byte
		  Units::Calc::Convert::Combo);

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

# sub canonical_unit { return; }

# to_canonical : unit -> value
#
# This depends on only having canonical units as keys for the three hashes.
sub to_canonical {
    my ($self, $unit) = @_;

    # CACHE!!

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
	foreach my $uclass (@UnitClasses) {
	    my $c;
	    return $c if $c = $uclass->to_canonical($_);
	}
	return [ 1, $unit ]; # Default to user-defined???
    }
}

sub get_class {
    my ($self, $unit) = @_;
    my $canon = Units::Calc::Convert::to_canonical($unit);
    foreach my $uclass (@UnitClasses) {
	return $uclass if $uclass->canonical_unit() eq $canon->[1];
    }
}

sub variants {
    my ($self, $base) = @_;
    return $base, keys %{ $self->get_class($base)->unit_map() };
}

sub range_score {
    my ($self, $v) = @_;
    die unless ! ref $v->[1];
    return $self->get_class($v->[1])->range_score($v);
}

sub pref_score {
    my ($self, $unit) = @_;
    die unless ! ref $unit;
    return $self->get_class($unit)->pref_score($unit);
}

1;
