nanomid
=======

A nano text-based musical language with a MIDI converter.

Most useful for entering one or more vocal lines to learn ensemble music.  Simple, yet powerful enough to support generating MIDIs for all the Valkyrie & Wotan parts in Act III.1/2 of Wagner's _Die Walküre_.

You can also enter in piano parts if they are relatively simple and you are patient.

You'll need Perl and the MIDI CPAN module:

	$ sudo perl -MCPAN -e 'install MIDI'

Then:

	$ perl n2mid.pl [text file with your music] [output midi file]

Look at the text files in the repo for some examples.
