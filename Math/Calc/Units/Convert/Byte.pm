package Units::Calc::Convert::Byte;
use base 'Units::Calc::Convert::Base2Metric';
use strict;
use vars qw(%units %pref %total_unit_map);

%units = ( bit => [ 1/8, 'byte' ] );
%pref = ( bit => 0.1 );

# Return a list of the variants of byte: none
sub variants {
#    my ($self) = @_;
    return; # No variants of byte
}

sub unit_map {
    my ($self) = @_;
    if (keys %total_unit_map == 0) {
	%total_unit_map = (%{$self->SUPER::unit_map()}, %units);
    }
    return \%total_unit_map;
}

sub canonical_unit { return 'byte'; }

sub simple_convert {
    my ($self, $v, $unit) = @_;
    my ($val, $from) = @$v;

    # 'b', 'byte', or 'bytes'
    return [ $val, 'byte' ] if $from =~ /^b(yte(s?))?$/i;

    if (my $easy = $self->SUPER::simple_convert($v, $unit)) {
	return $easy;
    }

    # mb == megabyte
    if ($from =~ /^(.)b(yte(s?))?$/i) {
	if (my $prefix = $self->expand($1)) {
	    return $self->simple_convert([ $val, $prefix . "byte" ], $unit);
	}
    }

    return; # Failed
}

sub describe {
    my $self = shift;
    my $v = shift;
    die "Huh? Can only do seconds!" if $v->[1] ne 'sec';
    my @spread = $self->spread($v, 'week', 'day', 'hour', 'minute', 'sec',
			       'ms', 'ns');
    return (\@spread, $v); # Hmm... what type am I returning??
}

1;
