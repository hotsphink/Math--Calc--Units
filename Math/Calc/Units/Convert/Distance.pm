package Math::Calc::Units::Convert::Distance;
use base 'Math::Calc::Units::Convert::Metric';
use strict;
use vars qw(%units %pref);

my %distance_units = ( inch => [ 2.54, 'centimeter' ],
		       foot => [ 12, 'inch' ],
		       yard => [ 3, 'foot' ],
		       mile => [ 5280, 'foot' ],
);

my %distance_pref = ( meter => 1.1,
		      inch => 0.7,
		      foot => 0.9,
		      yard => 0,
		      mile => 1.0,
);

my %aliases = ( 'feet' => 'foot',
		'second' => 'sec',
		'h' => 'hour',
		'hr' => 'hour',
		'min' => 'minute',
);

1;
