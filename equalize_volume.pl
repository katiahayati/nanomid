use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

use Nanomid qw(adjust_overlapping midi read_midi write_midi);

sub usage {
    print "Usage: $0 [--input|-i <input file>] [--output|o <output file>] <new_volume>";
    exit;
}

my $fn; my $out_fn;
GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h=s" => \&usage,
    );

my $new_volume = shift @ARGV or die usage();

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;

my @tracks_to_keep;
foreach my $track (@tracks) {
    my @events = $track->events;
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "note_on" and $e->[4] != 0) {
	  $e->[4] = $new_volume;
      }
  }
    $track->events(@events);
    push @tracks_to_keep, $track;
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
