use warnings;
use strict;

use Nanomid qw(process_file);


my $fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file>";

process_file($fn, $out_fn);
