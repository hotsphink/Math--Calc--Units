package Units::Calc::Convert::Base2Metric;
use base 'Units::Calc::Convert::Metric'; # Overrides
use strict;

use vars qw(%metric_base2 %abbrev $metric_prefix_test);

%metric_base2 = ( kilo => 2**10,
		  mega => 2**20,
		  giga => 2**30,
		  tera => 2**40,
		  peta => 2**50,
		  exa => 2**60,
);

# No nanobytes, sorry
%abbrev = ( k => 'kilo',
	    m => 'mega',
	    g => 'giga',
	    t => 'tera',
	    p => 'peta',
	    e => 'exa',
);

sub get_metric {
    my ($self, $what) = @_;
    return $metric_base2{$what};
}

sub get_abbrev {
    my ($self, $what) = @_;
    return $abbrev{$what};
}

$metric_prefix_test = qr/^(${\join("|",keys %metric_base2)})/i;

sub get_prefix {
    my ($self, $what) = @_;
    if ($what =~ $metric_prefix_test) {
	return $1;
    } else {
	return;
    }
}

# Unnecessary efficiency hack: don't bother checking both upper & lower case
sub expand {
    my ($self, $char) = @_;
    return ($self->get_abbrev($char));
}

1;
