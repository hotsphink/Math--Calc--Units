package Units::Calc::Convert::Byte;
use base 'Units::Calc::Convert::Base2Metric';
use strict;
use vars qw(%units %pref %ranges %total_unit_map);

%units = ( bit => [ 1/8, 'byte' ] );
%pref = ( bit => 0.1, default => 1 );
%ranges = ( default => [ 1, 999 ] );

sub major_pref {
    return 1;
}

sub major_variants {
    my ($self) = @_;
    return $self->variants('byte');
}

sub get_ranges {
    return \%ranges;
}

sub get_prefs {
    return \%pref;
}

sub unit_map {
    my ($self) = @_;
    if (keys %total_unit_map == 0) {
	%total_unit_map = (%{$self->SUPER::unit_map()}, %units);
    }
    return \%total_unit_map;
}

sub canonical_unit { return 'byte'; }

# simple_convert : unitName x unitName -> multiplier
#
sub simple_convert {
    my ($self, $from, $to) = @_;

    # 'b', 'byte', or 'bytes'
    return 1 if $from =~ /^b(yte(s?))?$/i;

    if (my $easy = $self->SUPER::simple_convert($from, $to)) {
	return $easy;
    }

    # mb == megabyte
    if ($from =~ /^(.)b(yte(s?))?$/i) {
	if (my $prefix = $self->expand($1)) {
	    return $self->simple_convert($prefix . "byte", $to);
	}
    }

    return; # Failed
}

1;
