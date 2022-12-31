package Scent::Util;
use v5.14;
use warnings;
use parent qw(Exporter);

# Core imports
use Encode qw(encode);
use POSIX;
use Scalar::Util qw(looks_like_number);

=head1 NAME

Scent::Util - Utility functions for Scent.

=head1 SYNOPSIS

  use Scent::Util qw(
    scIsLong
    scIsInteger
    scIsFixed
    scFixedToFloat
    scFixedToString
    scParseFixed
    scIsName
    scIsBuiltInFont
    scIsCMYK
    scIsContentString
    scEscapeString
  );
  
  # Check if a given scalar is a valid long integer
  if (scIsLong(29)) {
    ...
  }
  
  # Check if a given scalar is a valid integer
  if (scIsInteger(-11)) {
    ...
  }
  
  # Check if a given scalar is a valid integer-encoded fixed-point
  if (scIsFixed(250000)) {
    ...
  }
  
  # Convert an integer-encoded fixed-point into a floating-point scalar
  my $float = scFixedToFloat(250000);
  
  # Convert an integer-encoded fixed-point value into a string
  my $string = scFixedToString(250000);
  
  # Parse a string as a fixed-point value
  my $value = scParseFixed("-11.0250");
  if (defined $value) {
    ...
  }
  
  # Check that given scalar is a string storing valid name
  if (scIsName("MyNameExample_1")) {
    ...
  }
  
  # Check whether a string refers to a built-in PDF font name
  if (scIsBuiltInFont("Helvetica-Oblique")) {
    ...
  }
  
  # Check that a given scalar is a string storing a CMYK color
  if (scIsCMYK("%FF00FF00")) {
    ...
  }
  
  # Check that a given string is valid for text rendering
  if (scIsContentString($str)) {
    ...
  }
  
  # Apply \\ and \' escapes to a string
  my $escaped = scEscapeString($string);

=head1 DESCRIPTION

Various Scent utility functions.  See the function documentation for
further information.

=head1 FUNCTIONS

=over 4

=item B<scIsLong(value)>

Returns 1 if C<value> is a scalar long integer.  Else, returns 0.

This succeeds only if C<value> passes C<looks_like_number> from
<Scalar::Util>, its C<int()> conversion is equivalent, and its absolute
value does not exceed C<2^53 - 1> (the largest integer that can be
exactly stored within a double-precision floating point value).

=cut

use constant MAX_LONG =>  9007199254740991;
use constant MIN_LONG => -9007199254740991;

sub scIsLong {
  # Get parameter
  ($#_ == 0) or die;
  my $val = shift;
  
  # Check that it is a number
  looks_like_number($val) or return 0;
  
  # Check that it is an integer
  ($val == int($val)) or return 0;
  
  # Check that it is in range
  if (($val >= MIN_LONG) and ($val <= MAX_LONG)) {
    return 1;
  } else {
    return 0;
  }
}

=item B<scIsInteger(value)>

Returns 1 if C<value> is a scalar integer.  Else, returns 0.

This succeeds only if C<value> passes C<scIsLong()> and C<value> can be
stored within a two's-complement signed 32-bit integer.  That is, the
range must be [-2147483648, 2147483647].

=cut

use constant MAX_INTEGER =>  2147483647;
use constant MIN_INTEGER => -2147483648;

sub scIsInteger {
  # Get parameter
  ($#_ == 0) or die;
  my $val = shift;
  
  # Check it is a long integer
  (scIsLong($val)) or return 0;
  
  # Check that it is in range
  if (($val >= MIN_INTEGER) and ($val <= MAX_INTEGER)) {
    return 1;
  } else {
    return 0;
  }
}

=item B<scIsFixed(value)>

Returns 1 if C<value> is an integer-encoded fixed-point value.  Else,
returns 0.

This succeeds only if C<value> passes C<scIsLong()> and C<value> is in
the range [-3276700000, 3276700000].

=cut

use constant MAX_FIXED_ENCODED =>  3276700000;
use constant MIN_FIXED_ENCODED => -3276700000;

sub scIsFixed {
  # Get parameter
  ($#_ == 0) or die;
  my $val = shift;
  
  # Check it is a long integer
  (scIsLong($val)) or return 0;
  
  # Check that it is in range
  if (($val >= MIN_FIXED_ENCODED) and ($val <= MAX_FIXED_ENCODED)) {
    return 1;
  } else {
    return 0;
  }
}

=item B<scFixedToFloat(value)>

Given a C<value> that passes C<scIsFixed()>, return the closest
approximation of that value as a numeric scalar.

This conversion is not exact because Scent's fixed-point format uses
base-10 fractional digits while numeric scalars use floating-point with
base-2 fractional digits.

=cut

sub scFixedToFloat {
  # Get parameter
  ($#_ == 0) or die;
  my $val = shift;
  scIsFixed($val) or die;
  
  # Return the numeric scalar conversion
  return $val / 100000;
}

=item B<scFixedToString(value)>

Given a C<value> that passes C<scIsFixed()>, return a string
representation that matches the expected Scent string format for
fixed-point values.

Conversion between string representation and integer encoding for
fixed-point values is exact.  However, since there is more than one way
to express the same fixed-point value as a string, it is not guaranteed
that taking a fixed-point string, converting to integer encoding, and
then converting back to a string will yield the exact same string that
you started out with.

This function will return the shortest possible representation.  If
there are no fractional digits, an integer string representation without
any decimal point will be returned.

=cut

sub scFixedToString {
  # Get parameter
  ($#_ == 0) or die;
  my $val = shift;
  scIsFixed($val) or die;
  
  # Extract the sign and convert val to its absolute value
  my $negative = 0;
  if ($val < 0) {
    $negative = 1;
    $val = 0 - $val;
  }
  
  # Split the integer-encoded value into the integer and fractional
  # parts of the fixed-point value
  my $ipart = POSIX::floor($val / 100000.0);
  my $fpart = $val % 100000;
  
  # If the negative flag is set, make the integer part negative
  if ($negative) {
    $ipart = 0 - $ipart;
  }
  
  # Format as a string with the full five decimal places
  my $result = sprintf("%d.%05u", $ipart, $fpart);
  
  # Trim any trailing zeros and possibly the decimal point too
  $result =~ s/\.?0+$//;
  
  # Return the final result
  return $result;
}

=item B<scParseFixed(str)>

Given a scalar string C<str>, attempt to parse it as a Scent fixed-point
value and return the integer-encoded fixed-point value.

If the conversion succeeds, the returned scalar will pass
C<scIsFixed()>.  If the conversion fails, C<undef> is returned.

Leading and trailing whitespace is ignored.  No internal whitespace
within the fixed-point string value (for example, between digits) is
allowed.

If the first non-whitespace character is C<+> or C<-> then it is
interpreted as a sign indicating whether the value is positive or
negative.  There is no difference between positive and negative zero,
with both returning the exact same integer-encoded fixed-point value.

Apart from the optional sign and any leading or trailing whitespace, the
rest of the value must be a sequence of zero to five decimal digits,
optionally followed by a C<.> decimal point and a sequence of zero to
five decimal digits.  Furthermore, there must be at least one decimal
digit somewhere in the passed string or the conversion will fail.

Conversion between string representation and integer encoding for
fixed-point values is exact.  However, since there is more than one way
to express the same fixed-point value as a string, it is not guaranteed
that taking a fixed-point string, converting to integer encoding, and
then converting back to a string will yield the exact same string that
you started out with.

=cut

sub scParseFixed {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  (not ref($str)) or die;
  
  # Parse the whole string
  unless ($str =~ /^\s*([\+\-])?([0-9]{0,5})(\.[0-9]{0,5})?\s*$/) {
    return undef;
  }
  
  my $s = $1;
  my $i = $2;
  my $f = $3;
  
  # Negative flag is set only if sign is defined and '-', otherwise
  # clear
  my $negative = 0;
  if ((defined $s) and ($s eq '-')) {
    $negative = 1;
  }
  
  # If integer portion is not empty, convert to integer; else, set it to
  # zero and check that fractional defined and at least of length two
  # (indicating at least one digit)
  if ((defined $i) and (length($i) > 0)) {
    $i = int($i);
  } else {
    $i = 0;
    ((defined $f) and (length($f) >= 2)) or return undef;
  }
  
  # If fractional portion defined and at least of length two (indicating
  # at least one digit), then let d = 6 - length, convert everything
  # after first character to integer, and multiply by 10^d to account
  # for missing decimal positions; else, set fractional portion to zero
  if ((defined $f) and (length($f) >= 2)) {
    my $d = 6 - length($f);
    $f = int(substr($f, 1));
    for( ; $d > 0; $d--) {
      $f = $f * 10;
    }
    
  } else {
    $f = 0;
  }
  
  # Combine integer and fractional in integer-encoded fixed-point
  my $result = ($i * 100000) + $f;
  
  # If negative flag set and result is greater than zero, make the
  # result negative
  if ($negative and ($result > 0)) {
    $result = 0 - $result;
  }
  
  # Check that result passes scIsFixed
  scIsFixed($result) or return undef;
  
  # Return the result
  return $result;
}

=item B<scIsName(str)>

Returns 1 if C<str> is a scalar string that satisfies Scent requirements
for a name.  Else, returns 0.

This succeeds only if C<str> is a scalar consisting of one to 31 ASCII
alphanumeric and underscore characters where the first character is not
a decimal digit.

=cut

sub scIsName {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  
  # Check that it is scalar
  (not ref($str)) or return 0;
  
  # Check its format
  ($str =~ /^[A-Za-z_][A-Za-z_0-9]{0,30}$/) or return 0;
  
  # If we got here, check passed
  return 1;
}

=item B<scIsBuiltInFont(str)>

Returns 1 if C<str> is a scalar string that matches one of the built-in
PDF font names.  Else, returns 0.

The following are the built-in PDF font names:

  Courier
  Courier-Bold
  Courier-BoldOblique
  Courier-Oblique
  Helvetica
  Helvetica-Bold
  Helvetica-BoldOblique
  Helvetica-Oblique
  Symbol
  Times-Bold
  Times-BoldItalic
  Times-Italic
  Times-Roman
  ZapfDingbats

Note that built-in PDF font names do not always satisfy C<scIsName()>
because they may contain hyphens.

=cut

# Set mapping the recognized built-in font names to values of 1.
#
my %_BUILT_IN_FONTS = (
  'Courier'               => 1,
  'Courier-Bold'          => 1,
  'Courier-BoldOblique'   => 1,
  'Courier-Oblique'       => 1,
  'Helvetica'             => 1,
  'Helvetica-Bold'        => 1,
  'Helvetica-BoldOblique' => 1,
  'Helvetica-Oblique'     => 1,
  'Symbol'                => 1,
  'Times-Bold'            => 1,
  'Times-BoldItalic'      => 1,
  'Times-Italic'          => 1,
  'Times-Roman'           => 1,
  'ZapfDingbats'          => 1
);

sub scIsBuiltInFont {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  
  # Check that it is scalar
  (not ref($str)) or return 0;
  
  # Check that it is in the set
  (defined $_BUILT_IN_FONTS{$str}) or return 0;
  
  # If we got here, check passed
  return 1;
}

=item B<scIsCMYK(str)>

Returns 1 if C<str> is a scalar string that encodes a CMYK color.  Else,
returns 0.

The string must have exactly nine characters in the form:

  %CCMMYYKK

where each CMYK color channel is represented by exactly two base-16
digits specifying a channel value from 0-255.  Both uppercase and
lowercase letters are allowed for the base-16 digits C<A-F>.  Zero
padding is used for base-16 values that do not require two digits.

=cut

sub scIsCMYK {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  
  # Check that it is scalar
  (not ref($str)) or return 0;
  
  # Check its format
  ($str =~ /^%[0-9A-Fa-f]{8}$/) or return 0;
  
  # If we got here, check passed
  return 1;  
}

=item B<scIsContentString(str)>

Returns 1 if C<str> is a scalar string that is valid for use in text
rendering.  Else, returns 0.

The string must have at least one character.  Each character represents
a Unicode codepoint, with supplemental codepoints allowed.  When the
string is encoded in UTF-8, its byte length must not exceed 65,535
bytes.

Codepoints in surrogate range are forbidden.  ASCII control codes in
range C<[U+0000, U+001F]> are forbidden, as is C<U+007F>.  Although you
may use extended Unicode control codes, note that text rendering just
maps Unicode codepoints to a default glyph and does not attempt to
interpret Unicode controls in any way.

=cut

sub scIsContentString {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  
  # Check that it is scalar
  (not ref($str)) or return 0;
  
  # Check that all characters in range, and at least one character
  ($str =~ /^[\x{20}-\x{7e}\x{80}-\x{d7ff}\x{e000}-\x{10ffff}]+$/) or
    return 0;
  
  # If we have at most 16,383 characters then we know for sure that we
  # are in the 65,535-byte UTF-8 limit since UTF-8 will have at most
  # four bytes per codepoint, and 16,383 x 4 < 65535; if we have more
  # than 65,535 characters, then we know we are over the limit so we can
  # fail in that case; if we have [16384, 65535] characters, we need to
  # encode to UTF-8 to check whether we are in the limit
  unless (length($str) <= 16383) {
    # We must have at most 65535 characters or we know the string is too
    # long
    (length($str) <= 65535) or return 0;
    
    # If we got here, we need to UTF-8 encode to check whether we are in
    # the limit
    my $bytes = encode('UTF-8', $str,
                  Encode::FB_CROAK | Encode::LEAVE_SRC);
    (length($bytes) <= 65535) or return 0;
  }
  
  # If we got here, check passed
  return 1;  
}

=item B<scEscapeString(str)>

Apply Scent Assembly escapes to a given string.

C<str> is the unescaped string.  It may not include any ASCII control
codes in range [0x00, 0x1f] and 0x7f.

Any backslashes present in the data will be replaced with C<\\> escape
sequences and any double quotes present in the data will be replaced
with C<\'> escape sequences.  Finally, double quotes are added around
the string.

=cut

sub scEscapeString {
  # Get parameter
  ($#_ == 0) or die;
  my $str = shift;
  
  # Check that it is scalar
  (not ref($str)) or return 0;
  
  # Check that no ASCII control codes present
  (not ($str =~ /[\x{00}-\x{1f}\x{7f}]/)) or die;
  
  # Replace literal backslashes with \\ escapes
  $str =~ s/\\/\\\\/g;
  
  # Replace double quotes with \' escapes
  $str =~ s/"/\\'/g;
  
  # Surround string with double quotes
  $str = "\"$str\"";
  
  # Return the escaped string
  return $str;
}

=back

=cut

# ==============
# Module exports
# ==============

our @EXPORT_OK = qw(
  scIsLong
  scIsInteger
  scIsFixed
  scFixedToFloat
  scFixedToString
  scParseFixed
  scIsName
  scIsBuiltInFont
  scIsCMYK
  scIsContentString
  scEscapeString
);

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

# End with something that evaluates to true
1;
