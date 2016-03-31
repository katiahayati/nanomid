use warnings;
use strict;
use Data::Dumper;
use Nanomid qw(read_midi);
use Getopt::Long;
use MIDI;

sub usage {
    print "Usage: $0 [--input|-i input_file]\n";
    exit;
}

my $fn;
GetOptions("input|i=s" => \$fn,
	   "help|h" => \&usage,
    );

my $obj = read_midi($fn);

print STDERR $0, "\n";

print Dumper($obj);

