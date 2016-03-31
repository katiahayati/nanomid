use warnings;
use strict;
use Data::Dumper;
use MIDI;

my $fn = shift @ARGV or die "Usage: $0 <input file>";
my $obj = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });
print Dumper($obj);

