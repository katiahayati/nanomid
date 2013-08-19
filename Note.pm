use warnings;
use strict;
use Data::Dumper;
use MIDI;

our @EXPORT = qw(all);

my %mods = (
 "#" => [ qw(F C G A D E) ],
 "b" => [ qw(B E A D G C) ],
);

sub get_modified_notes {
    my ($key) = @_;
    
    # c major
    if (! $key) {
	return {};
    }

    my ($num, $which) = split "", $key;
    my $which_list = $mods{$which};
    my %modded;
    for (my $i = 0; $i < $num; $i++) {
	$modded{$which_list->[$i]} = 1;
    }
    return \%modded;
}

sub get_note_in_key {
    my ($value, $key) = @_;
    
    my $note; my $modifier; my $octave;
    if ($value =~ /([a-zA-Z])([\#bN]?)(\d?)/) {
	$note = $1;
	$modifier = $2;
	$octave = $3;
    } else {
	warn "Invalid note: $value";
	return $value;
    }

    $note = uc($note);
    if ($modifier) {
	return $value;
    } else {
	my $modded = get_modified_notes($key);
	if ($modded->{$note}) {
	    my ($num, $new_modifier) = split "", $key;
	    return $note . $new_modifier . $octave;
	} else {
	    return $value;
	}
    }
}


sub get_note_number {
    my ($value, $default_octave) = @_;

    my $note; my $modifier; my $octave;
    if ($value =~ /^([a-zA-Z])([\#bN]?)(\d?)/) {
	$note = $1;
	$modifier = $2;
	$octave = $3;
    } else {
	warn "Invalid note: $value";
	return $value;
    } 

    if ($modifier eq "N") {
	$modifier = "";
    }

    if (not $octave) {
	$octave = $default_octave;
    }

    $octave++;

    my $lookup_key = uc($note) . $octave;
    my $number = $MIDI::note2number{$lookup_key};

    if ($modifier eq "#") {
	$number++;
    } elsif ($modifier eq "b") {
	$number--;
    }
    return $number;

}

# return true, 'cause that's what Perl modules do
1;
