use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(adjust_overlapping midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new volume> [track2|new volume] ...";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new volume> [track2|new volume] ...";

my %volumes = map { my ($name, $vol) = split /\|/; $name => $vol } @ARGV;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;

my @tracks_to_keep;
foreach my $track (@tracks) {
    my @events = $track->events;
    my $new_vol;
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "track_name") {
	  my $track_name = $e->[2];
	  if (defined ($volumes{$track_name})) {
	      $new_vol = $volumes{$track_name};
	  } else {
	      last EVENTS;
	  }
      }
      if ($e->[0] eq "note_on" and $e->[4] != 0) {
	  $e->[4] = $new_vol;
      }
  }
    $track->events(@events);
    push @tracks_to_keep, $track;
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
