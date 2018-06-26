use warnings;
use strict;
use Data::Dumper;
use MIDI;
use Getopt::Long;
use Nanomid qw(adjust_overlapping midi write_midi read_midi);

my %EVENTS_TO_DROP = (
    patch_change => 1,
    track_name => 1,
    );

my $fn;
my $out_fn;
my $usage = "Usage: $0 [--input|-i <input file>] [--output|-o <output file>] <track 1|new instrument> [track2|new instrument] ...";

GetOptions("input|i=s" => \$fn,
	   "output|o=s" => \$out_fn,
	   "help|h" => sub { die $usage },
    );

my %instruments = map { my ($name, $inst) = split /\|/; $name => $inst } @ARGV;

my $midi = read_midi($fn);

print STDERR $0, "\n";

my @tracks = $midi->tracks;

my @tracks_to_keep;
my $track_num = -1;
 TRACK: foreach my $track (@tracks) {
     $track_num++;
    my @events = $track->events;
    my $new_inst;

     if (defined $instruments{$track_num}) {
	 $new_inst = $instruments{$track_num};
     }
    # need to loop through all events twice if this is a track to change, because
    # the patch_change can occur before the track_name
     if (not defined $new_inst) {
       EVENTS: for my $e (@events) {
	   if ($e->[0] eq "track_name") {
	       my $track_name = $e->[2];
	       if (not defined ($instruments{$track_name})) {
		   push @tracks_to_keep, $track;
		   next TRACK;
	       } else {
		   $new_inst = $instruments{$track_name};
	       }
	   }
       }
     }
     if (defined $new_inst) {
	 CHANGE_LOOP: for my $e (@events) {
	     if ($e->[0] eq "patch_change") {
		 print STDERR "Making the change\n";
		 $e->[3] = $new_inst;
		 last CHANGE_LOOP;
	     }
	 }
     }
     $track->events(@events);
     push @tracks_to_keep, $track;
     next TRACK;

	 
}



my $out_midi = midi(\@tracks_to_keep, $midi->ticks);
write_midi($out_midi, $out_fn);
