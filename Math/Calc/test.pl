# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use lib '/home/sfink/units'; # Just so I can use perldb

######################### We start with some black magic to print on failure.

BEGIN { $| = 1; print "1..39\n"; }
END { print "not ok 1 - failed to use Math::Calc::Units\n" unless $loaded; }
use Math::Calc::Units qw(calc readable convert equal);
$loaded = 1;
$STATUS = 0;
print "ok 1 - initialization\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# I'd love to use Test::Simple/Test::More, but I don't want to depend
# on having them installed...

$NUMBER = 2;
sub ok ($$) {
    my ($passed, $message) = @_;
    if ($passed) {
	print "ok ".$NUMBER++;
    } else {
	print "not ok ".$NUMBER++;
	$STATUS = 1;
    }
    print " - $message" if $message;
    print "\n";
}

ok(equal("1 sec", "1 sec"), "basic equality");
ok(equal("1 sec", "1sec"), "whitespace");
ok(equal("1 sec", "1 byte * 1 sec / byte"), "simple reduction");
ok(equal("1 sec", "1 second"), "aliases");
ok(equal("1 secs", "1 seconds"), "plurals");
ok(equal("1024 bytes", "1 kilobyte"), "base 2 metric prefix");
ok(equal("1024 bytes", "1 KB"), "abbreviated metric prefix");
ok(equal(".001 sec", "1 ms"), "weird abbreviations");
ok(equal("1 picosec", "1 ps"), "tiny abbrevs");
ok(equal("1 Mbps", "1 megabit/second"), "compound units");
ok(equal("8 Mbps", "1 megabyte/second"), "bits and bytes");
ok(equal("1 sec + 1 sec", "2 sec"), "addition");
ok(equal("1 sec - 1 sec", "0 sec"), "subtraction");
ok(equal("1 sec - 1 sec", "0 weeks"), "zero equivalences");
ok(equal("2 sec * 4 sec", "8 sec sec"), "multiplication");
ok(equal("1 sec / 2 sec", "0.5"), "division");
ok(equal("3 sec ** 2", "9 sec sec"), "exponentiation");
ok(equal("4 ** 1.5", "8"), "exponentiation to non-integral power");
ok(equal("2 minutes ** 2", "4 minute minutes"), "non-base exponentiation");
ok(equal("1 Kbps * 1 Kbps", "1 megabit bit / sec / sec"), "complex multiplication");
ok(equal("1 Kbps ** 2", "1 megabit bit / sec / sec"), "complex exponentiation");

ok(calc("1 sec"), "calc() function");
eval { calc("3 ** 2 sec") };
ok($@ =~ /only raise to unit-less/i, "error: power with units");
eval { calc("1 sec + 1 byte"); };
ok($@ =~ /Unable to add incompatible/i, "error: adding incompatible units");
eval { calc("1 sec - 1 byte"); };
ok($@ =~ /Unable to subtract incompatible/i, "error: subtracting incompatible units");
eval { calc("1 sec ** 1.1"); };
ok($@ =~ /to an integral power/i, "error: units ** fractional power");

ok(convert("1 sec", "sec") eq "1 sec", "basic conversion");
ok(convert("1 min", "sec") eq "60 sec", "non-base -> base conversion");
ok(convert("60 sec", "min") eq "1 min", "base -> non-base conversion");
ok(convert("60 minutes", "hour") eq "1 hour", "non-base -> non-base conversion");
ok(convert("1KB/sec", "byte/sec") eq "1024 byte / sec", "complex conversion");
ok(convert("1KB/sec", "Kbps") eq "8 Kbps", "combo conversion");
ok(equal("1byte/Kbps", "(1/(1024/8)) sec"), "complex type on bottom");

# Documentation examples
ok((grep { /./ } readable("10MB / 384Kbps")), "doc example 1");
ok((grep { /./ } readable("8KB / (8KB/(20MB/sec) + 15ms)")), "doc example 2");
ok((grep { /./ } readable("((1sec/20MB) + 15ms/8KB) ** -1")), "doc example 3");
ok(convert("2MB/sec", "GB/week") =~ m!1181 GB / week!, "doc example 4");
$DB::single = 1;
ok((grep { /714 angel/ } readable("42 angels/pinhead * 17 pinheads")), "doc example 5");

exit($STATUS);
