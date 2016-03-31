use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(adjust_overlapping midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new name> [track2|new name] ...";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new name> [track2|new name] ...";

my %names = map { my ($old, $new) = split /\|/; $old => $new } @ARGV;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;

my @tracks_to_keep;
foreach my $track (@tracks) {
    my @events = $track->events;
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "track_name") {
	  my $track_name = $e->[2];
	  if (defined ($names{$track_name})) {
	      $e->[2] = $names{$track_name};
	  }
	  $track->events(@events);
	  last EVENTS;
      }
  }
    push @tracks_to_keep, $track;
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
