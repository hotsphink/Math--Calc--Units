package Units::Calc;

# Allow this module to be invoked directly from the command line.
BEGIN {
    if (!(caller(2))) {
	eval 'use FindBin; use lib "$FindBin::Bin/..";';
    }
}

use Units::Calc::Compute qw(compute);
use Units::Calc::Rank qw(render choose_juicy_ones);
use Units::Calc::Convert;

use base 'Exporter';
use vars qw($VERSION @EXPORT_OK);
BEGIN {
    $VERSION = '1.00';
    @EXPORT_OK = qw(calc readable convert equal);
}
use strict;

# calc : string -> string
sub calc {
    my $expr = shift;
    my $v = compute($expr);
    return render($v);
}

# readable : string -> ( string )
sub readable {
    my ($expr, $verbose) = @_;
    my $v = compute($expr);
    return map { render($_) } choose_juicy_ones($v, $verbose);
}

# convert : string x string -> string
sub convert {
    my ($expr, $units) = @_;
    my $v = compute($expr);
    my $u = compute("# $units");
    my $c = Units::Calc::Convert::convert($v, $u->[1]);
    return render($c);
}

# equal : string x string -> boolean
use constant EPSILON => 1e-12;
sub equal {
    my ($u, $v) = @_;
    $u = compute($u);
    $v = compute($v);
    $v = Units::Calc::Convert::convert($v, $u->[1]);
    $u = $u->[0];
    $v = $v->[0];
    return 1 if ($u == 0) && abs($v) < EPSILON;
    return abs(($u-$v)/$u) < EPSILON;
}

if (!(caller)) {
    my $verbose;
    if ($ARGV[0] eq '-v') { shift; $verbose = 1; }
    print "$_\n" foreach readable($ARGV[0], $verbose);
}

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Units::Calc - Unit-aware calculator with adaptive output

=head1 SYNOPSIS

  use Units::Calc;
  blah blah blah

=head1 DESCRIPTION

Does stuff.

=head1 AUTHOR

Steve Fink, sfink@cpan.org

=head1 SEE ALSO

ucalc(1), Math::Units, Convert::Units.

=cut

1;
