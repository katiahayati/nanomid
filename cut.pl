use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Nanomid qw(make_abs_time make_delta_time midi write_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $usage = "Usage: $0 <input file> <output file> <from_measure> [to_measure]";

my $fn = shift @ARGV or die $usage;
my $out_fn = shift @ARGV or die $usage;
my $from_measure = shift @ARGV or die $usage;
my $to_measure = shift @ARGV;

die $usage if ($from_measure < 1);

my $midi = MIDI::Opus->new({ 'from_file' => $fn, 'no_parse' => 0 });
my $ticks_per_quarter = $midi->ticks;

my @tracks = $midi->tracks;

my @time_signature_events;
my $max_time;
foreach my $track (@tracks) {
    my @events = $track->events;
    my @abs_events = make_abs_time(@events);
    foreach my $e (@abs_events) {
	if ($e->[0] eq "time_signature") {
	    push @time_signature_events, $e;
	} elsif ($e->[0] eq "note_off") {
	    if (not defined $max_time or $e->[1] > $max_time) {
		$max_time = $e->[1];
	    }
	}
    }
}

if (not @time_signature_events) {
    # assume 4/4 at time 0
    push @time_signature_events, [ 'time_signature', 0, 4, 2, 36, 8 ];
}

# sort by absolute time
@time_signature_events = sort { $a->[1] <=> $b->[1] } @time_signature_events;
my @time_signature_times = map { $_->[1] } @time_signature_events;
push @time_signature_times, $max_time;

# now there are at least 2 time signatures in the array


print STDERR Dumper(@time_signature_events);
print STDERR $ticks_per_quarter, "\n";

my @measure_ticks;
my $start = 0; my $end = 1;
while ($start < @time_signature_times and $end < @time_signature_times) {
    my $start_time = $time_signature_times[$start];
    my $end_time = $time_signature_times[$end];
    
    my $current_time_sig = $time_signature_events[$start];
    my $num = $current_time_sig->[2];
    my $denom = $current_time_sig->[3];

    my $quarters_per_measure = 4 / (2**($denom)) * $num;
    my $current_ticks_per_measure = int($quarters_per_measure * 
	$ticks_per_quarter);
#    print STDERR join " ", ($start_time, $end_time, $num, $denom, $quarters_per_measure, $current_ticks_per_measure, "\n");
    
    for (my $t = $start_time; $t < $end_time; $t++) {
	if (($t-$start_time) % $current_ticks_per_measure == 0) {
	    push @measure_ticks, $t;
	}
    }

    $start++;
    $end++;
}
#print STDERR Dumper(\@measure_ticks);

my $desired_start_time = $measure_ticks[$from_measure - 1];
# we want to end at the start time of the next measure so we get the full last measure
my $desired_end_time = (defined $to_measure and $to_measure < @measure_ticks) ? $measure_ticks[$to_measure - 1 + 1] : $max_time + 1; 
print STDERR join " ", ($from_measure, $to_measure, $desired_start_time, $desired_end_time, $measure_ticks[$to_measure-1], "\n");

my @new_tracks;
foreach my $track (@tracks) {
    my @events = make_abs_time($track->events);
    @events = map { $_->[1] = $_->[1] - $desired_start_time; $_ } grep { $_->[1] >= $desired_start_time and $_->[1] < $desired_end_time } @events;
    print STDERR Dumper(\@events);
    my @new_events = make_delta_time(@events);
    my $track = MIDI::Track->new({ events => \@new_events });
    push @new_tracks, $track;
}
    
my $out_midi = midi(\@new_tracks, $midi->ticks);
write_midi($out_midi, $out_fn);
