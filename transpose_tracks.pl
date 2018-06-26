use warnings;
use strict;
use Data::Dumper;
use Getopt::Long;

use Nanomid qw(adjust_overlapping midi read_midi write_midi);

my $num_notes_in_octave = 12;

sub usage {
    print "Usage: $0 <input file> <output file> <track 1|up or down> [track2|up or down] ...";
    exit;
}

my $fn; my $out_fn;
GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h=s" => \&usage,
    );

my %names = map { my ($old, $new) = split /\|/; $old => $new } @ARGV;

for my $key (keys %names) {
    if ($names{$key} eq "up") {
	$names{$key} = $num_notes_in_octave;
    } else {
	$names{$key} = -$num_notes_in_octave;
    }
}

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;

my $track_num = -1;
my @tracks_to_keep;
foreach my $track (@tracks) {
    $track_num++;
    my @events = $track->events;
    # assume any note events are after a track name event
    # not a good assumption
    my $change;
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "track_name") {
	  my $track_name = $e->[2];
	  if (defined ($names{$track_name}) or defined ($names{$track_num})) {
	      if (defined $names{$track_name}) {
		  $change = $names{$track_name};
	      } else {
		  $change = $names{$track_num};
	      }
	  }
      }
      if ($e->[0] eq "note_on" or $e->[0] eq "note_off") {
	  if (defined $change) {
	      $e->[3] += $change;
	  }
      }
  }
    $track->events(@events);
    push @tracks_to_keep, $track;
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
