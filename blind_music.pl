use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(adjust_overlapping midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file> <tracks to blind>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file> <tracks to blind>";

my %blind = map { $_ => 1 } @ARGV;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;

my @new_events;

my @tracks_to_keep;
foreach my $track (@tracks) {
    my @events = $track->events;
    my $track_name;
    for my $e (@events) {
	if ($e->[0] eq "track_name") {
	    $track_name = $e->[2];
	    last;
	}
    }
    if (not $track_name or not defined $blind{$track_name}) {
	print STDERR "keeping $track_name\n";
	push @tracks_to_keep, $track;
    } else {
	print STDERR "Blinding $track_name\n";
	for (my $i = 0; $i < @events; $i++) {
	    my $e = \$events[$i];
	    if (($$e->[0] eq "note_on") or ($$e->[0] eq "note_off")) {
		$$e->[3] = 71; #turn the note into a B4
	    }
	}
	push @tracks_to_keep, $track;
    }
    
}

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
