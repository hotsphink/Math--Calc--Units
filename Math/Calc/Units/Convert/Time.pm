package Units::Calc::Convert::Time;
use base 'Units::Calc::Convert::Metric';
use strict;
use vars qw(%units %pref %ranges %total_unit_map);

%units = ( minute => [ 60, 'sec' ],
	   hour => [ 60, 'minute' ],
	   day => [ 24, 'hour' ],
	   week => [ 7, 'day' ],
	   min => [ 1, 'minute' ],
);

%pref = ( default => 1,
	  hour => 1.2,
	  day => 1.1,
	  week => 0.4,
	  minute => 1.1,
);

%ranges = ( default => [ 1, 300 ],
	    millisec => [ 1, 999 ],
	    sec => [ 1, 200 ],
	    minute => [ 2, 100 ],
	    hour => [ 1, 80 ],
	    day => [ 1, undef ],
	    week => [ 1, 4 ],
);

# Return a list of the variants of the canonical unit of time: 'sec'
sub variants {
#    my ($self) = @_;
    return keys %units;
}

sub unit_map {
    my ($self) = @_;
    if (keys %total_unit_map == 0) {
	%total_unit_map = (%{$self->SUPER::unit_map()}, %units);
    }
    return \%total_unit_map;
}

sub canonical_unit { return 'sec'; }

# demetric : string => [ mult, base ]
#
# Must override here to avoid megahours or milliweeks
#
sub demetric {
    my ($self, $string) = @_;
    if (my $prefix = $self->get_prefix($string)) {
	my $tail = substr($string, length($prefix));
	if ($tail =~ /^sec(ond)?s?$/) {
	    return [ $self->get_metric($prefix), $tail ];
	}
	return; # Should this fail, or assume it's a non-metric unit?
    } else {
	return [ 1, $string ];
    }
}

# simple_convert : value x unit -> value
#
# Does not allow msec (only millisec or ms)
#
sub simple_convert {
    my ($self, $v, $unit) = @_;
    my $from = $v->[1];

    # sec, secs, second, seconds
    return [ $v->[0], 'sec' ] if $from =~ /^sec(ond)?s?$/i;

    if (my $easy = $self->SUPER::simple_convert($v, $unit)) {
	return $easy;
    }

    # ms == millisec
    if ($from =~ /^(.)s$/) {
	my @expansions = $self->expand($1);
	# Only use prefixes smaller than one, and pick the first
	my ($expansion) = grep { ($self->demetric($from))[0] < 1 } @expansions;
	if ($expansion) {
	    return $self->simple_convert($v, $expansion . "sec");
	}
    }

    return; # Failed
}

##############################################################################

sub describe {
    my $self = shift;
    my $v = shift;
    die "Huh? Can only do seconds!" if $v->[1] ne 'sec';
    my @spread = $self->spread($v, 'week', 'day', 'hour', 'minute', 'sec',
			       'ms', 'us', 'ns', 'ps');
    return (\@spread, $v); # Hmm... what type am I returning??
}

sub preference {
    my ($self, $v) = @_;
    my ($val, $unit) = @$v;
    my $base = lc(($self->demetric($unit))[1]);
    my $pref = $pref{$base} || $pref{default};
    return $pref * $self->prefix_pref(substr($unit, 0, -length($base)));
}

sub get_ranges {
    return \%ranges;
}

sub get_prefs {
    return \%pref;
}

1;
