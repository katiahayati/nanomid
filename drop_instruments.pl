use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Getopt::Long;
use Nanomid qw(adjust_overlapping midi write_midi read_midi);

my $fn;
my $out_fn;
my $usage = "Usage: $0 [--input|-i <input file>] [--output|-o <output file>] <track to drop> [track to drop] ...";

GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h" => sub { die $usage },
    );

my %tracks_to_drop = map { $_ => 1 } @ARGV;

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;

my @tracks_to_keep;
my $track_num = -1;
 TRACK: foreach my $track (@tracks) {
    $track_num++;
    my @events = $track->events;

     if (defined $tracks_to_drop{$track_num}) {
		next TRACK; # drop
     }

     EVENTS: for my $e (@events) {
	   if ($e->[0] eq "track_name") {
	       my $track_name = $e->[2];
	       if (defined ($tracks_to_drop{$track_name})) {
				next TRACK; # drop
			}
			last EVENTS; # presumably there's only one track name event per track
		}
	}
	# if we got here we should keep this track
	push @tracks_to_keep, $track;
	next TRACK;

	 
}



my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
