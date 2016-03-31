use warnings;
use strict;

use Getopt::Long;
use Nanomid qw(tracks midi read_midi write_midi);

sub usage {
    print "Usage: $0 [--input|-i <input file>] [--output|-o <output file>] 'event1,after_n' [event2,after_n] ...\n";
    exit;
}

my $fn; my $out_fn;
GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h" => \&usage,
    );

my @events_to_remove = @ARGV;

my %bad = map { my ($e, $c) = split /\,/; $e => ($c || 0) } @events_to_remove;
my %counts;

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;
my $ticks = $midi->ticks;


my @clean_events;
foreach my $track (@tracks) {
    my @nt;
    foreach my $e ($track->events) {
	my $name = $e->[0];
	$counts{$name}++;
	if (defined $bad{$name} and $counts{$name} > $bad{$name}) {
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
