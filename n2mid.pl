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

# divisible by 2, 3, 4, 6, 8, 12, 16, 32, 64
my $quarter_ticks = 192;

my $key = $obj->{header_data}->{key};
my @instruments = (defined $obj->{header_data}->{instruments}) ?
    split " ", $obj->{header_data}->{instruments} : ();
my @default_octaves = (defined $obj->{header_data}->{default_octaves}) ?
    split " ", $obj->{header_data}->{default_octaves} : ();
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

    my $delay = 0;
    my $current_time = 0;

    # for each chord, for each note in the chord, we have to place a note at
    # the right time offset in the MIDI stream.
    # for each part, we're going to create one MIDI track per notes in a chord
    # so if the largest chord has 4 notes in it, there will be 4 tracks
    # if 3 notes, 3 tracks
    # if this is just a vocal line, this reduces to 1 track for 1 channel
    foreach my $chord_obj (@{$data_track->{notes}}) {
        my $chord_start_time = $current_time;
        my $num_parts = scalar @{$chord_obj->{chord}};
        my @order;
        # for ease of reading an imported MIDI file in another program, try to keep
        # the top note on the top track, the middle note in the middle track, and
        # the bottom note on the bottom track
        if ($num_parts >= 1) {
            push @order, 0;
        }
        if ($num_parts >= 2) {
            push @order, -1;
        }
        if ($num_parts >= 3) {
            push @order, 1..$num_parts-1-1;
        }

        # @all_events is an array of array
        # each inner array is a set of events corresponding to a track
        # counter keeps track of which track we're adding notes to
        my $counter = 0;
        # go through the notes in the chord in the order specified
        foreach my $which_chord (@order) {
            $current_time = $chord_start_time;
            # are we starting a new track?
            if (scalar @all_events < $counter + 1) {
                @{$all_events[$counter]} = (
                    [ 'set_tempo', 0, $tempo ],
                    [ 'track_name', 0, $track_name ],
                    [ 'patch_change', 0, $channel, $instrument ],  # same channel as we are currently on
                    );
                # at the beginning of a track we are at time 0
                $event_current_time[$counter] = 0;
            }
            # grab the list of events for this track
            my $events = $all_events[$counter];
            # what time are we at on this track
            # the problem is: what if for 3 bars we just have single notes
            # then after 3 bars there's a chord with 2 notes
            # that bottom note needs to happen after a delay of 3 bars
            # but when we go add to the top track, that delay should just be 0
            # so we need to keep track of the overall current time, as well as
            # the current time on this track
            $delay = $current_time - $event_current_time[$counter];

            # ok, now we actually get to add some notes
            my $chord_part = $chord_obj->{chord}->[$which_chord];

            my $debug = (@{$chord_part} >= 2);
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

                    # a rest is encoded as a gap between the end time of the
                    # previous note and the start time of this note
                    # that's $delay, and it's incremented only when the previous note
                    # is a rest
                    push @$events, [ 'note_on', $delay, $channel, $number, 127 ];
                    push @$events, [ 'note_off', $mult*$quarter_ticks, $channel,
                                     $number, 127 ];
                    $current_time += $mult*$quarter_ticks;
                    $event_current_time[$counter] = $current_time;
                } else {
                    # this is a rest
                    # update current time but not event current time
                    # so the delay will be the length of this rest
                    $current_time += $mult*$quarter_ticks;
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
# heh, well, that's all there is in Die Walkure, pretty much!  anyway, MIDI
# doesn't really care about time signatures, this is mostly for esthetics if you
# import the file in a music editor.
# TODO: do this mathematically
if ($time_sig eq "3 4") {
    $time_event = [ 'time_signature', 0, 3, 2, 8, 8];
} elsif ($time_sig eq "9 8") {
    $time_event = [ 'time_signature', 0, 9, 3, 18, 8];
}
my $dummy_track = MIDI::Track->new( { events => [ 
                      [ 'track_name', 0, 'title' ],
                      $time_event ]});
unshift @tracks, $dummy_track;

# format 1 MIDI file (multiple tracks)
my $opus = MIDI::Opus->new({
    format => 1,
ticks => $quarter_ticks});
$opus->tracks(@tracks );
$opus->write_to_file($out_fn);


##################

