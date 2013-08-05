use warnings;
use strict;

package SM;

my $note_re = qr/((\d+\.?)(\+\d+\.?)*)([a-zA-Z][b\#N]?\d?)/;

sub new {
    my ($class, $fn) = @_;

    my $self = parse_file($fn);

    bless $self, $class;
}

=pod
sub explode_tracks {
    my ($self) = @_;
    
    my @tracks = @{$self->{tracks}};
    TRACK: foreach my $track (@tracks) {
	my @notes = @{$track->{notes}};
	my $max_chord_size = 1;
	foreach my $note (@notes) {
	    if (defined $note->{chord}) {
		my $current_chord_size = scalar @{$note->{chord}};
		if ($current_chord_size > $max_chord_size) {
		    $max_chord_size = $current_chord_size;
		}
	    }
	}
	next unless $max_chord_size > 1;

	my $orig_name = $track->{name};
	

    }

}
=cut

sub parse_file {
    my ($fn) = @_;

    my $self = {};

    local $/ = "\n\n";
    open IN, $fn or die $!;
    PARAGRAPH: while (my $paragraph = <IN>) {
	chomp $paragraph;
	my @lines = split "\n", $paragraph;
	my $title;
	while ($_ = shift @lines) {
	    # ignore comments
	    if (/^\s*#/) {
		next;
	    }
	    if (!$title) {
		$title = $_;
		$title =~ s/\:$//;
		last;
	    }
	}
	if (! $title) {
	    die "need a header in each paragraph";
	}
	# at this point we've just read everything up to the first non-comment
	# line, which hopefully is a header name

	# deal with header data
	if ($title eq "header") {
	    # worry about header stuff later
	    my $header_data = {};
	    foreach (@lines) {
		my ($key, $val) = split /\:\s*/;
		$header_data->{$key} = $val;
	    }
	    $self->{header_data} = $header_data;
	    next PARAGRAPH;
	}

	# ok, here we know this is a part
	# the title is the name of the part
	my $track = {};
	$track->{name} = $title;
	my @notes;
	foreach (@lines) {
	    next if (/^\s*\#/);
	    my @note_specs = split /\s+/;
	    foreach my $ns (@note_specs) {
		if ($ns eq "em") {
		    # empty measure
		    # figure duration out later
		    push @notes, { duration => "measure",
				   note => "r" };
		} elsif ($ns =~ /^$note_re$/) {
		    # 5.G#3 = dotted quarter G# 3
		    # 4gN = eigth g4 natural
		    # 6g3N3 = half g3 natural
		    # 6+4f5 = half tied with eighth (damn you wagner)
		    my $duration = $1;
		    my $note = $4;
		    push @notes, { chord => [ [ { duration => $duration,
						note => $note } ] ] };
		} elsif ($ns =~ /^$note_re(,$note_re)*(;$note_re(,$note_re)*)+$/) {
		    # { duration => $duration,
		    #   chord_parts => [ [ { duration => 4, note => .. } ],
                    #                    [ { duration => 5, note => .. },
		    #                      { duration => 5, note => .. } ] 
		    # }
		    #
		    my @chord_parts = split /;/, $ns;
		    my @chord_part_specs;
		    foreach my $chord_part (@chord_parts) {
			my @notes = split /,/, $chord_part;
			my @note_specs;
			foreach (@notes) {
			    if (/$note_re/) {
				push @note_specs,
				{ duration => $1,
				  note => $4 };
			    } else {
				warn "invalid note spec: $chord_part";
			    }
			}
			push @chord_part_specs, \@note_specs;
		    }
		    push @notes, { chord => \@chord_part_specs };
		} else {
		    warn "can't parse note spec: $ns";
		}
	    }
	}
	$track->{notes} = \@notes;
	push @{$self->{tracks}}, $track;
    }
    return $self;
}

# return true, 'cause that's what Perl modules do
1;
