package Math::Calc::Units::Convert;
use base 'Exporter';
use strict;
use vars qw(@EXPORT_OK);
BEGIN { @EXPORT_OK = qw(convert reduce canonical find_top); };

use Math::Calc::Units::Convert::Multi qw(to_canonical);

# convert : value x unit -> value
#
# The lower-level conversion routines really only know how to convert
# things to canonical units. But this routine may be called with eg
# 120 minutes -> hours. So we convert both the current and target to
# canonical units, and divide the first by the second. (It'll be a
# pain when I need to add units that aren't just multiples of each
# other, but that's not what this tool is for anyway...)
sub convert {
    my ($from, $unit) = @_;

#      my $from = [ $v->[0], canonical_form($v->[1]) ];
#      my $to = [ 1, canonical_form($unit) ];
    my $to = [ 1, $unit ];

    my $canon_from = canonical($from);
    my $canon_to = canonical($to);

    return [ $canon_from->[0] / $canon_to->[0], $unit ];
}

sub canonical {
    my ($v) = @_;

    $DB::single = 1 if not ref $v->[1];
    my $c = to_canonical($v->[1]);
    my $w = [ $v->[0] * $c->[0], $c->[1] ];
    return $w;
}

sub reduce {
    my ($v) = @_;
    return canonical($v, 'reduce, please');
}

1;
