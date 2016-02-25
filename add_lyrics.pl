use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(make_abs_time make_delta_time midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $usage = "Usage: $0 <input file> <output file> <track name> <lyrics file name>";

my $fn = shift @ARGV or die $usage;
my $out_fn = shift @ARGV or die $usage;
my $track_name = shift @ARGV or die $usage;
my $lyrics_fn = shift @ARGV or die $usage;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @lyrics;
open IN, "$lyrics_fn" or die $!;
while (<IN>) {
    chomp;
    my @syllables = split /\s+/;
    push @lyrics, @syllables;
}
close IN;

my @tracks = $midi->tracks;

my @new_tracks;
foreach my $track (@tracks) {
    my @events = $track->events;
    my $current_track_name;
    for my $e (@events) {
	if ($e->[0] eq "track_name") {
	    $current_track_name = $e->[2];
	    last;
	}
    }
    if (not $current_track_name or $current_track_name ne $track_name) {
	print STDERR "keeping $current_track_name\n";
	push @new_tracks, $track;
	next;
    } else {
	print STDERR "Adding lyrics based on $track_name\n";
	my @new_events;
	for my $e (@events) {
	    push @new_events, $e;
	    if ($e->[0] eq "note_on") {
		my $lyric_event = [ 'lyric', 0, shift @lyrics ];
		push @new_events, $lyric_event;
	    }
	}
	my $new_track = MIDI::Track->new({ events => \@new_events });
	push @new_tracks, $new_track;
    }
}

my $out_midi = midi(\@new_tracks, $midi->ticks);
write_midi($out_midi, $out_fn);
