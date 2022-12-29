#!/usr/bin/env perl
use v5.14;
use warnings;
use utf8;

# Non-core imports
use Image::Info qw(image_info);

=head1 NAME

image_info.pl - Report information about a given image file.

=head1 SYNOPSIS

  ./image_info.pl image_file.jpg

=head1 DESCRIPTION

Given the path to an image file, report information about the image file
using the C<Image::Info> library.

=cut

# ==================
# Program entrypoint
# ==================

# Get program arguments
#
($#ARGV == 0) or die "Wrong number of program arguments!\n";

my $file_path = shift @ARGV;
(-f $file_path) or die "Can't find file '$file_path'!\n";

# Read information about the image file
#
my $info = image_info($file_path);
if (my $error = $info->{'error'}){
  die "Can't parse image info: $error\n";
}

# Fill in missing fields with unknown values
#
unless (defined $info->{'SamplesPerPixel'}) {
  $info->{'SamplesPerPixel'} = -1;
}
unless (defined $info->{'BitsPerSample'}) {
  $info->{'BitsPerSample'} = [];
}
unless (ref($info->{'BitsPerSample'}) eq 'ARRAY') {
  $info->{'BitsPerSample'} = [ $info->{'BitsPerSample'} ];
}
unless (defined $info->{'Interlace'}) {
  $info->{'Interlace'} = '';
}
unless (defined $info->{'Compression'}) {
  $info->{'Compression'} = '';
}

# Report information
#
printf "File MIME type: %s\n", $info->{'file_media_type'};
printf "Image width   : %d\n", $info->{'width'};
printf "Image height  : %d\n", $info->{'height'};
printf "Color type    : %s\n", $info->{'color_type'};
printf "Resolution    : %s\n", $info->{'resolution'};

if ($info->{'SamplesPerPixel'} >= 0) {
  printf "Samples/pixel : %d\n", $info->{'SamplesPerPixel'};
} else {
  print  "Samples/pixel :\n";
}

print  "Bits/sample   :";
for my $bps (@{$info->{'BitsPerSample'}}) {
  printf " %d", $bps;
}
print "\n";

printf "Interlace     : %s\n", $info->{'Interlace'};
printf "Compression   : %s\n", $info->{'Compression'};

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
