use warnings;
use strict;
use Data::Dumper;

use Getopt::Long;
use Nanomid qw(make_abs_time make_delta_time midi read_midi write_midi);


sub usage {
    print "Usage: $0 [--input|-i <input file>] [--output|-o <output file>]\n";
    exit;
}

my $fn; my $out_fn;
GetOptions("input|i=s" => \$fn,
    "output|o=s" => \$out_fn,
	   "help|h" => \&usage,
    );


my $midi = read_midi($fn);

# tempo_str =    60 / $bpm * 1_000_000
# tempo_str / 1_000_000 = 60 / bpm
# 1_000_000 / tempo_str = bpm / 60
# bpm = 60 * 1_000_000 / tempo_str

# quarter per second = 1_000_000 / tempo_str
# tick per second = quarter per second * tick per quarter

my $ticks_per_quarter = $midi->ticks;
print STDERR $ticks_per_quarter, "\n";

my @tracks = $midi->tracks;

my @all_events;

foreach my $track (@tracks) {
    my @events = $track->events;
    my @abs_events = make_abs_time(@events);
    push @all_events, @abs_events;
}

@all_events = sort { $a->[1] <=> $b->[1] } @all_events;

my @all_delta_events = make_delta_time(@all_events);


my $current_ticks_per_second = 1;
my $current_abs_time = 0;
    
my @cue_times;
#print STDERR Dumper(\@all_delta_events);
foreach my $e (@all_delta_events) {
    $current_abs_time += $e->[1] / $current_ticks_per_second;
    if ($e->[0] eq "set_tempo") {
        my $tempo_str = $e->[2];
        my $qps = 1_000_000 / $tempo_str;
        $current_ticks_per_second = $ticks_per_quarter * $qps;
        print STDERR "TICKS: ", $current_ticks_per_second, "\n";

    } elsif ($e->[0] eq "lyric") {
        push @cue_times, $current_abs_time;
    }
}

open OUT, ">$out_fn";
binmode(OUT, ":utf8");
print OUT join "\n", @cue_times;
close OUT;
