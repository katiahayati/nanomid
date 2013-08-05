use warnings;
use strict;
use SM;
use Data::Dumper;
use Note;
use MIDI;

# or could use MATH
# what about double dotting
# what about triplets
my %duration_to_mult = (
    5 => 1,
    "5." => 1.5,
    4 => 0.5,
    "4." => 0.75,
    3 => 0.25,
    "3." => 0.25 + 0.125,
    2 => 0.125,
    "2." => 0.125*1.5,
    6 => 2,
    "6." => 3,
    7 => 4,
    "7." => 6,

    # triplet
    33 => 1/3,
    66 => 1/6,
    );


my $fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $obj = SM->new($fn);

# FIXME: what is this number and what should it be?
my $quarter_ticks = 96;

my $key = $obj->{header_data}->{key};
my @instruments = (defined $obj->{header_data}->{instruments}) ?
    split " ", $obj->{header_data}->{instruments} : ();
my $tempo = 500_000; # quarter = 120
if ($obj->{header_data}->{tempo}) {
    # 5=120
    # 6.=32
    my ($which_note, $bpm) = split "=", $obj->{header_data}->{tempo};
    $tempo = 60 / $bpm * 1_000_000  * $duration_to_mult{$which_note};
}

my @tracks;

my $channel = 0;

my $previous_track_name;
foreach my $data_track (@{$obj->{tracks}}) {
    my $instrument = (@instruments) ? shift @instruments : 68;
    my $track_name = $data_track->{name};
    if (!$previous_track_name or $track_name ne $previous_track_name) {
	$channel++;
    }
    $channel = 11 if ($channel == 9); # skip the cowbell channels
    my @all_events;
    my @event_current_time;

    my $delay = 0;
    my $current_time = 0;

    foreach my $chord_obj (@{$data_track->{notes}}) {
	my $chord_start_time = $current_time;
	my $num_parts = scalar @{$chord_obj->{chord}};
	my @order;
	if ($num_parts >= 1) {
	    push @order, 0;
	}
	if ($num_parts >= 2) {
	    push @order, -1;
	}
	if ($num_parts >= 3) {
	    push @order, 1..$num_parts-1-1;
	}

	my $counter = 0;
	foreach my $which_chord (@order) {
	    $current_time = $chord_start_time;
	    if (scalar @all_events < $counter + 1) {
		@{$all_events[$counter]} = (
		    [ 'set_tempo', 0, $tempo ],  # 5 => 0.45 s
		    [ 'track_name', 0, $track_name ],
		    [ 'patch_change', 0, $channel, $instrument ],  # same channel as we are currently on
		    );  # 5 = 0.45 seconds
		$event_current_time[$counter] = 0;
	    }
	    my $events = $all_events[$counter];
	    $delay = $current_time - $event_current_time[$counter];

	    my $chord_part = $chord_obj->{chord}->[$which_chord];

	    my $debug = (@{$chord_part} >= 2);
	    foreach my $note_obj (@{$chord_part}) {
	       
		my $duration = $note_obj->{duration};
		my $value = $note_obj->{note};

		my $mult = 0;
		my @duration_parts = split /\+/, $duration;
		foreach (@duration_parts) {
		    if (!exists $duration_to_mult{$_}) {
			print STDERR "unknown duration $_\n";
		    }
		    $mult += $duration_to_mult{$_};
		}
		if (! defined $mult) {
		    print STDERR $duration, "\n";
		}
		# what about double flats, double sharps (prob not in score)
		if ($value ne "r") {
		    $value = get_note_in_key($value, $key);
		    my $number = get_note_number($value);
		    
		    if (not defined $number) {
			$number = 0;
			print STDERR $note_obj->{value}, "\t", $value, "\n";
		    }

		    push @$events, [ 'note_on', $delay, $channel, $number, 127 ];
		    push @$events, [ 'note_off', $mult*$quarter_ticks, $channel,
				     $number, 127 ];
		    $current_time += $mult*$quarter_ticks;
		    $event_current_time[$counter] = $current_time;
		    $delay = 0;
		} else {
		    $current_time += $mult*$quarter_ticks;
		    $delay = $mult*$quarter_ticks;
		}
	    }
	    $counter++;
	}
    }
    foreach my $event_track (@all_events) {
	my $track = MIDI::Track->new({ events => $event_track });
	push @tracks, $track;
    }
}


my $time_sig = $obj->{header_data}->{time};
my $time_event;
if ($time_sig eq "3 4") {
    $time_event = [ 'time_signature', 0, 3, 2, 8, 8];
} elsif ($time_sig eq "9 8") {
    $time_event = [ 'time_signature', 0, 9, 3, 18, 8];
}
my $dummy_track = MIDI::Track->new( { events => [ 
					  [ 'track_name', 0, 'title' ],
					  $time_event ]});
unshift @tracks, $dummy_track;
# for (1..2) {
#     my @events;
#     push @events, [ 'track_name', 0, "track " . $_ ];
# # dtime channel note velocity
#     push @events, [ 'note_on', 0, 10, $MIDI::note2number{"E5"} + $_, 127 ];
#     push @events, [ 'note_off', 96, 10, $MIDI::note2number{"E5"} + $_, 127 ];

# #     push @events, [ 'note_on', 0, 10, 70* $_, 127 ];
# #     push @events, [ 'note_off', 96, 10, 70 * $_, 127 ];

# # # push @events, [ 'note_on', 0, 10, 56, 127 ];
# # # push @events, [ 'note_off', 96, 10, 56, 127 ];

# #     push @events, [ 'note_on', 96, 10, 70 * $_, 127 ];
# #     push @events, [ 'note_off', 96, 10, 70 * $_, 127 ];

# #     push @events, [ 'note_on', 0, 10, 56 * $_, 127 ];
# #     push @events, [ 'note_off', 96, 10, 56 * $_, 127 ];

# #push @events, [ 'note_on', 90, 9, 56, 127 ];
# #push @events, [ 'note_off', 6, 9, 56, 127 ];

#     my $track = MIDI::Track->new({ events => \@events });
#     push @tracks, $track;
# }


my $opus = MIDI::Opus->new({
    format => 1,
ticks => 96});
$opus->tracks(@tracks );
$opus->write_to_file($out_fn);


##################

