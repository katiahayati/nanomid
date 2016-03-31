use warnings;
use strict;

use Getopt::Long;
use Nanomid qw(tracks midi read_midi write_midi);

my $fn;
my $out_fn;

sub usage {
    print "Usage: $0 [--input|-i input_file] [--output -o output_file]\n";
    exit;
}

GetOptions(
    "input|i=s" => \$fn,
    "output|o=s" => \$out_fn
);

my $midi = read_midi($fn);

print STDERR $0, "\n";

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
