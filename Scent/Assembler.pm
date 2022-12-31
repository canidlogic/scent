package Scent::Assembler;
use v5.14;
use warnings;

# Scent imports
use Scent::Util qw(
  scIsFixed
  scParseFixed
  scIsName
  scIsBuiltInFont
  scIsCMYK
  scIsContentString
);

# Non-core imports
use Image::Info qw(image_info);

=head1 NAME

Scent::Assembler - Base class for Scent Assembly implementations.

=head1 SYNOPSIS

  # Construct one of the subclass implementations
  my $asm = ...
  
  # Each Scent Assembly instruction has a corresponding instance method
  # - Names and string values are passed as scalar strings
  # - The special "-" mark is passed as undef
  # - Numeric values are passed as integer-encoded fixed-point
  # - Color values are strings with % and then six base-16 digits
  
  $asm->font_standard("BuiltInFont", "Courier-Bold");
  $asm->font_file("CustomFont", "path/to/font.otf");
  $asm->image_jpeg("MyPhoto", "path/to/photo.jpg");
  $asm->image_png("MyGraphic", "path/to/graphic.png");
  
  $asm->begin_page;
  $asm->dim(59527559, 84188976);
  
  $asm->bleed_box(10, 10, 59527549, 84188966);
  $asm->trim_box(20, 20, 59527539, 84188956);
  $asm->art_box(30, 30, 59527529, 84188946);
  
  $asm->view_rotate("right");
  
  $asm->body;
  
  $asm->line_width(200000);
  $asm->line_cap("square");
  $asm->line_join("round");
  $asm->line_join("miter", 141400);
  
  $asm->line_dash(0, 1200000, 600000, 600000, 600000);
  $asm->line_dash(1200000, @pattern);
  $asm->line_undash;
  
  $asm->stroke_color("%ff00ff00");
  $asm->fill_color("%88AA00a3");
  
  $asm->save;
  $asm->restore;
  
  $asm->matrix(7200000, 0, 0, 3600000, 0, 0);
  $asm->image("MyPhoto");
  
  $asm->begin_path("stroke", "fillnz", undef);
  $asm->moveto(2500000, 1000000);
  $asm->line(4800000, 1000000);
  $asm->curve(2500000, 1000000, 0, 0, 55413, 29001);
  $asm->closePath;
  $asm->rect(0, 0, 7600000, 7600000);
  $asm->end_path;
  
  $asm->begin_text("clip");
  $asm->cspace(5000);
  $asm->wspace(1250);
  $asm->hscale(12500000);
  $asm->lead(3600000);
  $asm->font("CustomFont", 1200000);
  $asm->text_render(undef, "fill");
  $asm->rise(75000);
  $asm->advance;
  $asm->advance(2500000, -3700000);
  $asm->writeText("Hello world!");
  $asm->end_text;
  
  $asm->end_page;
  
  # Check whether this is acceptable stopping point
  if ($asm->canStop) {
    ...
  }
  
  # Run all the instructions in a Scent Assembly file
  $asm->run("path/to/scent.assembly");

=head1 DESCRIPTION

Abstract base class for processing Scent Assembly instructions.

Do not attempt to directly construct and use this abstract base class.
All methods will cause a fatal error C<Abstract base class>.

Instead, use one of the derived subclasses.  C<TextAssembler> is a
derived subclass that captures all the instructions and uses them to
create a Scent Assembly file.  C<PDFAssembler> is a derived subclass
that uses all the instructions to create a finished PDF file.
C<LayerAssembler> is a derived subclass that uses the instructions to
add overlays and/or underlays to the pages of an existing PDF file.

This base class implements all the public methods and performs argument
and state checking to make sure that the methods were given proper
arguments and that they were called when the assembler is in the proper
state.  After all the argument and state checking is performed, the base
class calls protected methods, which are exactly like the public methods
except they have an underscore prefixed to their name.

At any time, the C<canStop()> function indicates whether the assembly
object is in an acceptable state where the assembly can end.

This base class also provides a fully implemented method C<run> that
parses a Scent Assembly text file and runs all the instructions
contained within it against the methods provided by this class.

Within the base class, each protected method immediately causes a fatal
error C<Abstract base class> to prevent clients from directly using the
base class.  Subclasses must override each of these protected methods
and provide a proper implementation.  Since the base class has already
checked parameters and state, subclasses do not need to duplicate these
checks.

In order to implement a subclass, then, you need to inherit from this
base class, provide your own constructor, and then override each
protected method.  Do I<not> override the public methods.

If anything goes wrong with an assembly instruction, a fatal error
occurs.  Clients can catch these errors in an C<eval>.  However, they
should not attempt to use the assembler object again after an error has
happened.  Fatal errors that are likely to occur due to invalid syntax
in the Scent Assembly file will have a user-friendly message and a line
break at the end.

=head1 PRIVATE METHODS AND STATE

This base class reserves all keys starting with C<_base_> in the self
hash for its own private use.  Subclasses should not define any 
functions or keys in the object with this prefix.

=cut

# Page state constants
#
use constant PGS_NULL    => -1;
use constant PGS_HEADER  =>  0;
use constant PGS_INITIAL =>  1;
use constant PGS_PATH    =>  2;
use constant PGS_TEXT    =>  3;

# Path state constants
#
use constant PHS_NULL    => -1;
use constant PHS_EMPTY   =>  0;
use constant PHS_READY   =>  1;
use constant PHS_START   =>  2;
use constant PHS_SUBPATH =>  3;

# _base_init()
# ------------
#
# Initialize the _base_self on the current object if not already
# initialized.
#
sub _base_init {
  # Check parameter count
  ($#_ == 0) or die;
  
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize _base_self if not yet defined
  unless (defined $self->{'_base_self'}) {
    # Define base self
    $self->{'_base_self'} = {};
    
    # Get base self
    my $bself = $self->{'_base_self'};
    
    # image_names is a set mapping defined image names to a value of 1
    $bself->{'image_names'} = {};
    
    # font_names is a set mapping defined font names to a value of 1
    $bself->{'font_names'} = {};
    
    # built_ins is a set mapping built-in font names that have been
    # loaded to a value of 1
    $bself->{'built_ins'} = {};
    
    # has_pages is 1 if at least one page has been defined
    $bself->{'has_pages'} = 0;
    
    # in_page is 1 if a page definition is open, 0 otherwise
    $bself->{'in_page'} = 0;
    
    # page_state is PGS_HEADER, PGS_INITIAL, PGS_PATH, or PGS_TEXT if a
    # page definition is currently open, else PGS_NULL
    $bself->{'page_state'} = PGS_NULL;
    
    # page_dim is an array of two integer-encoded fixed-point values
    # storing the width and height of the page if a page definition is
    # open and the dimensions have been defined; undef otherwise
    $bself->{'page_dim'} = undef;
    
    # bleed_box, trim_box, and art_box are each arrays of four
    # integer-encoded fixed-point values, the first two storing the
    # lower-left coordinates of the box and the second two storing the
    # upper-right coordinates of the box; undef if not defined yet
    $bself->{'bleed_box'} = undef;
    $bself->{'trim_box' } = undef;
    $bself->{'art_box'  } = undef;
    
    # gstack is the graphics state stack; outside a page it must be
    # empty, inside a page there is always one element and the top
    # element is 0 if a current font is not defined or 1 if a current
    # font is defined; save and restore operations push and pop elements
    # from this stack
    $bself->{'gstack'} = [];
    
    # path_state is PHS_EMPTY when first entering path mode; PHS_READY
    # after a close or rect instruction; PHS_START after a move
    # instruction; PHS_SUBPATH after a line or curve instruction; or
    # PHS_NULL when not in path mode
    $bself->{'path_state'} = PHS_NULL;
    
    # text_content is set to 1 during text blocks to indicate at least
    # one text span has been rendered; it is cleared to zero at the
    # start of each text block and is ignored and set to zero when not
    # in text state
    $bself->{'text_content'} = 0;
  }
}

=head1 PROTECTED INSTANCE METHODS

Subclasses need to override each of these methods and provide their own
implementation.  The implementation in this base class simply causes a
fatal error.  The public instance methods have already checked that the
parameters are valid and that the state of the assembler was valid for
this particular instruction.  The specification of these protected
methods is the same as the corresponding public instance methods.

Clients should not directly use these protected instance methods.
Instead, call the public instance methods.

=over 4

=item B<_font_standard(name, standard_name)>
=cut

sub _font_standard {
  die "Abstract base class";
}

=item B<_font_file(name, path)>
=cut

sub _font_file {
  die "Abstract base class";
}

=item B<_image_jpeg(name, path)>
=cut

sub _image_jpeg {
  die "Abstract base class";
}

=item B<_image_png(name, path)>
=cut

sub _image_png {
  die "Abstract base class";
}

=item B<_begin_page()>
=cut

sub _begin_page {
  die "Abstract base class";
}

=item B<_end_page()>
=cut

sub _end_page {
  die "Abstract base class";
}

=item B<_body()>
=cut

sub _body {
  die "Abstract base class";
}

=item B<_dim(width, height)>
=cut

sub _dim {
  die "Abstract base class";
}

=item B<_bleed_box(min_x, min_y, max_x, max_y)>
=cut

sub _bleed_box {
  die "Abstract base class";
}

=item B<_trim_box(min_x, min_y, max_x, max_y)>
=cut

sub _trim_box {
  die "Abstract base class";
}

=item B<_art_box(min_x, min_y, max_x, max_y)>
=cut

sub _art_box {
  die "Abstract base class";
}

=item B<_view_rotate(mode)>
=cut

sub _view_rotate {
  die "Abstract base class";
}

=item B<_begin_path(stroke, fill, clip)>
=cut

sub _begin_path {
  die "Abstract base class";
}

=item B<_end_path()>
=cut

sub _end_path {
  die "Abstract base class";
}

=item B<_begin_text(clip)>
=cut

sub _begin_text {
  die "Abstract base class";
}

=item B<_end_text()>
=cut

sub _end_text {
  die "Abstract base class";
}

=item B<_line_width(width)>
=cut

sub _line_width {
  die "Abstract base class";
}

=item B<_line_cap(style)>
=cut

sub _line_cap {
  die "Abstract base class";
}

=item B<_line_join(style[, miter-ratio])>
=cut

sub _line_join {
  die "Abstract base class";
}

=item B<_line_dash(phase, d1, g1, ... dn, gn)>
=cut

sub _line_dash {
  die "Abstract base class";
}

=item B<_line_undash()>
=cut

sub _line_undash {
  die "Abstract base class";
}

=item B<_stroke_color(color)>
=cut

sub _stroke_color {
  die "Abstract base class";
}

=item B<_fill_color(color)>
=cut

sub _fill_color {
  die "Abstract base class";
}

=item B<_save()>
=cut

sub _save {
  die "Abstract base class";
}

=item B<_restore()>
=cut

sub _restore {
  die "Abstract base class";
}

=item B<_matrix(a, b, c, d, e, f)>
=cut

sub _matrix {
  die "Abstract base class";
}

=item B<_image(name)>
=cut

sub _image {
  die "Abstract base class";
}

=item B<_move(x, y)>
=cut

sub _move {
  die "Abstract base class";
}

=item B<_line(x2, y2)>
=cut

sub _line {
  die "Abstract base class";
}

=item B<_curve(x2, y2, x3, y3, x4, y4)>
=cut

sub _curve {
  die "Abstract base class";
}

=item B<_closePath()>
=cut

sub _closePath {
  die "Abstract base class";
}

=item B<_rect(x, y, width, height)>
=cut

sub _rect {
  die "Abstract base class";
}

=item B<_cspace(extra)>
=cut

sub _cspace {
  die "Abstract base class";
}

=item B<_wspace(extra)>
=cut

sub _wspace {
  die "Abstract base class";
}

=item B<_hscale(percent)>
=cut

sub _hscale {
  die "Abstract base class";
}

=item B<_lead(distance)>
=cut

sub _lead {
  die "Abstract base class";
}

=item B<_font(name, size)>
=cut

sub _font {
  die "Abstract base class";
}

=item B<_text_render(stroke, fill)>
=cut

sub _text_render {
  die "Abstract base class";
}

=item B<_rise(distance)>
=cut

sub _rise {
  die "Abstract base class";
}

=item B<_advance([x, y])>
=cut

sub _advance {
  die "Abstract base class";
}

=item B<_writeText(string)>
=cut

sub _writeText {
  die "Abstract base class";
}

=back

=head1 PUBLIC INSTANCE METHODS

Subclasses should I<not> override these methods.  Instead, override the
protected instance methods.

=head2 Top-level instructions

These are instructions that can only be used when no page definition is
currently open.  Although C<begin_page> is technically a top-level
instruction, it is grouped with the page structure instructions.

=over 4

=item B<font_standard(name, standard_name)>

Load a built-in font.  This instruction may only be used when no page
definition is open.

C<name> is the Scent name that will be used to refer to this font once
it is loaded.  This name is not actually stored within a PDF file; it is
only for identification within Scent Assembly.  C<name> must pass the
C<scIsName()> function of C<Scent::Util> and it must not already have
been defined by C<font_standard> or C<font_file>.

C<standard_name> is the name of one of the built-in PDF fonts.  It must
satisfy C<scIsBuiltInFont()>.

Each built-in font may be loaded by C<font_standard()> at most once.

=cut

sub font_standard {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Invalid font resource name '$res_name'!\n";
  
  my $font_name = shift;
  (not ref($font_name)) or die;
  scIsBuiltInFont($font_name) or
    die "Unrecognized built-in font name '$font_name'!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure no page definition is open
  (not $bself->{'in_page'}) or
    die "font_standard may not be used within a page!\n";
  
  # Make sure given resource name has not been defined as a font
  (not (defined $bself->{'font_names'}->{$res_name})) or
    die "Font resource name '$res_name' redefinition!\n";
  
  # Make sure given built-in font name has not already been loaded
  (not (defined $bself->{'built_ins'}->{$font_name})) or
    die "Built-in font '$font_name' loaded more than once!\n";
  
  # Update base state
  $bself->{'font_names'}->{$res_name } = 1;
  $bself->{'built_ins' }->{$font_name} = 1;
  
  # Everything is ready so call protected method
  $self->_font_standard($res_name, $font_name);
}

=item B<font_file(name, path)>

Load a TrueType or OpenType font from a file.  This instruction may only
be used when no page definition is open.

C<name> is the Scent name that will be used to refer to this font once
it is loaded.  This name is not actually stored within a PDF file; it is
only for identification within Scent Assembly.  C<name> must pass the
C<scIsName()> function of C<Scent::Util> and it must not already have
been defined by C<font_standard> or C<font_file>.

C<path> is the path to the font file.  It must refer to an existing
file.

=cut

sub font_file {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Invalid font resource name '$res_name'!\n";
  
  my $font_path = shift;
  (not ref($font_path)) or die;
  (-f $font_path) or
    die "Can't find font file '$font_path'!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure no page definition is open
  (not $bself->{'in_page'}) or
    die "font_file may not be used within a page!\n";
  
  # Make sure given resource name has not been defined as a font
  (not (defined $bself->{'font_names'}->{$res_name})) or
    die "Font resource name '$res_name' redefinition!\n";
  
  # Update base state
  $bself->{'font_names'}->{$res_name} = 1;
  
  # Everything is ready so call protected method
  $self->_font_file($res_name, $font_path);
}

=item B<image_jpeg(name, path)>

Load a raster image resource from a JPEG file.  This instruction may
only be used when no page definition is open.

C<name> is the Scent name that will be used to refer to this image once
it is loaded.  This name is not actually stored within a PDF file; it is
only for identification within Scent Assembly.  C<name> must pass the
C<scIsName()> function of C<Scent::Util> and it must not already have
been defined by C<image_jpeg> or C<image_png>.

C<path> is the path to the JPEG file.  It must refer to an existing
file.  Also, the C<Image::Info> library must verify that the file is
indeed a JPEG file, that its width and height do not exceed 16384
pixels, that its colorspace is grayscale or YCbCr without any alpha
channel, and that it is not interlaced.

It is strongly recommended to preprocess JPEG and PNG images with the
C<image_recode.pl> program to minimize the chances of weird encoding
problems.

=cut

sub image_jpeg {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Invalid image resource name '$res_name'!\n";
  
  my $img_path = shift;
  (not ref($img_path)) or die;
  (-f $img_path) or
    die "Can't find image file '$img_path'!\n";
  
  # Check the JPEG file
  my $info = image_info($img_path);
  if (my $error = $info->{'error'}) {
    die "Failed to parse image '$img_path' because: $error\n";
  }
  
  ($info->{'file_media_type'} eq 'image/jpeg') or
    die "Image '$img_path' is not a JPEG file!\n";
  
  (($info->{'width'} > 0) and ($info->{'height'} > 0)) or
    die "Image '$img_path' has invalid dimensions!\n";
  
  ($info->{'width'} <= 16384) or
    die "Image '$img_path' exceeds maximum width of 16384!\n";
  ($info->{'height'} <= 16384) or
    die "Image '$img_path' exceeds maximum height of 16384!\n";
  
  (($info->{'color_type'} eq 'Gray') or
    ($info->{'color_type'} eq 'YCbCr')) or
    die "JPEG image '$img_path' has unsupported color model!\n";
  
  (not defined $info->{'Interlace'}) or
    die "Image '$img_path' can't be interlaced!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure no page definition is open
  (not $bself->{'in_page'}) or
    die "image_jpeg may not be used within a page!\n";
  
  # Make sure given resource name has not been defined as an image
  (not (defined $bself->{'image_names'}->{$res_name})) or
    die "Image resource name '$res_name' redefinition!\n";
  
  # Update base state
  $bself->{'image_names'}->{$res_name} = 1;
  
  # Everything is ready so call protected method
  $self->_image_jpeg($res_name, $img_path);
}

=item B<image_png(name, path)>

Load a raster image resource from a PNG file.  This instruction may only
be used when no page definition is open.

C<name> is the Scent name that will be used to refer to this image once
it is loaded.  This name is not actually stored within a PDF file; it is
only for identification within Scent Assembly.  C<name> must pass the
C<scIsName()> function of C<Scent::Util> and it must not already have
been defined by C<image_jpeg> or C<image_png>.

C<path> is the path to the PNG file.  It must refer to an existing file.
Also, the C<Image::Info> library must verify that the file is indeed a
PNG file, that its width and height do not exceed 16384 pixels, that its
colorspace is grayscale or RGB without any alpha channel, and that it is
not interlaced.

It is strongly recommended to preprocess JPEG and PNG images with the
C<image_recode.pl> program to minimize the chances of weird encoding
problems.

=cut

sub image_png {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Invalid image resource name '$res_name'!\n";
  
  my $img_path = shift;
  (not ref($img_path)) or die;
  (-f $img_path) or
    die "Can't find image file '$img_path'!\n";
  
  # Check the PNG file
  my $info = image_info($img_path);
  if (my $error = $info->{'error'}) {
    die "Failed to parse image '$img_path' because: $error\n";
  }
  
  ($info->{'file_media_type'} eq 'image/png') or
    die "Image '$img_path' is not a PNG file!\n";
  
  (($info->{'width'} > 0) and ($info->{'height'} > 0)) or
    die "Image '$img_path' has invalid dimensions!\n";
  
  ($info->{'width'} <= 16384) or
    die "Image '$img_path' exceeds maximum width of 16384!\n";
  ($info->{'height'} <= 16384) or
    die "Image '$img_path' exceeds maximum height of 16384!\n";
  
  (($info->{'color_type'} ne 'GrayA') and
    ($info->{'color_type'} ne 'RGBA')) or
    die "PNG image '$img_path' has unsupported alpha channel!\n";
  
  (($info->{'color_type'} eq 'Gray') or
    ($info->{'color_type'} eq 'RGB')) or
    die "PNG image '$img_path' has unsupported color model!\n";
  
  (not defined $info->{'Interlace'}) or
    die "Image '$img_path' can't be interlaced!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure no page definition is open
  (not $bself->{'in_page'}) or
    die "image_png may not be used within a page!\n";
  
  # Make sure given resource name has not been defined as an image
  (not (defined $bself->{'image_names'}->{$res_name})) or
    die "Image resource name '$res_name' redefinition!\n";
  
  # Update base state
  $bself->{'image_names'}->{$res_name} = 1;
  
  # Everything is ready so call protected method
  $self->_image_png($res_name, $img_path);
}

=back

=head2 Page structure instructions

These instructions are used to declare pages and split the page
definition into a header section and body section.

=over 4

=item B<begin_page()>

Start the definition of a page.

This can only be called when not already in a page definition.  Each
begin page call must be matched with an end page call.  The page starts
out in header state with no dimensions or boundary boxes defined and all
graphics state initialized to default values.  The current font is
undefined at the start of each page.

=cut

sub begin_page {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure not currently in a page
  (not $bself->{'in_page'}) or
    die "begin_page instructions may not be nested!\n";
  
  # Initialize page state in base self
  $bself->{'in_page'     } = 1;
  $bself->{'page_state'  } = PGS_HEADER;
  $bself->{'page_dim'    } = undef;
  $bself->{'bleed_box'   } = undef;
  $bself->{'trim_box'    } = undef;
  $bself->{'art_box'     } = undef;
  $bself->{'gstack'      } = [0];
  $bself->{'path_state'  } = PHS_NULL;
  $bself->{'text_content'} = 0;
  
  # Set flag indicating at least one page defined
  $bself->{'has_pages'} = 1;
  
  # Everything is ready so call protected method
  $self->_begin_page;
}

=item B<end_page()>

Finish the definition of a page.

This can only be called when in a page definition.  The page state must
be initial state, with an error if it is in header, path, or text state.
The graphics state stack must be empty, such that each C<save>
instruction within the page is paired with a C<restore> instruction.

=cut

sub end_page {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page, in initial state, and graphics stack
  # with height one (meaning no user saves)
  ($bself->{'in_page'}) or
    die "end_page instruction without matching begin_page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "end_page may only be used in initial instruction state!\n";
  
  (scalar(@{$bself->{'gstack'}}) == 1) or
    die "Unpaired save instruction within page!\n";
  
  # Reset state in base self
  $bself->{'in_page'     } = 0;
  $bself->{'page_state'  } = PGS_NULL;
  $bself->{'page_dim'    } = undef;
  $bself->{'bleed_box'   } = undef;
  $bself->{'trim_box'    } = undef;
  $bself->{'art_box'     } = undef;
  $bself->{'gstack'      } = [];
  $bself->{'path_state'  } = PHS_NULL;
  $bself->{'text_content'} = 0;
  
  # Everything is ready so call protected method
  $self->_end_page;
}

=item B<body()>

Move from header state to initial state within a page.

This can only be called when in a page definition that is in header
state.  Furthermore, the page dimensions must be defined before calling
this instruction.

All boundary boxes are optional, but if they are defined then each must
be completely contained with the page area.

=cut

sub body {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "body instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "body instruction may only be used in header state!\n";
  
  # Make sure page dimensions have been defined
  (defined $bself->{'page_dim'}) or
    die "Define page dimensions before using body instruction!\n";
  
  # Check any boundary boxes that have been defined
  my $page_width  = $bself->{'page_dim'   }->[0];
  my $page_height = $bself->{'page_height'}->[1];
  
  for my $bb ('bleed_box', 'trim_box', 'art_box') {
    if (defined $bself->{$bb}) {
      # Get maximum box points
      my $max_x = $bself->{$bb}->[2];
      my $max_y = $bself->{$bb}->[3];
      
      # Check that maximums are within the dimensions
      ($max_x < $page_width) or
        die "Boundary box '$bb' right side exceeds page width!\n";
      ($max_y < $page_height) or
        die "Boundary box '$bb' top side exceeds page height!\n";
    }
  }
  
  # Switch to initial state
  $bself->{'page_state'} = PGS_INITIAL;
  
  # Everything is ready so call protected method
  $self->_body;
}

=back

=head2 Page header instructions

These instructions are used within the page header.

=over 4

=item B<dim(width, height)>

Define the dimensions of the current page.  This instruction may only be
used when a page definition is open and in header mode.  If used more
than once, subsequent definitions overwrite earlier definitions.  You
must define page dimensions for each page before using the C<body>
instruction.

The parameters are integer-encoded fixed-point values that must pass
C<scIsFixed> from C<Scent::Util>.  They must both be greater than zero.
The measurements are in points (1/72 inch).

=cut

sub dim {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $width = shift;
  scIsFixed($width) or die;
  ($width > 0) or die "Page width must be greater than zero!\n";
  
  my $height = shift;
  scIsFixed($height) or die;
  ($height > 0) or die "Page height must be greater than zero!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "dim instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "dim instruction may only be used in header state!\n";
  
  # Set the page dimensions
  $bself->{'page_dim'} = [$width, $height];
  
  # Everything is ready so call protected method
  $self->_dim($width, $height);
}

=item B<bleed_box(min_x, min_y, max_x, max_y)>

Define the (optional) bleed box of the current page.  This instruction
may only be used when a page definition is open and in header mode.  If
used more than once, subsequent definitions overwrite earlier
definitions.

The parameters are integer-encoded fixed-point values that must pass
C<scIsFixed> from C<Scent::Util>.  They must all be greater than zero,
and each maximum coordinate must be greater than its corresponding
minimum coordinate.  The measurements are in points (1/72 inch), where
the origin is the bottom-left corner of the page, X points right, and Y
points up.

When C<body> is called, a check will be made that all boundary box
maximum values are less than the corresponding page dimension.  This
check is not performed until the C<body> instruction, since the page
dimensions or boundary box could be redefined before then.

=cut

sub bleed_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  scIsFixed($min_x) or die;
  
  my $min_y = shift;
  scIsFixed($min_y) or die;
  
  my $max_x = shift;
  scIsFixed($max_x) or die;
  
  my $max_y = shift;
  scIsFixed($max_y) or die;
  
  ($min_x > 0) or die "Boundary box min_x must be greater than zero!\n";
  ($min_y > 0) or die "Boundary box min_y must be greater than zero!\n";
  ($max_x > $min_x) or
    die "Boundary box max_x must be greater than min_x!\n";
  ($max_y > $min_y) or
    die "Boundary box max_y must be greater than min_y!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "bleed_box instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "bleed_box instruction may only be used in header state!\n";
  
  # Set the boundary box
  $bself->{'bleed_box'} = [$min_x, $min_y, $max_x, $max_y];
  
  # Everything is ready so call protected method
  $self->_bleed_box($min_x, $min_y, $max_x, $max_y);
}

=item B<trim_box(min_x, min_y, max_x, max_y)>

Define the (optional) trim box of the current page.  This instruction
may only be used when a page definition is open and in header mode.  If
used more than once, subsequent definitions overwrite earlier
definitions.

The parameters are integer-encoded fixed-point values that must pass
C<scIsFixed> from C<Scent::Util>.  They must all be greater than zero,
and each maximum coordinate must be greater than its corresponding
minimum coordinate.  The measurements are in points (1/72 inch), where
the origin is the bottom-left corner of the page, X points right, and Y
points up.

When C<body> is called, a check will be made that all boundary box
maximum values are less than the corresponding page dimension.  This
check is not performed until the C<body> instruction, since the page
dimensions or boundary box could be redefined before then.

=cut

sub trim_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  scIsFixed($min_x) or die;
  
  my $min_y = shift;
  scIsFixed($min_y) or die;
  
  my $max_x = shift;
  scIsFixed($max_x) or die;
  
  my $max_y = shift;
  scIsFixed($max_y) or die;
  
  ($min_x > 0) or die "Boundary box min_x must be greater than zero!\n";
  ($min_y > 0) or die "Boundary box min_y must be greater than zero!\n";
  ($max_x > $min_x) or
    die "Boundary box max_x must be greater than min_x!\n";
  ($max_y > $min_y) or
    die "Boundary box max_y must be greater than min_y!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "trim_box instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "trim_box instruction may only be used in header state!\n";
  
  # Set the boundary box
  $bself->{'trim_box'} = [$min_x, $min_y, $max_x, $max_y];
  
  # Everything is ready so call protected method
  $self->_trim_box($min_x, $min_y, $max_x, $max_y);
}

=item B<art_box(min_x, min_y, max_x, max_y)>

Define the (optional) art box of the current page.  This instruction may
only be used when a page definition is open and in header mode.  If used
more than once, subsequent definitions overwrite earlier definitions.

The parameters are integer-encoded fixed-point values that must pass
C<scIsFixed> from C<Scent::Util>.  They must all be greater than zero,
and each maximum coordinate must be greater than its corresponding
minimum coordinate.  The measurements are in points (1/72 inch), where
the origin is the bottom-left corner of the page, X points right, and Y
points up.

When C<body> is called, a check will be made that all boundary box
maximum values are less than the corresponding page dimension.  This
check is not performed until the C<body> instruction, since the page
dimensions or boundary box could be redefined before then.

=cut

sub art_box {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $min_x = shift;
  scIsFixed($min_x) or die;
  
  my $min_y = shift;
  scIsFixed($min_y) or die;
  
  my $max_x = shift;
  scIsFixed($max_x) or die;
  
  my $max_y = shift;
  scIsFixed($max_y) or die;
  
  ($min_x > 0) or die "Boundary box min_x must be greater than zero!\n";
  ($min_y > 0) or die "Boundary box min_y must be greater than zero!\n";
  ($max_x > $min_x) or
    die "Boundary box max_x must be greater than min_x!\n";
  ($max_y > $min_y) or
    die "Boundary box max_y must be greater than min_y!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "art_box instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "art_box instruction may only be used in header state!\n";
  
  # Set the boundary box
  $bself->{'art_box'} = [$min_x, $min_y, $max_x, $max_y];
  
  # Everything is ready so call protected method
  $self->_art_box($min_x, $min_y, $max_x, $max_y);
}

=item B<view_rotate(mode)>

Define the (optional) view rotation of the current page.  This
instruction may only be used when a page definition is open and in
header mode.  If used more than once, subsequent definitions overwrite
earlier definitions.

The C<mode> parameter has the following possible string values:

   mode  |            Meaning
  -------+--------------------------------
   none  |  No view rotation
   right |  90 degrees clockwise rotation
   twice | 180 degrees clockwise rotation
   left  | 270 degrees clockwise rotation

The view rotation only affects how PDF viewer applications display the
page on a screen.  It has no effect on the coordinate system or
dimensions of the page.  Everything remains the same as though there
were no rotation.

The idiomatic way of handling landscape orientation is to define the
page in portrait orientation with everything rotated to the side, and
then set a view rotation so that on a screen it is shown correctly.
This is because printers usually always print paper in portrait
orientation, so thinking of landscape as a rotated portrait matches how
the page will be printed.

The default view rotation for each page is C<none>, which is used unless
a different view rotation is explicitly set with this instruction for
the page.

=cut

sub view_rotate {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $mode = shift;
  (not ref($mode)) or die;
  
  (($mode eq 'none') or ($mode eq 'right') or
    ($mode eq 'twice') or ($mode eq 'left')) or
    die "Invalid view rotation '$mode'!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in header state
  ($bself->{'in_page'}) or
    die "view_rotate instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_HEADER) or
    die "view_rotate instruction may only be used in header state!\n";
  
  # Everything is ready so call protected method
  $self->_view_rotate($mode);
}

=back

=head2 Content mode instructions

These instructions are used within the page body to switch between
initial mode, path mode, and text mode.

=over 4

=item B<begin_path(stroke, fill, clip)>

Enter path mode to define graphics to draw.  This instruction may only
be used when a page definition is open and in initial mode.

C<stroke> is either C<undef> for no stroke, or the string C<stroke> for
stroking.

C<fill> is either C<undef> for no fill, C<fillnz> for filling with the
nonzero winding rule, or C<filleo> for filling with the even-odd rule.

C<clip> is either C<undef> for no clipping area adjustment, C<clipnz>
for clipping area adjustment with the nonzero winding rule, or C<clipeo>
for clipping area adjustment with the even-odd rule.

You must match each C<begin_path> with an C<end_path>.  Rendering does
not take place until C<end_path>.  If multiple rendering operations are
specified, the order is:  (1) fill; (2) stroke; (3) adjust clipping
area.

Adjusting clipping area reduces the clipping area by intersecting it
with the interior of the path that was just defined.

At least one of the three parameters to this call must be defined.

=cut

sub begin_path {
  # Get self and parameters
  ($#_ == 3) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $stroke = shift;
  my $fill   = shift;
  my $clip   = shift;
  
  if (defined $stroke) {
    (not ref($stroke)) or die;
    ($stroke eq 'stroke') or die "Invalid stroke setting '$stroke'!\n";
  }
  
  if (defined $fill) {
    (not ref($fill)) or die;
    (($fill eq 'fillnz') or ($fill eq 'filleo')) or
      die "Invalid fill setting '$fill'!\n";
  }
  
  if (defined $clip) {
    (not ref($clip)) or die;
    (($clip eq 'clipnz') or ($clip eq 'clipeo')) or
      die "Invalid clip setting '$clip'!\n";
  }
  
  ((defined $stroke) or (defined $fill) or (defined $clip)) or
    die "Path must have at least one rendering mode!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "begin_path instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "begin_path instruction may only be used in initial state!\n";
  
  # Set path mode and start in empty path state
  $bself->{'page_state'} = PGS_PATH;
  $bself->{'path_state'} = PHS_NULL;
  
  # Everything is ready so call protected method
  $self->_begin_path($stroke, $fill, $clip);
}

=item B<end_path()>

Leave path mode and return to initial mode.  This instruction may only
be used when a page definition is open and in path mode.

All rendering operations that were defined at the beginning of the path
are executed when this command is given, in the order described at
C<begin_path>.

At least one instruction must have been issued between C<begin_path> and
C<end_path>, and the last instruction issued must not have been C<move>.

=cut

sub end_path {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "end_path instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "end_path instruction may only be used in path state!\n";
  
  # Make sure path definition not empty and that we haven't just started
  # a subpath
  ($bself->{'path_state'} != PHS_EMPTY) or
    die "Empty path definition!\n";
  
  ($bself->{'path_state'} != PHS_START) or
    die "Empty subpath definition!\n";
  
  # Return to initial mode and clear path state
  $bself->{'page_state'} = PGS_INITIAL;
  $bself->{'path_state'} = PHS_NULL;
  
  # Everything is ready so call protected method
  $self->_end_path;
}

=item B<begin_text(clip)>

Enter text mode to define text to draw.  This instruction may only be
used when a page definition is open and in initial mode.

C<clip> is either C<undef> for no clipping area adjustment or C<clip>
for clipping area adjustment.

You must match each C<begin_text> with an C<end_text>.  Rendering of
filled and stroked text takes place immediately at the C<write>
instructions within the text block.  (This is different than the
behavior of path blocks, where the path is neither filled nor stroked
until C<end_path>.)  However, clipping area updates do not take place
until the C<end_text> definition.

Adjusting clipping area reduces the clipping area by intersecting it
with the interior of all the glyphs that were written in the text block.

=cut

sub begin_text {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $clip = shift;
  if (defined $clip) {
    (not ref($clip)) or die;
    ($clip eq 'clip') or die "Invalid text clip setting '$clip'!\n";
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "begin_text instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "begin_text instruction may only be used in initial state!\n";
  
  # Set text mode and clear the text content flag
  $bself->{'page_state'  } = PGS_TEXT;
  $bself->{'text_content'} = 0;
  
  # Everything is ready so call protected method
  $self->_begin_text($clip);
}

=item B<end_text()>

Leave text mode and return to initial mode.  This instruction may only
be used when a page definition is open and in text mode.

If a clipping mode was set for this text block, the clipping area will
be intersected with the area of all glyphs that were rendered in this
text block.

At least one C<write> instruction must have been issued between
C<begin_path> and C<end_path>.

=cut

sub end_text {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "end_text instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "end_text instruction may only be used in text state!\n";
  
  # Make sure at least one text span was rendered
  $bself->{'text_content'} or
    die "Text block needs at least one write instruction!\n";
  
  # Return to initial mode and clear text block state
  $bself->{'page_state'  } = PGS_INITIAL;
  $bself->{'text_content'} = 0;
  
  # Everything is ready so call protected method
  $self->_end_text;
}

=back

=head2 Common state instructions

These instructions are used to modify the common graphics state both in
initial and text content modes.

=over 4

=item B<line_width(width)>

Set the line width for stroking paths and stroking glyph outlines.
C<width> is an integer-encoded fixed-point value that must be greater
than zero.  The width is measured in points (1/72 inch).  The default
width in Scent Assembly set at the start of each page is one point.

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub line_width {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $width = shift;
  scIsFixed($width) or die;
  ($width > 0) or
    die "Line width must be greater than zero!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "line_width instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "line_width may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_line_width($width);
}

=item B<line_cap(style)>

Set the line cap for stroking paths and stroking glyph outlines.
C<style> is either C<butt>, C<round>, or C<square>.  The default line
cap in Scent Assembly set at the start of each page is C<round>.

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub line_cap {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $style = shift;
  (not ref($style)) or die;
  (($style eq 'butt') or ($style eq 'round') or ($style eq 'square')) or
    die "Unrecognized line cap style '$style'!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "line_cap instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "line_cap may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_line_cap($style);
}

=item B<line_join(style[, miter-ratio])>

Set the line join style for stroking paths and stroking glyph outlines.
C<style> is either C<round>, C<bevel>, or C<miter>.  When C<miter> is
passed, a second parameter is required which gives the miter ratio limit
as an integer-encoded fixed-point value greater than zero.  The default
line join in Scent Assembly set at the start of each page is C<round>.

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub line_join {
  # Get self and parameters
  (($#_ == 1) or ($#_ == 2)) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $style = shift;
  (not ref($style)) or die;
  (($style eq 'round') or ($style eq 'bevel') or ($style eq 'miter')) or
    die "Unrecognized line join style '$style'!\n";
  
  my $miter_ratio = undef;
  if ($style eq 'miter') {
    ($#_ == 0) or die;
    $miter_ratio = shift;
    scIsFixed($miter_ratio) or die;
    ($miter_ratio > 0) or
      die "Miter ratio limit must be greater than zero!\n";
    
  } else {
    ($#_ < 0) or die;
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "line_join instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "line_join may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  if ($style eq 'miter') {
    $self->_line_join($style, $miter_ratio);
  } else {
    $self->_line_join($style);
  }
}

=item B<line_dash(phase, d1, g1, ... dn, gn)>

Set a line dash pattern for stroking paths and stroking glyph outlines.
C<phase> is an integer-encoded fixed-point value zero or greater that
specifies how far along in the pattern the dashing should begin,
measured in points (1/72 inch).

After C<phase> must follow two or more parameters, with the total number
of additional parameters being even.  These additional parameters come
in pairs C<dn> C<gn> where the C<d> parameters specify the length of a
dash in points and the C<g> parameters specify the length of a gap in
points.  All of these parameters are integer-encoded fixed-point values
greater than zero.  The pattern cycles infinitely.

By default, Scent Assembly sets no dashing pattern at the start of each
page, so that line dashing is not enabled unless this instruction is
used within a page.

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub line_dash {
  # Get self and parameters
  ($#_ >= 3) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $phase = shift;
  scIsFixed($phase) or die;
  ($phase >= 0) or
    die "Line dash phase must be zero or greater!\n";
  
  ((scalar(@_) % 2) == 0) or die;
  for my $dv (@_) {
    scIsFixed($dv) or die;
    ($dv > 0) or
      die "Dash pattern values must be greater than zero!\n";
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "line_dash instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "line_dash may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_line_dash($phase, @_);
}

=item B<line_undash()>

Clears any defined line dash pattern.  Lines will no longer be dashed
after this instruction.  This is the default dashing state that is set
by Scent Assembly at the start of each page.

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub line_undash {
  # Get self and parameters
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "line_undash instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "line_undash may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_line_undash;
}

=item B<stroke_color(color)>

Sets the color used for stroking paths and stroking glyph outlines.
C<color> is a string in the CMYK format defined by the C<scIsCMYK()>
function in C<Scent::Util>.  The default stroke color set by Scent
Assembly at the start of each page is black (C<%000000FF>).

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub stroke_color {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $color = shift;
  scIsCMYK($color) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "stroke_color instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "stroke_color may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_stroke_color($color);
}

=item B<fill_color(color)>

Sets the color used for filling paths and filling glyphs.  C<color> is a
string in the CMYK format defined by the C<scIsCMYK()> function in
C<Scent::Util>.  The default fill color set by Scent Assembly at the
start of each page is black (C<%000000FF>).

This instruction may only be used when a page definition is open and in
either initial or text mode.

=cut

sub fill_color {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $color = shift;
  scIsCMYK($color) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial or text state
  ($bself->{'in_page'}) or
    die "fill_color instruction may only be used within page!\n";
  
  (($bself->{'page_state'} == PGS_INITIAL) or
    ($bself->{'page_state'} == PGS_TEXT)) or
    die "fill_color may only be used in initial or text state!\n";
  
  # Everything is ready so call protected method
  $self->_fill_color($color);
}

=back

=head2 Initial instructions

These instructions can only be used when a page is in initial content
mode.  Technically, C<begin_path> and C<begin_text> are initial
instructions, but they are instead categorized as content mode
instructions.

=over 4

=item B<save()>

Push a copy of all the current graphics state parameters onto the
graphics state stack.

Each C<save> instruction must have a matching C<restore> instruction
later within the same page.  Save and restore blocks may be nested.

This instruction may only be used when a page definition is open and in
initial mode.

=cut

sub save {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "save instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "save instruction may only be used in initial state!\n";
  
  # Stack should always have at least one value on it while we are in a
  # page
  (scalar(@{$bself->{'gstack'}}) > 0) or die;
  
  # The value on the stack stores whether a font has been loaded in this
  # content, so we want to push another copy of that on top of our stack
  my $stack_value = $bself->{'gstack'}->[-1];
  push @{$bself->{'gstack'}}, ($stack_value);
  
  # Everything is ready so call protected method
  $self->_save;
}

=item B<restore()>

Pop and restore all the graphics state parameters from the top of the
graphics state stack.

Each C<restore> instruction must have a matching C<save> instruction
earlier within the same page.  Save and restore blocks may be nested.

This instruction may only be used when a page definition is open and in
initial mode.

=cut

sub restore {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "restore instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "restore instruction may only be used in initial state!\n";
  
  # Make sure at least two values on our stack; our stack always has a
  # height one greater than the number of saves on this page
  (scalar(@{$bself->{'gstack'}}) >= 2) or
    die "restore instruction without an earlier save!\n";
  
  # Pop the top value off our stack, restoring the previous state flag
  # keeping track of whether a font has been loaded
  pop @{$bself->{'gstack'}};
  
  # Everything is ready so call protected method
  $self->_restore;
}

=item B<matrix(a, b, c, d, e, f)>

Premultiply a given transformation matrix to the Current Transformation
Matrix (CTM).

The CTM is a 3x3 matrix that maps points C<(x, y)> in user space to
points C<(x', y')> in page space using the following formula:

  | x' y' 1 | = | x y 1 | x CTM

At the start of each page, the CTM is set so that the origin of user
space is the bottom-left corner of the page, the X axis points right,
the Y axis points up, and the unit on both X and Y axis is a point (1/72
inch).  The default CTM does I<not> take into account the view rotation
that may have been set with C<view_rotate> so the coordinate system will
always be for the unrotated portrait page rather than a rotated
landscape page.

The C<matrix> operation modifies the current CTM to a new CTM, C<CTM'>
according to the following formula:

         | a b 0 |
  CTM' = | c d 0 | x CTM
         | e f 1 |

Each of the arguments passed to this function must be integer-encoded
fixed-point values.

This instruction may only be used when a page definition is open and in
initial mode.

=cut

sub matrix {
  # Get self
  ($#_ >= 0) or die;
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Check we have six remaining parameters, each of which is an
  # integer-encoded fixed-point value
  ($#_ == 5) or die;
  for my $val (@_) {
    scIsFixed($val) or die;
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "matrix instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "matrix instruction may only be used in initial state!\n";
  
  # Everything is ready so call protected method
  $self->_matrix(@_);
}

=item B<image(name)>

Draw a raster image.

C<name> must pass C<scIsName> from C<Scent::Util> and it must be an
image resource name that has already been previously defined by an
C<image_jpeg> or C<image_png> instruction.

The image is drawn with its bottom-left corner at the origin of user
space, and its top-right corner at coordinates (1, 1) in user space.
The image is stretched to fit within this unit square.

Usually, you don't actually want the image to be drawn in a unit square
at the origin.  To position and size the image appropriately, use the
C<matrix> instruction to adjust user space so the unit square at the
origin in user space maps to the appropriate area on the page.

This instruction may only be used when a page definition is open and in
initial mode.

=cut

sub image {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Image name '$res_name' is not a valid resource name!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in initial state
  ($bself->{'in_page'}) or
    die "image instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_INITIAL) or
    die "image instruction may only be used in initial state!\n";
  
  # Make sure image has already been defined
  (defined $bself->{'image_names'}->{$res_name}) or
    die "Image name '$res_name' has not been defined!\n";
  
  # Everything is ready so call protected method
  $self->_image($res_name);
}

=back

=head2 Path instructions

These instructions can only be used when a page is in path content mode.
Technically, C<end_path> is a path instruction, but it is instead
categorized as a content mode instruction.

=over 4

=item B<move(x, y)>

Begin a new subpath, starting at the given coordinates in user space.

This instruction may only be used when a page definition is open and in
path mode.  Furthermore, it may not be used immediately following 
another C<move> instruction.

All parameters must be integer-encoded fixed-point values that pass the
C<scIsFixed()> function in C<Scent::Util>.

=cut

sub move {
  # Get self
  ($#_ >= 0) or die;
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Check remaining parameter count and that each is an integer-encoded
  # fixed-point value
  ($#_ == 1) or die;
  for my $val (@_) {
    scIsFixed($val) or die;
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "move instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "move instruction may only be used in path state!\n";
  
  # Make sure not immediately after another move instruction
  ($bself->{'path_state'} != PHS_START) or
    die "move instruction may not follow another move instruction!\n";
  
  # Update path state
  $bself->{'path_state'} = PHS_START;
  
  # Everything is ready so call protected method
  $self->_move(@_);
}

=item B<line(x2, y2)>

Add a line to the current subpath, going straight from the current
position in the subpath to the given coordinates.

This instruction may only be used when a page definition is open and in
path mode.  Furthermore, it may only be used after a C<move>, C<line>,
or C<curve> instruction.

All parameters must be integer-encoded fixed-point values that pass the
C<scIsFixed()> function in C<Scent::Util>.

=cut

sub line {
  # Get self
  ($#_ >= 0) or die;
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Check remaining parameter count and that each is an integer-encoded
  # fixed-point value
  ($#_ == 1) or die;
  for my $val (@_) {
    scIsFixed($val) or die;
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "line instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "line instruction may only be used in path state!\n";
  
  # Make sure immediately after a move, line, or curve instruction
  (($bself->{'path_state'} == PHS_START) or
    ($bself->{'path_state'} == PHS_SUBPATH)) or
    die "line instruction must follow move, line, or curve!\n";
  
  # Update path state
  $bself->{'path_state'} = PHS_SUBPATH;
  
  # Everything is ready so call protected method
  $self->_line(@_);
}

=item B<curve(x2, y2, x3, y3, x4, y4)>

Add a cubic Bezier curve to the current subpath, going from the current
position in the subpath to the (x4, y4) coordinates, using (x2, y2) and
(x3, y3) as control points.

This instruction may only be used when a page definition is open and in
path mode.  Furthermore, it may only be used after a C<move>, C<line>,
or C<curve> instruction.

All parameters must be integer-encoded fixed-point values that pass the
C<scIsFixed()> function in C<Scent::Util>.

=cut

sub curve {
  # Get self
  ($#_ >= 0) or die;
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Check remaining parameter count and that each is an integer-encoded
  # fixed-point value
  ($#_ == 5) or die;
  for my $val (@_) {
    scIsFixed($val) or die;
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "curve instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "curve instruction may only be used in path state!\n";
  
  # Make sure immediately after a move, line, or curve instruction
  (($bself->{'path_state'} == PHS_START) or
    ($bself->{'path_state'} == PHS_SUBPATH)) or
    die "curve instruction must follow move, line, or curve!\n";
  
  # Update path state
  $bself->{'path_state'} = PHS_SUBPATH;
  
  # Everything is ready so call protected method
  $self->_curve(@_);
}

=item B<closePath()>

Close the current subpath by drawing a line from the current position in
the subpath to the starting point of the subpath.

It is not necessary to close each subpath.  Subpaths may remain open.

This instruction may only be used when a page definition is open and in
path mode.  Furthermore, it may only be used after a C<line> or C<curve>
instruction.

This corresponds to the C<close> instruction in Scent Assembly, but was
renamed to avoid conflict with the Perl C<close> function.

=cut

sub closePath {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "close instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "close instruction may only be used in path state!\n";
  
  # Make sure immediately after a line or curve instruction
  ($bself->{'path_state'} == PHS_SUBPATH) or
    die "close instruction must follow line or curve!\n";
  
  # Update path state
  $bself->{'path_state'} = PHS_READY;
  
  # Everything is ready so call protected method
  $self->_close();
}

=item B<rect(x, y, width, height)>

Add a complete rectangular subpath to the current path.

If there is an open subpath when this instruction is called, that
subpath is added to the path with an open shape and then this rectangle
is added to the path as a separate subpath.

The lower-left corner of the rectangle is given by the (x, y)
coordinates.  The C<width> and C<height> must both be greater than zero.
For purposes of the nonzero winding rule, the edges of the rectangle
move in counter-clockwise direction.

This instruction may only be used when a page definition is open and in
path mode.  Furthermore, it may not be used immediately after a C<move>
instruction.

=cut

sub rect {
  # Get self and parameters
  ($#_ == 4) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $x      = shift;
  my $y      = shift;
  my $width  = shift;
  my $height = shift;
  
  (scIsFixed($x) and scIsFixed($y) and
    scIsFixed($width) and scIsFixed($height)) or die;
  
  ($width > 0) or
    die "Rectangle width must be greater than zero!\n";
  ($height > 0) or
    die "Rectangle height must be greater than zero!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in path state
  ($bself->{'in_page'}) or
    die "rect instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_PATH) or
    die "rect instruction may only be used in path state!\n";
  
  # Make sure not immediately after a move instruction
  ($bself->{'path_state'} != PHS_START) or
    die "rect instruction must not follow move instruction!\n";
  
  # Update path state
  $bself->{'path_state'} = PHS_READY;
  
  # Everything is ready so call protected method
  $self->_rect($x, $y, $width, $height);
}

=back

=head2 Text instructions

These instructions can only be used when a page is in text content mode.
Technically, C<end_text> is a text instruction, but it is instead
categorized as a content mode instruction.

When a page has multiple text blocks, the parameter values defined in
this section carry over from block to block.  However, they are always
reset to default values at the start of each page.

=over 4

=item B<cspace(extra)>

Set the character spacing for rendering glyphs.  C<extra> is an
integer-encoded fixed-point value that must be greater than or equal to
zero.  The extra width is measured in points (1/72 inch).  The default
extra width in Scent Assembly set at the start of each page is zero.

The extra space defined by character spacing is added to each rendered
glyph beyond the glyph's default spacing established by the font.  For
Unicode codepoint U+0020 (Space), the extra space for the glyph includes
the character spacing added together with the word spacing.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub cspace {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $extra = shift;
  scIsFixed($extra) or die;
  ($extra >= 0) or
    die "Character spacing must be zero or greater!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "cspace instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "cspace may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_cspace($extra);
}

=item B<wspace(extra)>

Set the word spacing for rendering glyphs.  C<extra> is an 
integer-encoded fixed-point value that must be greater than or equal to
zero.  The extra width is measured in points (1/72 inch).  The default
extra width in Scent Assembly set at the start of each page is zero.

The extra space defined by word spacing is added to the glyph on for
Unicode codepoint U+0020 (Space).  The extra space defined by word
spacing for the space character is in addition to any extra space
defined by the character spacing.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub wspace {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $extra = shift;
  scIsFixed($extra) or die;
  ($extra >= 0) or
    die "Word spacing must be zero or greater!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "wspace instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "wspace may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_wspace($extra);
}

=item B<hscale(percent)>

Set the horizontal scaling for rendering glyphs.  C<percent> is an 
integer-encoded fixed-point value that must be greater than zero.  The
default scaling value in Scent Assembly set at the start of each page
is 100, which means default horizontal scaling.

Scaling values greater than 100 mean that each glyph will be stretched
horizontally by that percent.  Scaling values less than 100 mean that
each glyph will be squeezed horizontally by that percent.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub hscale {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $pct = shift;
  scIsFixed($pct) or die;
  ($pct > 0) or
    die "Horizontal scaling must be greater than zero!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "hscale instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "hscale may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_hscale($pct);
}

=item B<lead(distance)>

Set the distance between baselines when an C<advance> instruction is
used without any parameters.

C<distance> is an integer-encoded fixed-point value.  The default value
in Scent Assembly set at the start of each page is zero, which means
lines are printed on top of each other.  You will probably want to
change that.

C<distance> values greater than zero move I<downward> on the page, which
is the opposite of the usual interpretation of Y coordinates in PDF.

This parameter is only relevant when an C<advance> instruction is used
without any parameters.  In that case, the start of the next text line
is the same as the start of the current text line, except the Y
coordinate is subtracted by the lead value.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub lead {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $lead = shift;
  scIsFixed($lead) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "lead instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "lead may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_lead($lead);
}

=item B<font(name, size)>

Set the current font.

C<name> must pass C<scIsName> from C<Scent::Util> and it must be a font
resource name that has already been previously defined by a
C<font_standard> or C<font_file> instruction.

C<size> is the size of the font in points.  It is an integer-encoded
fixed-point value that must be greater than zero.

You must set a font before using the C<write> instruction since there is
no default font.  The Scent Assembler will keep track of whether a font
is currently defined, including modifications by C<restore>
instructions, to make sure C<write> only happens when a font is defined.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub font {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $res_name = shift;
  (not ref($res_name)) or die;
  scIsName($res_name) or
    die "Font name '$res_name' is not a valid resource name!\n";
  
  my $font_size = shift;
  scIsFixed($font_size) or die;
  ($font_size > 0) or
    die "Font size must be greater than zero!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "font instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "font may only be used in text state!\n";
  
  # Make sure named font has already been defined
  (defined $bself->{'font_names'}->{$res_name}) or
    die "Font name '$res_name' is undefined!\n";
  
  # Set the font definition flag on the top of our stack
  $bself->{'gstack'}->[-1] = 1;
  
  # Everything is ready so call protected method
  $self->_font($res_name, $font_size);
}

=item B<text_render(stroke, fill)>

Set the text rendering mode.

C<stroke> is either C<undef> if not stroking glyph outlines or the
string C<stroke> if stroking font outlines.  C<fill> is either C<undef>
if not filling glyphs or the string C<fill> if filling font outlines.
The default set by Scent Assembly at the start of each page is fill
only.

If both stroke and fill are selected, the glyphs will be filled first
and stroked second.

It is possible to select neither stroke nor fill.  In this case, no
glyphs will be rendered on the page.  This may be useful when you have
clipping area modification enabled for the text block and you want to
use glyphs to adjust the clipping area without rendering them.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub text_render {
  # Get self and parameters
  ($#_ == 2) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $stroke = shift;
  if (defined $stroke) {
    ($stroke eq 'stroke') or
      die "Invalid text stroke mode '$stroke'!\n";
  }
  
  my $fill = shift;
  if (defined $fill) {
    ($fill eq 'fill') or
      die "Invalid text fill mode '$fill'!\n";
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "text_render instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "text_render may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_text_render($stroke, $fill);
}

=item B<rise(distance)>

Set the vertical distance to adjust the baseline when rendering glyphs.

C<distance> is an integer-encoded fixed-point value.  The default value
in Scent Assembly set at the start of each page is zero, which means
glyphs are printed directly on the baseline.  The distance measures
vertical distance in points (1/72 inch), with positive values lifting
the baseline for a superscript and negative values dropping the baseline
for a subscript.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub rise {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $rise = shift;
  scIsFixed($rise) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "rise instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "rise may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_rise($rise);
}

=item B<advance([x, y])>

Advance to the next line of text.

PDF has two different locations for keeping track of text position.  The
first location is the current line, which is the baseline point at the
start of the current line of text.  The second location is the current
text, which is the baseline point where the next string that will be
written is placed.  (The current text location does not take into
account the C<rise> of the text, which is applied just before a glyph is
rendered.)

At the start of each text block, the current line and current text are
both set to the origin of user space.

Each time text is rendered with C<write>, the X coordinate of the
current text location is advanced.  This allows a single line of text to
be rendered with a sequence of C<write> instructions.

The C<advance> instruction modifies the current line location and then
sets to the current text location to the new current line location.
This has the effect of advancing text position to the next line.  Since
the current line location is never modified by C<write> instructions,
line advances work the same way regardless of how many C<write>
instructions were performed on a text line.

If the C<advance> instruction is given two parameters, then the given X
and Y coordinates will be added to the current line location (relative
motion!)  The line leading parameter established by C<lead> is
completely ignored in this case.  Both parameters must be
integer-encoded fixed-point values.

If the C<advance> instruction is given no parameters, then the current
line location X coordinate will be unmodified but the current line
location Y coordinate will be subtracted by the current advance
distance.

This instruction may only be used when a page definition is open and in
text mode.

=cut

sub advance {
  # Get self
  ($#_ >= 0) or die;
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # If there are any parameters remaining, there must be exactly two
  # parameters and both must be integer-encoded fixed-point
  if ($#_ >= 0) {
    ($#_ == 1) or die;
    for my $val (@_) {
      scIsFixed($val) or die;
    }
  }
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "advance instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "advance may only be used in text state!\n";
  
  # Everything is ready so call protected method
  $self->_advance(@_);
}

=item B<writeText(string)>

Render a string of text.

C<string> is the string of text to render.  It must pass the
C<scIsContentString()> function of C<Scent::Util>.

Moving from left to right along the baseline, each codepoint in the
string will be mapped to the default glyph in the current font.  The
current text position will be updated each time a glyph is shown.

This function has no support for writing directions other than left to
right, and it does not support complex shaping or automatic ligatures,
since each codepoint is naively mapped to the default glyph without
taking context into account.  However, kerning I<is> supported.

A font must have been set with C<font> before using this function, since
there is no default font.

Within each text block, there must be at least one C<write> instruction.

This instruction may only be used when a page definition is open and in
text mode.

This corresponds to the C<write> instruction in Scent Assembly.  It has
been renamed here to avoid a name conflict with Perl's C<write>
function.

=cut

sub writeText {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $str = shift;
  scIsContentString($str) or
    die "Invalid text content string!\n";
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Make sure currently in a page and in text state
  ($bself->{'in_page'}) or
    die "write instruction may only be used within page!\n";
  
  ($bself->{'page_state'} == PGS_TEXT) or
    die "write may only be used in text state!\n";
  
  # Make sure a font is currently defined
  ($bself->{'gstack'}->[-1]) or
    die "write may only be used when a font is selected!\n";
  
  # Set the text content flag to indicate we've rendered some text
  # within this block
  $bself->{'text_content'} = 1;
  
  # Everything is ready so call protected method
  $self->_writeText($str);
}

=back

=head2 Non-instruction methods

This section contains public instance functions that do I<not>
correspond to Scent Assembly instructions.

=over 4

=item B<canStop()>

Return 1 if the assembler is in a state which is valid to finish the
document, or 0 otherwise.

The valid stopping state is no page definition currently open and at
least one page has been defined.

=cut

sub canStop {
  # Get self
  ($#_ == 0) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  # Initialize base self if necessary and get state
  $self->_base_init;
  my $bself = $self->{'_base_self'};
  
  # Must not currently be in a page
  (not $bself->{'in_page'}) or return 0;
  
  # Must have defined at least one page
  ($bself->{'has_pages'}) or return 0;
  
  # If we got here, we are in a valid stopping state
  return 1;
}

=item B<run(path)>

Run a Scent Assembly file at the given C<path> against this assembler
object.

Each instruction in the Scent Assembly file invokes the relevant
function on this object.  No check is made at the end whether this is a
valid stopping state.

Errors result in fatal errors.  Errors from instructions will be altered
to include line number information and then rethrown.

=cut

# Mapping of Scent Assembly operation names to an array descriptor.
#
# Instructions that start with "begin" or "end" must include the word
# after that in the instruction name.
#
# The first element in the array descriptor is a reference to the class
# instance function that should be called to handle the operation.
#
# Each remaining element in the array is a format string that
# represents a different possibility for the arguments to this class
# instance function.  The format strings have one character per argument
# to the operation, with n for name, s for string, f for fixed-point and
# c for CMYK color.  N is used for name or undef (-).  When N occurs,
# there will only be N in the format and no n.
#
# If an operation does not have any format strings, it means it is an
# exceptional syntax operation that must be handled specially by the
# parser.
#
my %OP_MAP = (
  'font_standard' => [\&font_standard, 'ns'],
  'font_file'     => [\&font_file    , 'ns'],
  'image_jpeg'    => [\&image_jpeg   , 'ns'],
  'image_png'     => [\&image_png    , 'ns'],
  'begin page'    => [\&begin_page   , ''],
  'end page'      => [\&end_page     , ''],
  'body'          => [\&body         , ''],
  'dim'           => [\&dim          , 'ff'],
  'bleed_box'     => [\&bleed_box    , 'ffff'],
  'trim_box'      => [\&trim_box     , 'ffff'],
  'art_box'       => [\&art_box      , 'ffff'],
  'view_rotate'   => [\&view_rotate  , 'n'],
  'begin path'    => [\&begin_path   , 'NNN'],
  'end path'      => [\&end_path     , ''],
  'begin text'    => [\&begin_text   , 'N'],
  'end text'      => [\&end_text     , ''],
  'line_width'    => [\&line_width   , 'f'],
  'line_cap'      => [\&line_cap     , 'n'],
  'line_join'     => [\&line_join],
  'line_dash'     => [\&line_dash],
  'line_undash'   => [\&line_undash  , ''],
  'stroke_color'  => [\&stroke_color , 'c'],
  'fill_color'    => [\&fill_color   , 'c'],
  'save'          => [\&save         , ''],
  'restore'       => [\&restore      , ''],
  'matrix'        => [\&matrix       , 'ffffff'],
  'image'         => [\&image        , 'n'],
  'move'          => [\&move         , 'ff'],
  'line'          => [\&line         , 'ff'],
  'curve'         => [\&curve        , 'ffffff'],
  'close'         => [\&closePath    , ''],
  'rect'          => [\&rect         , 'ffff'],
  'cspace'        => [\&cspace       , 'f'],
  'wspace'        => [\&wspace       , 'f'],
  'hscale'        => [\&hscale       , 'f'],
  'lead'          => [\&lead         , 'f'],
  'font'          => [\&font         , 'nf'],
  'text_render'   => [\&text_render  , 'NN'],
  'rise'          => [\&rise         , 'f'],
  'advance'       => [\&advance      , 'ff', ''],
  'write'         => [\&writeText    , 's'],
);

sub run {
  # Get self and parameters
  ($#_ == 1) or die;
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or die;
  
  my $path = shift;
  (not ref($path)) or die;
  (-f $path) or die "Can't find assembly file '$path'!\n";
  
  # Open the assembly file for UTF-8 input
  open(my $fh, "< :encoding(UTF-8) :crlf", $path) or
    die "Failed to open input file '$path'!\n";
  
  # Wrap the rest in an eval that closes the file and then rethrows any
  # errors
  eval {
    # Read the header line
    my $ltext = readline($fh);
    (defined $ltext) or
      die "Failed to read assembly header from '$path'!\n";
    
    # Drop line break, drop any leading UTF-8 byte order mark (BOM), and
    # make sure header and version is correct
    chomp $ltext;
    $ltext =~ s/^\x{feff}//;
    ($ltext =~ /^scent\-assembly\s+1\.0\s*$/) or
      die "Unsupported Scent Assembly header in '$path'!\n";
    
    # Parse the rest of the lines in the assembly, in an eval block that
    # catches errors, adds line numbers, and rethrows them
    my $line_number = 1;
    eval {
    while (1) {
      # Read the next line, leave loop if EOF
      $ltext = readline($fh);
      unless (defined $ltext) {
        if (eof($fh)) {
          last;
        } else {
          die "I/O error!\n";
        }
      }
      
      # Increase line number
      $line_number++;
      
      # Drop line break and skip line if blank or a comment line
      chomp $ltext;
      (not ($ltext =~ /^\s*$/)) or next;
      (not ($ltext =~ /^'/)) or next;
      
      # Tokenize the line into a token array, where each element is a
      # subarray pairing a string with a type code and a value; the type
      # code is 'n' for name, 's' for string, 'f' for fixed-point, 'c'
      # for CMYK color string, 'N' for undefined name
      my @tokens;
      while (length($ltext) > 0) {
        # Trim leading whitespace
        $ltext =~ s/^[ \t]+//;
        
        # If empty after trimming, done
        (length($ltext) > 0) or next;
        
        # Handle token based on whether this is a quoted string or not
        if ($ltext =~ /^"/) {
          # Quoted string so extract the whole quoted string, not
          # including the surrounding quotes
          ($ltext =~ /^"([^"]*)"/) or die "Unclosed quoted string!\n";
          my $raw = $1;
          $ltext =~ s/^"[^"]*"//;
          
          # Replace all apostrophes preceded by an odd number of
          # backslashes with double quotes and drop one of the
          # blackslashes
          $raw =~ s/^((?:\\\\)*)\\'/$1"/;
          $raw =~ s/([^\\](?:\\\\)*)\\'/$1"/g;
          
          # Make sure there are no ASCII 0x1a control codes
          (not ($raw =~ /\x{1a}/)) or
            die "Quoted string contains ASCII control codes!\n";
          
          # Replace all pairs of backslashes with ASCII 0x1a control
          # codes
          $raw =~ s/\\\\/\x{1a}/g;
          
          # If any backslashes remain, unrecognized escape codes present
          (not ($raw =~ /\\/)) or
            die "Quoted string contains invalid escape codes!\n";
          
          # Now substitute backslashes for the 0x1a control codes
          $raw =~ s/\x{1a}/\\/g;
          
          # Make sure a valid content string
          scIsContentString($raw) or
            die "Invalid quoted string!\n";
          
          # Add a string token
          push @tokens, (['s', $raw]);
          
        } else {
          # Not a quoted string, so extract all non-space characters at
          # the start
          ($ltext =~ /^(\S+)/) or die;
          my $raw = $1;
          $ltext =~ s/^\S+//;
          
          # Handle the specific token type
          if ($raw eq '-') {
            # Undefined name token
            push @tokens, (['N', undef]);
            
          } elsif ($raw =~ /^[\+\-0-9]/) {
            # Numeric token
            my $val = scParseFixed($raw);
            (defined $val) or die "Invalid numeric token '$raw'!\n";
            push @tokens, (['f', $val]);
            
          } elsif ($raw =~ /^[A-Za-z_]/) {
            # Name token
            scIsName($raw) or die "Invalid name token '$raw'!\n";
            push @tokens, (['n', $raw]);
            
          } elsif ($raw =~ /^%/) {
            # Color token
            scIsCMYK($raw) or die "Invalid color token '$raw'!\n";
            push @tokens, (['c', $raw]);
            
          } else {
            die "Unknown token type for '$raw'!\n";
          }
        }
      }
      
      # We got all the tokens; there must be at least one
      (scalar(@tokens) > 0) or die;
      
      # Get the first token as the instruction name
      my $op_name = shift @tokens;
      ($op_name->[0] eq 'n') or die "Invalid operation name!\n";
      $op_name = $op_name->[1];
      
      # If instruction name is "begin" or "end" then we need to get the
      # second token too and add it after a space
      if (($op_name eq 'begin') or ($op_name eq 'end')) {
        (scalar(@tokens) > 0) or die "Invalid operation name!\n";
        my $op_extra = shift @tokens;
        ($op_extra->[0] eq 'n') or die "Invalid operation name!\n";
        $op_extra = $op_extra->[1];
        $op_name = "$op_name $op_extra";
      }
      
      # Look up the operation record
      (defined $OP_MAP{$op_name}) or
        die "Unknown operation '$op_name'!\n";
      my $opr = $OP_MAP{$op_name};
      
      # If operation record has format strings, check that one of them
      # matches what we have; else, use exceptional check
      my $syntax_match = 0;
      if (scalar(@$opr) > 1) {
        # Regular operation -- build a syntax format string matching
        # what we have
        my $fmt_string = '';
        for my $tk (@tokens) {
          $fmt_string = $fmt_string . $tk->[0];
        }
        
        # If any of the values in the string is N, convert all n's to N
        if ($fmt_string =~ /N/) {
          $fmt_string =~ s/n/N/g;
        }
        
        # Check if format string matches any of the possibilities
        for(my $i = 1; $i < scalar(@$opr); $i++) {
          # Get current pattern
          my $pattern = $opr->[$i];
          
          # Check if pattern has any N values
          if ($pattern =~ /N/) {
            # N values, so check if format string has N values
            if ($fmt_string =~ /N/) {
              # Format string also has N values, so direct compare
              if ($pattern eq $fmt_string) {
                $syntax_match = 1;
                last;
              }
              
            } else {
              # Format string has no N values, so get alternate format
              # string that converts n to N and compare that
              my $alt_string = $fmt_string;
              $alt_string =~ s/n/N/g;
              if ($pattern eq $alt_string) {
                $syntax_match = 1;
                last;
              }
            }
            
          } else {
            # No N values, so only match if exact match
            if ($pattern eq $fmt_string) {
              $syntax_match = 1;
              last;
            }
          }
        }
        
      } else {
        # Exceptional operation
        if ($op_name eq 'line_join') {
          # For line_join, we must have one or two parameters and the
          # first parameter must be a name
          ((scalar(@tokens) == 1) or (scalar(@tokens) == 2)) or
            die "Invalid syntax for line_join!\n";
          ($tokens[0]->[0] eq 'n') or
            die "Invalid syntax for line_join!\n";
          
          # If first parameter is 'miter' then there must be a second
          # parameter that is fixed-point; else, there must be no second
          # parameter
          if ($tokens[0]->[1] eq 'miter') {
            (scalar(@tokens) == 2) or
              die "Invalid syntax for line_join!\n";
            ($tokens[1]->[0] eq 'f') or
              die "Invalid syntax for line_join!\n";
          
          # If we got here, syntax is OK
          $syntax_match = 1;
            
          } else {
            (scalar(@tokens) == 1) or
              die "Invalid syntax for line_join!\n";
          }
          
        } elsif ($op_name eq 'line_dash') {
          # For line_dash, we must have at least three parameters and
          # the total number of parameters must be odd
          ((scalar(@tokens) >= 3) and ((scalar(@tokens) % 2) == 1)) or
            die "Invalid syntax for line_dash!\n";
          
          # All parameters must be fixed-point
          for my $tk (@tokens) {
            ($tk->[0] eq 'f') or
              die "Invalid syntax for line_dash!\n";
          }
          
          # If we got here, syntax is OK
          $syntax_match = 1;
          
        } else {
          die "Unknown exceptional operation syntax for '$op_name'!\n";
        }
      }
      
      # Check whether our arguments match
      $syntax_match or die "Invalid syntax for instruction!\n";
      
      # Now build an argument list
      my @arg_list;
      for my $tk (@tokens) {
        push @arg_list, ($tk->[1]);
      }
      
      # Invoke the function call with self and arguments
      &{$opr->[0]}($self, @arg_list);
    }
    };
    if ($@) {
      die "Assembly file '$path' line $line_number:\n$@";
    }
  };
  if ($@) {
    close($fh) or warn "Failed to close file";
    die $@;
  }
  
  # Close the file
  close($fh) or warn "Failed to close file";
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
