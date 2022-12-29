#!/usr/bin/env perl
use v5.14;
use warnings;
use utf8;

# Core imports
use File::Temp qw(tempfile);

# Non-core imports
use Imager;

=head1 NAME

image_recode.pl - Report information about a given image file.

=head1 SYNOPSIS

  ./image_info.pl input_file.jpg output_file.jpg

=head1 DESCRIPTION

Re-encode an JPEG or PNG file for maximum portability.

The first path is to the existing JPEG or PNG file that will be
re-encoded.  The second path is to the re-encoded output file, which
must not already exist.  Both paths must have an extension that is a
case-insensitive match for C<.png>, C<.jpg>, or C<.jpeg>, and this
extension must match the format within the file.  It is acceptable for
the input to be JPEG and the output to be PNG, or vice versa.

Grayscale images are written to a temporary PGM file before being
re-encoded.  Color images are written to a temporary PPM file before
being re-encoded.  This ensures that a minimum of information from the
original file is carried over to the re-encoded file.

If a PNG file is given that has transparency, the image will be composed
over a white background when the intermediate file is generated.

JPEG files are always re-encoded with a quality of 90%.

=cut

# ==================
# Program entrypoint
# ==================

# Get program arguments
#
($#ARGV == 1) or die "Wrong number of program arguments!\n";

my $input_path = shift @ARGV;
(-f $input_path) or die "Can't find input file '$input_path'!\n";

my $output_path = shift @ARGV;
(not (-e $output_path)) or
  die "Output file '$output_path' already exists!\n";

# Figure out input and output formats from extensions
#
my $input_format = undef;
if ($input_path =~ /\.jpe?g\z/i) {
  $input_format = 'jpeg';

} elsif ($input_path =~ /\.png\z/i) {
  $input_format = 'png';

} else {
  die "Unsupported input file extension!\n";
}

my $output_format = undef;
if ($output_path =~ /\.jpe?g\z/i) {
  $output_format = 'jpeg';

} elsif ($output_path =~ /\.png\z/i) {
  $output_format = 'png';

} else {
  die "Unsupported output file extension!\n";
}

# Attempt to read the input file
#
my $img = Imager->new('file' => $input_path, 'type' => $input_format) or
  die sprintf("Failed to read input: %s\n", Imager->errstr());

# Check image properties and determine whether there is transparency
#
(($img->getwidth > 0) and ($img->getwidth <= 16384)) or
  die "Invalid input image width!\n";
(($img->getheight > 0) and ($img->getheight <= 16384)) or
  die "Invalid input image height!\n";

my $is_transparent = 0;

if (($img->colormodel eq 'gray') or ($img->colormodel eq 'rgb')) {
  $is_transparent = 0;
} elsif (($img->colormodel eq 'graya') or
          ($img->colormodel eq 'rgba')) {
  $is_transparent = 1;
} else {
  die "Invalid input color model!\n";
}

# Get a temporary file for the PNM intermediate file
#
my $fh = tempfile();
binmode($fh, ':raw') or die;

# Output a PNM file; since we haven't enabled wide support, the maximum
# bits per sample will be 8 in the intermediate file
#
if ($is_transparent) {
  $img->write('fh' => $fh, 'type' => 'pnm',
              'i_background' => "#ffffff") or
    die sprintf("Failed to write intermediate file: %s\n",
                $img->errstr);  
} else {
  $img->write('fh' => $fh, 'type' => 'pnm') or
    die sprintf("Failed to write intermediate file: %s\n",
                $img->errstr);
}

# Rewind the temporary file
#
seek($fh, 0, 0) or die;

# Create a new imager instance that reads the PNM intermediate file we
# just created
#
$img = Imager->new('fh' => $fh, 'type' => 'pnm') or die;

# Write the proper output file
#
if ($output_format eq 'jpeg') {
  $img->write('file' => $output_path, 'type' => 'jpeg',
              'jpegquality' => 90) or
    die sprintf("Failed to write output file: %s\n", $img->errstr);
  
} elsif ($output_format eq 'png') {
  $img->write('file' => $output_path, 'type' => 'png') or
    die sprintf("Failed to write output file: %s\n", $img->errstr);
  
} else {
  die;
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
