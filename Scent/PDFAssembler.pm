package Scent::PDFAssembler;
use v5.14;
use warnings;
use parent qw(Scent::Assembler);

# Scent imports
use Scent::Util qw(
  scFixedToFloat
  scIsBuiltInFont
);

# Non-core imports
use PDF::API2;

=head1 NAME

Scent::PDFAssembler - Assembler implementation that generates a PDF
file.

=head1 SYNOPSIS

  # Construct the PDF assembler
  my $asm = Scent::PDFAssembler->create("path/to/output.pdf");
  
  # Run instructions (see Scent::Assembler documentation)
  ...
  
  # Finish up the output file and close it
  $asm->finish;

=head1 DESCRIPTION

C<Scent::Assembler> subclass that uses all assembly instructions it
receives to build a PDF file from scratch.

See the C<Scent::Assembler> superclass documentation for further
information.

=cut

# =================
# Private functions
# =================

# calcTextMode(\@tmode)
# ---------------------
#
# Given a reference to an array of three values representing stroke,
# fill, and clip settings (defined is enabled, undef is disabled),
# return the integer PDF text rendering mode.
#
sub calcTextMode {
  # Get parameter
  ($#_ == 0) or die;
  my $ar = shift;
  
  (ref($ar) eq 'ARRAY') or die;
  (scalar(@$ar) == 3) or die;
  
  # Figure out the text mode
  my $text_mode;
  if (defined $ar->[2]) {
    # Clip enabled
    if (defined $ar->[0]) {
      # Clip enabled, stroke enabled
      if (defined $ar->[1]) {
        # Clip enabled, stroke enabled, fill enabled
        $text_mode = 6;
        
      } else {
        # Clip enabled, stroke enabled, fill disabled
        $text_mode = 5;
      }
      
    } else {
      # Clip enabled, stroke disabled
      if (defined $ar->[1]) {
        # Clip enabled, stroke disabled, fill enabled
        $text_mode = 4;
        
      } else {
        # Clip enabled, stroke disabled, fill disabled
        $text_mode = 7;
      }
    }
    
  } else {
    # Clip disabled
    if (defined $ar->[0]) {
      # Clip disabled, stroke enabled
      if (defined $ar->[1]) {
        # Clip disabled, stroke enabled, fill enabled
        $text_mode = 2;
        
      } else {
        # Clip disabled, stroke enabled, fill disabled
        $text_mode = 1;
      }
      
    } else {
      # Clip disabled, stroke disabled
      if (defined $ar->[1]) {
        # Clip disabled, stroke disabled, fill enabled
        $text_mode = 0;
        
      } else {
        # Clip disabled, stroke disabled, fill disabled
        $text_mode = 3;
      }
    }
  }
  
  # Return the integer text mode
  return $text_mode;
}

=head1 CONSTRUCTOR

=over 4

=item B<create(path)>

Create a new PDF assembler instance.  C<path> is the path to the PDF
file to create.

After you are finished running all the instructions, you should call the
C<finish()> function on this subclass.

=cut

sub create {
  # Get parameters
  ($#_ == 1) or die;
  
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $file_path = shift;
  (not ref($file_path)) or die;
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # The '_pdf' property stores PDF::API2 object, or undef if the
  # assembler has finished
  $self->{'_pdf'} = PDF::API2->new();
  
  # The '_path' property stores the file path we were given
  $self->{'_path'} = $file_path;
  
  # The '_fontmap' property stores a mapping of font names to PDF font
  # objects
  $self->{'_fontmap'} = {};
  
  # The '_imagemap' property stores a mapping of image names to PDF
  # image objects
  $self->{'_imagemap'} = {};
  
  # The '_pagedim', '_pagebleed', '_pagetrim', and '_pageart' properties
  # are used to store arrays with the dimensions of boundary boxes when
  # inside a page header; undef if outside a page header or if the
  # boundary box is not defined
  $self->{'_pagedim'} = undef;
  $self->{'_pagebleed'} = undef;
  $self->{'_pagetrim'} = undef;
  $self->{'_pageart'} = undef;
  
  # The '_pagerot' stores the page rotation in degrees, or undef if
  # outside a page header
  $self->{'_pagerot'} = undef;
  
  # The '_pdfpage' property stores the current PDF page object during a
  # page body definition, or undef if outside a page body
  $self->{'_pdfpage'} = undef;
  
  # The '_content' property stores the Content object, which is normally
  # a graphics content object except when in a text block, in which case
  # it is a text content object; it is undef outside of a page body
  # definition
  $self->{'_content'} = undef;
  
  # The '_pathmode' property at the start of path mode saves the stroke,
  # fill, and clip properties in an array of three elements; it is undef
  # outside of path mode
  $self->{'_pathmode'} = undef;
  
  # The '_textmode' property throughout the page definition stores the
  # stroke, fill, and clip properties of the text render mode, with clip
  # always undef except when in a text block that has clip mode enabled;
  # it is undef outside of a page body definition
  $self->{'_textmode'} = undef;
  
  # Return the new object
  return $self;
}

=back

=head1 PUBLIC INSTANCE METHODS

These are specific to this subclass.  See the C<Scent::Assembler>
superclass for more functions.

=over 4

=item B<finish()>

Check that the assembler is in a valid state for closing the document,
then create and save the PDF file.  You may not call this function more
than once.  Attempting to use the object after calling this function
will result in an error.

=cut

sub finish {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Make sure this is a valid stopping point
  $self->canStop or
    die "Invalid stopping state at end of assembly!\n";
  
  # All set, so save the PDF and undefine it
  $self->{'_pdf'}->save($self->{'_path'});
  $self->{'_pdf'} = undef;
}

=back

=head1 PROTECTED INSTANCE METHODS

Clients should not directly use these protected instance methods.
Instead, call the public instance methods defined by the superclass,
which will then check parameters and state and call through to the
protected methods defined by this sublcass.

=over 4

=item B<_font_standard(name, standard_name)>
=cut

sub _font_standard {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $font_name     = shift;
  my $standard_name = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Load the font
  $self->{'_fontmap'}->{$font_name} =
    $self->{'_pdf'}->font($standard_name);
}

=item B<_font_file(name, path)>
=cut

sub _font_file {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $font_name = shift;
  my $font_path = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Make sure the font path does not match a common font name
  (not scIsBuiltInFont($font_path)) or
    die "Invalid font path!\n";
  
  # Load font
  $self->{'_fontmap'}->{$font_name} =
    $self->{'_pdf'}->font($font_path, 'format' => 'truetype');
}

=item B<_image_jpeg(name, path)>
=cut

sub _image_jpeg {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $image_name = shift;
  my $image_path = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Load image
  $self->{'_imagemap'}->{$image_name} =
    $self->{'_pdf'}->image($image_path, 'format' => 'jpeg');
}

=item B<_image_png(name, path)>
=cut

sub _image_png {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $image_name = shift;
  my $image_path = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Load image
  $self->{'_imagemap'}->{$image_name} =
    $self->{'_pdf'}->image($image_path, 'format' => 'png');
}

=item B<_begin_page()>
=cut

sub _begin_page {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Initialize page header state
  $self->{'_pagedim'} = undef;
  $self->{'_pagebleed'} = undef;
  $self->{'_pagetrim'} = undef;
  $self->{'_pageart'} = undef;
  $self->{'_pagerot'} = 0;
}

=item B<_end_page()>
=cut

sub _end_page {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Restore the graphics state that was saved at the beginning of the
  # page
  $self->{'_content'}->restore;
  
  # Forget the page state
  $self->{'_pdfpage' } = undef;
  $self->{'_content' } = undef;
  $self->{'_pathmode'} = undef;
  $self->{'_textmode'} = undef;
}

=item B<_body()>
=cut

sub _body {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Define the new page
  $self->{'_pdfpage'} = $self->{'_pdf'}->page();
  
  # Define the boundaries array and add the media box
  my @bounds;
  push @bounds, (
    'media',
    [0, 0, $self->{'_pagedim'}->[0], $self->{'_pagedim'}->[1]]
  );
  
  # Add any optional boundary boxes that have been defined
  if (defined $self->{'_pagebleed'}) {
    push @bounds, (
      'bleed',
      $self->{'_pagebleed'}
    );
  }
  
  if (defined $self->{'_pagetrim'}) {
    push @bounds, (
      'trim',
      $self->{'_pagetrim'}
    );
  }
  
  if (defined $self->{'_pageart'}) {
    push @bounds, (
      'art',
      $self->{'_pageart'}
    );
  }
  
  # Set the page boundaries
  $self->{'_pdfpage'}->boundaries(@bounds);
  
  # Set the page rotation if it is non-zero
  if ($self->{'_pagerot'} != 0) {
    $self->{'_pdfpage'}->rotation($self->{'_pagerot'});
  }
  
  # Clear the page header state
  $self->{'_pagedim'} = undef;
  $self->{'_pagebleed'} = undef;
  $self->{'_pagetrim'} = undef;
  $self->{'_pageart'} = undef;
  $self->{'_pagerot'} = undef;
  
  # Get a graphics content object for the page
  $self->{'_content'} = $self->{'_pdfpage'}->graphics;
  my $gfx = $self->{'_content'};
  
  # Begin by saving the graphics state to ensure that graphics state
  # changes are kept within the page
  $gfx->save;
  
  # Set state parameters to match the Scent Assembler defaults
  $gfx->line_width(1);
  $gfx->line_cap('round');
  $gfx->line_join('round');
  $gfx->line_dash_pattern();
  $gfx->stroke_color('%000000FF');
  $gfx->fill_color('%000000FF');
  $gfx->character_spacing(0);
  $gfx->word_spacing(0);
  $gfx->hscale(100);
  $gfx->leading(0);
  $gfx->render(0);  # Text render mode: fill glyphs
  $gfx->rise(0);
  
  # Path mode starts undef because we are not in path mode; however,
  # text mode applies throughout the page, so initialize it to match
  # the default text render mode
  $self->{'_pathmode'} = undef;
  $self->{'_textmode'} = [undef, 'fill', undef];
}

=item B<_dim(width, height)>
=cut

sub _dim {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $width  = shift;
  my $height = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the dimensions
  $self->{'_pagedim'} = [
    scFixedToFloat($width),
    scFixedToFloat($height)
  ];
}

=item B<_bleed_box(min_x, min_y, max_x, max_y)>
=cut

sub _bleed_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  my $min_y = shift;
  my $max_x = shift;
  my $max_y = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the dimensions
  $self->{'_pagebleed'} = [
    scFixedToFloat($min_x),
    scFixedToFloat($min_y),
    scFixedToFloat($max_x),
    scFixedToFloat($max_y)
  ];
}

=item B<_trim_box(min_x, min_y, max_x, max_y)>
=cut

sub _trim_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  my $min_y = shift;
  my $max_x = shift;
  my $max_y = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the dimensions
  $self->{'_pagetrim'} = [
    scFixedToFloat($min_x),
    scFixedToFloat($min_y),
    scFixedToFloat($max_x),
    scFixedToFloat($max_y)
  ];
}

=item B<_art_box(min_x, min_y, max_x, max_y)>
=cut

sub _art_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  my $min_y = shift;
  my $max_x = shift;
  my $max_y = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the dimensions
  $self->{'_pageart'} = [
    scFixedToFloat($min_x),
    scFixedToFloat($min_y),
    scFixedToFloat($max_x),
    scFixedToFloat($max_y)
  ];
}

=item B<_view_rotate(mode)>
=cut

sub _view_rotate {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $mode = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the rotation
  if ($mode eq 'none') {
    $self->{'_pagerot'} = 0;
  } elsif ($mode eq 'right') {
    $self->{'_pagerot'} = 90;
  } elsif ($mode eq 'twice') {
    $self->{'_pagerot'} = 180;
  } elsif ($mode eq 'left') {
    $self->{'_pagerot'} = 270;
  } else {
    die;
  }
}

=item B<_begin_path(stroke, fill, clip)>
=cut

sub _begin_path {
  # Get self and parameters
  ($#_ == 3) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $stroke = shift;
  my $fill   = shift;
  my $clip   = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Store the parameters
  $self->{'_pathmode'} = [$stroke, $fill, $clip];
}

=item B<_end_path()>
=cut

sub _end_path {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # If a clip mode is defined, then indicate the clipping path should be
  # updated on the next path drawing command
  if (defined $self->{'_pathmode'}->[2]) {
    my $clip_mode = $self->{'_pathmode'}->[2];
    if ($clip_mode eq 'clipnz') {
      $self->{'_content'}->clip('rule' => 'nonzero');
    } elsif ($clip_mode eq 'clipeo') {
      $self->{'_content'}->clip('rule' => 'even-odd');
    } else {
      die;
    }
  }
  
  # Issue the appropriate path drawing command
  my $stroke = $self->{'_pathmode'}->[0];
  my $fill   = $self->{'_pathmode'}->[1];
  
  if ((defined $stroke) and (defined $fill)) {
    # Both stroke and fill the path
    if ($fill eq 'fillnz') {
      $self->{'_content'}->paint('rule' => 'nonzero');
    } elsif ($fill eq 'filleo') {
      $self->{'_content'}->paint('rule' => 'even-odd');
    } else {
      die;
    }
    
  } elsif (defined $stroke) {
    # Just stroke the path
    $self->{'_content'}->stroke;
    
  } elsif (defined $fill) {
    # Just fill the path
    if ($fill eq 'fillnz') {
      $self->{'_content'}->fill('rule' => 'nonzero');
    } elsif ($fill eq 'filleo') {
      $self->{'_content'}->fill('rule' => 'even-odd');
    } else {
      die;
    }
    
  } else {
    # Neither stroke nor fill the path
    $self->{'_content'}->end;
  }
  
  # Leaving path mode, so undefine parameters
  $self->{'_pathmode'} = undef;
}

=item B<_begin_text(clip)>
=cut

sub _begin_text {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $clip = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # If the given clip mode does not match the current clip mode, then
  # change the text rendering mode; do this before changing to text mode
  # so that the clipping mode is consistent throughout the whole text
  # block
  if (((defined $self->{'_textmode'}->[2]) and (not defined $clip)) or
      ((not defined $self->{'_textmode'}->[2]) and (defined $clip))) {
    # Update the text render mode
    $self->{'_textmode'}->[2] = $clip;
    
    # Set the new text render mode
    $self->{'_content'}->render(calcTextMode($self->{'_textmode'}));
  }
  
  # Replace the content object with a text block
  $self->{'_content'} = $self->{'_pdfpage'}->text;
}

=item B<_end_text()>
=cut

sub _end_text {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Replace the content object with a graphics object
  $self->{'_content'} = $self->{'_pdfpage'}->graphics;
}

=item B<_line_width(width)>
=cut

sub _line_width {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $width = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Set the parameter
  $self->{'_content'}->line_width(scFixedToFloat($width));
}

=item B<_line_cap(style)>
=cut

sub _line_cap {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $style = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Set the parameter
  $self->{'_content'}->line_cap($style);
}

=item B<_line_join(style[, miter-ratio])>
=cut

sub _line_join {
  # Get self and parameters
  ($#_ >= 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  ($#_ >= 0) or die;
  my $style = shift;
  
  my $ratio = undef;
  if ($#_ >= 0) {
    $ratio = shift;
  }
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Set the parameter
  $self->{'_content'}->line_join($style);
  
  # If a miter join, also set the miter limit ratio
  if ($style eq 'miter') {
    $self->{'_content'}->miter_limit(scFixedToFloat($ratio));
  }
}

=item B<_line_dash(phase, d1, g1, ... dn, gn)>
=cut

sub _line_dash {
  # Get self and phase parameter
  ($#_ >= 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  ($#_ >= 0) or die;
  my $phase = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Convert phase and all array parameters to float
  $phase = scFixedToFloat($phase);
  for my $val (@_) {
    $val = scFixedToFloat($val);
  }
  
  # Set the dash pattern
  if ($phase > 0) {
    $self->{'_content'}->line_dash_pattern(
      'pattern' => \@_,
      'offset'  => $phase
    );
  } else {
    $self->{'_content'}->line_dash_pattern(@_);
  }
}

=item B<_line_undash()>
=cut

sub _line_undash {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Clear the dash pattern
  $self->{'_content'}->line_dash_pattern();
}

=item B<_stroke_color(color)>
=cut

sub _stroke_color {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $color = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Set the color
  $self->{'_content'}->stroke_color($color);
}

=item B<_fill_color(color)>
=cut

sub _fill_color {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $color = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Set the color
  $self->{'_content'}->fill_color($color);
}

=item B<_save()>
=cut

sub _save {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->save;
}

=item B<_restore()>
=cut

sub _restore {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->restore;
}

=item B<_matrix(a, b, c, d, e, f)>
=cut

sub _matrix {
  # Get self and parameters
  ($#_ == 6) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $a = shift;
  my $b = shift;
  my $c = shift;
  my $d = shift;
  my $e = shift;
  my $f = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->matrix(
    scFixedToFloat($a),
    scFixedToFloat($b),
    scFixedToFloat($c),
    scFixedToFloat($d),
    scFixedToFloat($e),
    scFixedToFloat($f)
  );
}

=item B<_image(name)>
=cut

sub _image {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $image_name = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Show the image in a unit square at the origin
  $self->{'_content'}->object(
    $self->{'_imagemap'}->{$image_name},
    0, 0, 1, 1
  );
}

=item B<_move(x, y)>
=cut

sub _move {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x = shift;
  my $y = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->move(scFixedToFloat($x), scFixedToFloat($y));
}

=item B<_line(x2, y2)>
=cut

sub _line {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x2 = shift;
  my $y2 = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->line(scFixedToFloat($x2), scFixedToFloat($y2));
}

=item B<_curve(x2, y2, x3, y3, x4, y4)>
=cut

sub _curve {
  # Get self and parameters
  ($#_ == 6) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x2 = shift;
  my $y2 = shift;
  my $x3 = shift;
  my $y3 = shift;
  my $x4 = shift;
  my $y4 = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->curve(
    scFixedToFloat($x2),
    scFixedToFloat($y2),
    scFixedToFloat($x3),
    scFixedToFloat($y3),
    scFixedToFloat($x4),
    scFixedToFloat($y4)
  );
}

=item B<_closePath()>
=cut

sub _closePath {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->close;
}

=item B<_rect(x, y, width, height)>
=cut

sub _rect {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x      = shift;
  my $y      = shift;
  my $width  = shift;
  my $height = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->rectangle(
    scFixedToFloat($x),
    scFixedToFloat($y),
    scFixedToFloat($x + $width ),
    scFixedToFloat($y + $height)
  );
}

=item B<_cspace(extra)>
=cut

sub _cspace {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $extra = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->character_spacing(scFixedToFloat($extra));
}

=item B<_wspace(extra)>
=cut

sub _wspace {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $extra = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->word_spacing(scFixedToFloat($extra));
}

=item B<_hscale(percent)>
=cut

sub _hscale {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $pct = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->hscale(scFixedToFloat($pct));
}

=item B<_lead(distance)>
=cut

sub _lead {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $distance = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->leading(scFixedToFloat($distance));
}

=item B<_font(name, size)>
=cut

sub _font {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $font_name = shift;
  my $font_size = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->font(
    $self->{'_fontmap'}->{$font_name},
    scFixedToFloat($font_size)
  );
}

=item B<_text_render(stroke, fill)>
=cut

sub _text_render {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $stroke = shift;
  my $fill   = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Update the text mode state
  $self->{'_textmode'}->[0] = $stroke;
  $self->{'_textmode'}->[1] = $fill;
  
  # Update the text rendering mode
  $self->{'_content'}->render(calcTextMode($self->{'_textmode'}));
}

=item B<_rise(distance)>
=cut

sub _rise {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $distance = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->rise(scFixedToFloat($distance));
}

=item B<_advance([x, y])>
=cut

sub _advance {
  # Get self
  ($#_ >= 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x = undef;
  my $y = undef;
  
  if ($#_ >= 0) {
    $x = shift;
    $y = shift;
  }
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  if (defined $x) {
    $self->{'_content'}->position(
      scFixedToFloat($x),
      scFixedToFloat($y)
    );
  } else {
    $self->{'_content'}->crlf;
  }
}

=item B<_writeText(string)>
=cut

sub _writeText {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $str = shift;
  
  # Make sure the PDF is still open
  (defined $self->{'_pdf'}) or die;
  
  # Run instruction
  $self->{'_content'}->text($str);
}

=back

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
