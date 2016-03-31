use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(adjust_overlapping midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new instrument> [track2|new instrument] ...";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file> <track 1|new instrument> [track2|new instrument] ...";

my %instruments = map { my ($name, $inst) = split /\|/; $name => $inst } @ARGV;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;

my @tracks_to_keep;
TRACK: foreach my $track (@tracks) {
    my @events = $track->events;
    my $new_inst;
    if (! grep { $_->[0] eq "track_name" } @events) {
	push @tracks_to_keep, $track;
	next TRACK;
    }
    # need to loop through all events twice if this is a track to change, because
    # the patch_change can occur before the track_name
  EVENTS: for my $e (@events) {
      if ($e->[0] eq "track_name") {
	  my $track_name = $e->[2];
	  if (not defined ($instruments{$track_name})) {
	      push @tracks_to_keep, $track;
	      next TRACK;
	  } else {
	      $new_inst = $instruments{$track_name};
	  }
      }
  }
    if (defined $new_inst) {
	for my $e (@events) {
	    if ($e->[0] eq "patch_change") {
		print STDERR "Making the change\n";
		$e->[3] = $new_inst;
		$track->events(@events);
		push @tracks_to_keep, $track;
		next TRACK;
	    }
	}
    }
}


my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
