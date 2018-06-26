use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

use Nanomid qw(adjust_overlapping midi read_midi write_midi);

sub usage {
    print "Usage: $0 <input file>";
    exit;
}

my $fn; my $out_fn;
GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h=s" => \&usage,
    );

my %names = map { my ($old, $new) = split /\|/; $old => $new } @ARGV;

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;

my @tracks_to_keep;
my $track_num = 0;
TRACK: foreach my $track (@tracks) {
    my @events = $track->events;
  EVENTS: for my $e (@events) {
      my $track_name;
      if ($e->[0] eq "track_name") {
	  $track_name = $e->[2];
	  print join "\t", $track_num, $track_name; print "\n";
	  $track_num++;
	  next TRACK;
      }
  }
    print join "\t", $track_num, "No name\n";
    $track_num++;
}

