#!/usr/bin/env perl
use strict;
use warnings;

# Non-core imports
use PDF::API2;

=head1 NAME

glyphcode.pl - Find the Unicode codepoint of a symbol or dingbat.

=head1 SYNOPSIS

  ./glyphcode.pl symbol name heart
  ./glyphcode.pl symbol octal 256
  ./glyphcode.pl dingbat name a20
  ./glyphcode.pl dingbat octal 247

=head1 DESCRIPTION

Figure out the Unicode codepoint of a symbol from the built-in C<Symbol>
font or a dingbat from the built-in C<ZapfDingbats> font.

Tables of the characters in the C<Symbol> and C<ZapfDingbats> fonts can
be found in an appendix of the PDF specification.  Unfortunately, these
tables do not give you the Unicode codepoint of the symbols.  You must
use Unicode codepoints to access these characters through Scent.  This
script will look up the appropriate Unicode codepoint given either the
glyph name or the octal code.

The first parameter of the script is either C<symbol> to query the
built-in C<Symbol> font, or C<dingbat> to query the built-in
C<ZapfDingbats> font.

The second parameter of the script indicates whether you will be
providing the glyph name or the glyph code in octal.

The third parameter is either the glyph name or the glyph code in octal.
Both of these can be found in the tables in the appendix of the PDF
specification.

=cut

# ==================
# Program entrypoint
# ==================

# Get parameters
#
($#ARGV == 2) or die "Wrong number of program arguments.\n";

my $arg_font = shift @ARGV;
my $arg_mode = shift @ARGV;
my $arg_code = shift @ARGV;

(($arg_font eq 'symbol') or ($arg_font eq 'dingbat')) or
  die "Invalid font '$arg_font', expecting 'symbol' or 'dingbat'.\n";
(($arg_mode eq 'name') or ($arg_mode eq 'octal')) or
  die "Invalid mode '$arg_mode', expecting 'name' or 'octal'.\n";

if ($arg_mode eq 'name') {
  ($arg_code =~ /\A[\x{21}-\x{7e}]+\z/) or
    die "Invalid glyph name '$arg_code'.\n";

} elsif ($arg_mode eq 'octal') {
  ($arg_code =~ /\A[0-7]{1,3}\z/) or
    die "Invalid octal code '$arg_code'.\n";
  $arg_code = oct($arg_code);

} else {
  die "Unexpected";
}

# Load PDF system
# 
my $pdf = PDF::API2->new();

# Load appropriate font
#
my $font;
if ($arg_font eq 'symbol') {
  $font = $pdf->font('Symbol');

} elsif ($arg_font eq 'dingbat') {
  $font = $pdf->font('ZapfDingbats');

} else {
  die "Unexpected";
}

# Query the codepoint
#
my $codep;
if ($arg_mode eq 'name') {
  $codep = $font->uniByGlyph($arg_code);
  
} elsif ($arg_mode eq 'octal') {
  $codep = $font->uniByEnc($arg_code);
  
} else {
  die "Unexpected";
}

# Report result
#
if ($codep) {
  printf "Unicode codepoint: U+%X\n", $codep;
} else {
  print "Codepoint not found!\n";
}

=head1 AUTHOR

Noah Johnson E<lt>noah.johnson@loupmail.comE<gt>

=head1 COPYRIGHT

Copyright 2022 Multimedia Data Technology, Inc.

This program is free software.  You can redistribute it and/or modify it
under the same terms as Perl itself.

This program is also dual-licensed under the MIT license:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
