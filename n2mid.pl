use warnings;
use strict;
use SM;
use Data::Dumper;
use Note;
use MIDI;

# or could use MATH
my %duration_to_mult = (
    5 => 1,
    "5." => 1.5,
    4 => 0.5,
    "4." => 0.75,
    3 => 0.25,
    "3." => 0.25 + 0.125,
    2 => 0.125,
    "2." => 0.125*1.5,
    1 => 0.0625,
    6 => 2,
    "6." => 3,
    7 => 4,
    "7." => 6,

    # triplet
    33 => 1/3,
    66 => 1/6,
    );

sub calculate_key {
    my ($key_str, $time) = @_;

    my $midi_key;
    my $major_or_minor = 0; # major
    if ($key_str) {
	my ($num, $sharp_or_flat) = split "", $key_str;
	if ($sharp_or_flat eq "b") {
	    $num = -$num;
	}
	$midi_key = $num;
    } else {
	$midi_key = 0;
    }
    my $event = [ 'key_signature', $time, $midi_key, $major_or_minor ];
    return $event;
}

sub calculate_tempo {
    my ($tempo_str) = @_;
    my ($which_note, $bpm) = split "=", $tempo_str;
    return 60 / $bpm * 1_000_000  * (1 / $duration_to_mult{$which_note});
}

sub calculate_time_sig {
    my ($time_sig, $time) = @_;
    my $separator = ($time_sig =~ /%/) ? "%" : " ";
    my ($numerator, $denominator) = split $separator, $time_sig;
    # 1 MIDI quarter = 24 clocks
    # 0 numerator log_2(denominator) mult{denominator}* 8
    my $time_event = [ 'time_signature', $time, $numerator,
		       int(log($denominator)/log(2)),
		       36, # not sure this one matters
		       8 ];
    return $time_event;
}

my $fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $out_fn = shift @ARGV or die "Usage: $0 <input file> <output file>";
my $obj = SM->new($fn);

# divisible by 2, 3, 4, 6, 8, 12, 16, 32, 64
my $quarter_ticks = 192;

my $header_key = $obj->{header_data}->{key};
my $key_event = calculate_key($header_key, 0);

my @instruments = (defined $obj->{header_data}->{instruments}) ?
    split " ", $obj->{header_data}->{instruments} : ();
my @default_octaves = (defined $obj->{header_data}->{default_octaves}) ?
    split " ", $obj->{header_data}->{default_octaves} : ();
my $tempo = 500_000; # quarter = 120
if ($obj->{header_data}->{tempo}) {
    # 5=120
    # 6.=32
    $tempo = calculate_tempo($obj->{header_data}->{tempo});
}

my $time_sig = $obj->{header_data}->{time};
my $time_event = calculate_time_sig($time_sig, 0);

my @tracks;
my @control_events;

push @control_events,
    [ 'track_name', 0, 'title' ],
    $time_event,
    $key_event,
    [ 'set_tempo', 0, $tempo ];

my $channel = 0;

my $previous_track_name;

my %time_to_keys;
$time_to_keys{0} = $header_key;

foreach my $data_track (@{$obj->{tracks}}) {
    my $instrument = (@instruments) ? shift @instruments : 68; # 68 = oboe
    my $default_octave = (@default_octaves) ? shift @default_octaves : 4;
    my $track_name = $data_track->{name};

    # keep all tracks that are called the same thing on the same channel
    # so if you have 2 piano tracks they will be on 1 MIDI channel
    if (!$previous_track_name or $track_name ne $previous_track_name) {
        $channel++;
    }
    $channel = 11 if ($channel == 9); # skip the cowbell channels
    my @all_events;
    my @event_current_time;

    my $current_time = 0;
    my $previous_chord_end_time = 0;

    push @all_events,  (
        [ 'track_name', 0, $track_name ],
        [ 'patch_change', 0, $channel, $instrument ], 
    );

    my $key = $header_key;
    
    # within each chord, calculate absolute time for each note,
    # and then convert to delta times at the end
    CHORD: foreach my $chord_obj (@{$data_track->{notes}}) {
	if (defined $time_to_keys{$current_time}) {
	    $key = $time_to_keys{$current_time};
	}
    
        if (defined $chord_obj->{control}) {
            my $data = $chord_obj->{control};
	    if ($data->{type} eq "*") {
		push @control_events, ( [ "text_event", $current_time, "cue" ] );
		next CHORD;
	    }
            if ($data->{type} eq "CHANGE_TEMPO" ) {
                my $new_tempo = calculate_tempo($data->{spec});
                push @control_events, ( [ "set_tempo", $current_time, $new_tempo ] );
                next CHORD;
	    } elsif ($data->{type} eq "CHANGE_KEY") {
		$key = $data->{spec};
		$time_to_keys{$current_time} = $key;
		my $new_key_event = calculate_key($data->{spec}, $current_time);
		push @control_events, $new_key_event;
		next CHORD;
	    } elsif ($data->{type} eq "CHANGE_TIMESIG") {
		my $new_timesig = calculate_time_sig($data->{spec}, $current_time);
		push @control_events, $new_timesig;
		next CHORD;
            } else {
                die "Unknown control type " . $data->{type};
            }
        }

        my @chord_events;
        my $chord_start_time = $current_time;
        my $chord_end_time;

        foreach my $chord_part (@{$chord_obj->{chord}}) {
            my $chord_current_time = $chord_start_time;

            foreach my $note_obj (@{$chord_part}) {
                my $duration = $note_obj->{duration};
                my $value = $note_obj->{note};

                my $mult = 0;
                # ties
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
                    my $number = get_note_number($value, $default_octave);
            
                    if (not defined $number) {
                        $number = 0;
                        print STDERR $note_obj->{value}, "\t", $value, "\n";
                    }

                    # absolute time
                    push @chord_events, 
                    [ 'note_on', 
                      $chord_current_time, 
                      $channel, $number, 127 ];
                    push @chord_events, 
                    [ 'note_off', 
                      $chord_current_time + $mult*$quarter_ticks, $channel,
                      $number, 127 ];
                    $chord_current_time += $mult*$quarter_ticks;
                } else {
                    # this is a rest
                    $chord_current_time += $mult*$quarter_ticks;
                }
            }
            # check that all chord parts have the same duration
            if (defined $chord_end_time and ($chord_current_time !=
                                             $chord_end_time)) {
                die "Unequal chord parts " . Dumper($chord_obj);
            }
            $chord_end_time = $chord_current_time;
        }
        # sort all note on and off events by time, and put off before on
        my @sorted_chord_events = sort { $a->[1] <=> $b->[1] 
                                             || # off before on
                                         $a->[0] cmp $b->[0]

        } @chord_events;
        my $previous_time = $previous_chord_end_time;
        my @actual_events;
        # compute delta times
        for (my $i = 0; $i < @sorted_chord_events; $i++) {
            my $event = $sorted_chord_events[$i];
            my $delta_time = $event->[1] - $previous_time;
            $previous_time = $event->[1];
            $event->[1] = $delta_time;
            push @actual_events, $event;
        }
        push @all_events, @actual_events;
        
        $current_time = $chord_end_time;
        # if the chord is a rest (single note which is a rest) then we need to
        # keep $previous_chord_end_time as is to encode the delay at the start
        # of the next chord
        if (@chord_events) {
            $previous_chord_end_time = $chord_end_time;
        }

    }
    my $track = MIDI::Track->new({ events => \@all_events });
    push @tracks, $track;
}

# compute delta times for control events;
my $previous_control_time = 0;
my @sorted_control_events = sort { $a->[1] <=> $b->[1] } @control_events;
my @delta_control_events;
foreach my $e (@sorted_control_events) {
    my $t = $e->[1];
    my $dt = $t - $previous_control_time;
    $e->[1] = $dt;
    push @delta_control_events, $e;
    $previous_control_time = $t;
}

my $control_track = MIDI::Track->new( { events => \@delta_control_events } );
unshift @tracks, $control_track;

# format 1 MIDI file (multiple tracks)
my $opus = MIDI::Opus->new({
    format => 1,
ticks => $quarter_ticks});
$opus->tracks(@tracks );
$opus->write_to_file($out_fn);


##################

