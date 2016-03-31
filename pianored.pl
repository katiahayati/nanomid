use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(adjust_overlapping midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file> <tracks to not reduce>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file> <tracks to not reduce>";
my %except = map { $_ => 1 } @ARGV;

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });

my @tracks = $midi->tracks;

my @new_events;
push @new_events, (
    [ 'track_name', 0, 'Piano reduction' ],
    [ 'patch_change', 0, 1, 0 ], #piano
    );

my @tracks_to_keep;
my $track_num = -1;
foreach my $track (@tracks) {
    $track_num++;
    my @events = $track->events;
    my $track_name;
    for my $e (@events) {
	if ($e->[0] eq "track_name") {
	    $track_name = $e->[2];
	    last;
	}
    }
    if (not $track_name or defined $except{$track_name} or defined $except{$track_num}) {
	print STDERR "keeping $track_name\n";
	push @tracks_to_keep, $track;
    } else {
	print STDERR "Reducing $track_name\n";
	my $t = 0;
	for my $e (@events) {
	    $t += $e->[1];
	    $e->[1] = $t;
	    $e->[2] = 1; #channel
	    if (($e->[0] eq "note_on") and ($e->[-1] == 0)) {
		$e->[0] = "note_off";
		$e->[-1] = 127;
		print STDERR "Added a note off\n";
	    }
	}
	push @new_events, grep { not defined $EVENTS_TO_DROP{$_->[0]} } @events;
    }
    
}

my @sorted_events = sort { $a->[1] <=> $b->[1] || $a->[0] cmp $b->[0] } @new_events;
print STDERR Dumper(\@sorted_events);

my @non_overlapping_events = adjust_overlapping(\@sorted_events, { need_abs => 0, sort => 0 });


my $piano_track = MIDI::Track->new({ events => \@non_overlapping_events });
push @tracks_to_keep, $piano_track;

my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
