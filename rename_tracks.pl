use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

use Nanomid qw(adjust_overlapping midi read_midi write_midi);

sub usage {
    print "Usage: $0 <input file> <output file> <track 1|new name> [track2|new name] ...";
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

my $track_num = -1;
my @tracks_to_keep;
foreach my $track (@tracks) {
    $track_num++;
    my @events = $track->events; 
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "track_name") {
	  my $track_name = $e->[2];
	  if (defined ($names{$track_name}) or defined ($names{$track_num})) {
	      my $new_name = (defined $names{$track_name}) ? $names{$track_name} : $names{$track_num};
		  $e->[2] = $new_name;
	  }
	  
	  $track->events(@events);
	  last EVENTS;
      }
  }
    push @tracks_to_keep, $track;
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
