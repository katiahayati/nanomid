use warnings;
use strict;

use Nanomid qw(tracks midi write_midi);


my $fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my @events_to_remove = @ARGV;


my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;
my $ticks = $midi->ticks;


my @clean_events;
foreach my $track (@tracks) {
    my @nt;
    foreach my $e ($track->events) {
	my $name = $e->[0];
	if ($name eq "control_change" and $e->[3] == 7) {
	    print STDERR "found one\n";
	    # skip
	} else {
	    push @nt, $e;
	}
    }
    push @clean_events, \@nt;
}

my $midi_tracks = tracks(\@clean_events);
my $new_midi = midi($midi_tracks, $ticks);
write_midi($new_midi, $out_fn);
