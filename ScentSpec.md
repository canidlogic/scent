# Scent Specification

Scent is a Shastina dialect that is used for compiling PDF files.  A specification for Shastina is available at [libshastina](https://github.com/canidlogic/libshastina).

## Header

There are two kinds of Scent files:  _standalone_ and _embedded._  A standalone Scent file is able to compile directly into PDF.  An embedded Scent file must first be embedded into a standalone Scent file before it can be compiled into PDF.  Embedded Scent files are useful for graphics and diagrams that are defined individually in embedded format and then later incorporated into a Scent standalone document.

Standalone Scent files must begin with the following kind of header:

    %scent 1.0;

More specifically, the first four Shastina entities read from the file must be as follows:

1. `BEGIN_META`
2. `META_TOKEN` with value `scent`
3. `META_TOKEN` with version number
4. `END_META`

The `scent` token is case sensitive.

The version number allows implementations supporting future versions of this specification to remain backwards compatible.  Implementations targeting this specification of Scent should refuse to parse anything that does not have a version exactly matching `1.0`.

Standalone Scent files may use all Scent operations, which are defined in later sections of this specification.

Embedded Scent files must begin with the following kind of header:

    %scent-embed 1.0;
    %bound-x 0;
    %bound-y -125.50;
    %bound-w 500;
    %bound-h 125.50;
    %body;

The first four Shastina entities read from the file are the same as read from a standalone Scent file, except the second token must be `scent-embed` instead of `scent`.  In the example above, the first four Shastina entities are contained on the first line.

Following the first four entities, there must be a sequence of one or more embedded header metacommands.  Each of these embedded header metacommands except the last has the following format:

1. `BEGIN_META`
2. `META_TOKEN` with value defining parameter name
3. `META_TOKEN` with value defining parameter value
4. `END_META`

The supported parameter names are `bound-x`, `bound-y`, `bound-w` and `bound-h`.  Each of these parameter names must be defined exactly once in the header, but the order of definitions does not matter.  The parameter values must all be fixed-point values in the same format defined for numeric entities later in this specification.  (Integers are automatically promoted to fixed-point.)

The parameters defined in the header indicate the lower-left corner and the width and height of the bounding box surrounding the embedded graphics defined by this file.  The specific X and Y coordinates used for the bounding box do not matter so much because they will be transformed into page space when the embedded graphic object is placed on the page.

The defined bounding box is only used for layout purposes.  In particular, the content drawn by the embedded graphics is _not_ clipped to the bounding box.

After all the header parameters and values have been defined, the last embedded header metacommand has the following format:

1. `BEGIN_META`
2. `META_TOKEN` with value `body`
3. `END_META`

After this metacommand is read, the header of the file is completed and no further metacommands may be used within the file.

Embedded Scent files may only use a subset of Scent operations.  The operation documentation given later in the specification will note which operations are only available in standalone format.

## Data types

Scent supports the following data types both on the Shastina interpreter stack and also in variables and constants:

1. Null
2. Integer
3. Fixed-point
4. Atom
5. String
6. Ream object
7. Color object
8. Stroke object
9. Font object
10. Image object
11. Path object
12. Transform object
13. Style object
14. Column object
15. Clipping object

The _null type_ includes only a single data value that represents a null, undefined value.

The _integer type_ supports all signed values in the range [-2147483648, +2147483647].  This matches the allowed range for integers set out in the PDF specification.

The _fixed-point type_ supports fractional values.  This is stored as a signed-integer value encoding a fixed-point decimal number with five fractional places after the decimal point.  The smallest supported value that is greater than zero is 0.00001.  The largest supported value is 32767.00000.  The largest supported value that is less than zero is -0.00001.  The smallest supported value is -32767.00000.  This range is very close to the real type defined by the PDF specification.

Integers can be automatically promoted to fixed-point values.  This means that an integer can be used anywhere a fixed-point value is expected, and the integer will be automatically converted to an equivalent fixed-point value.  However, automatic promotion only works for integers in the range [-32767, 32767].  Integers outside that range cause an error if they are used in place of a fixed-point value.

The _atom type_ is used for various special constants.  An atom is a predefined constant string value that is mapped to a unique integer value.  Only the unique integer value needs to be stored on the interpreter stack and as variable and constant values.  However, atoms are not interchangeable with integers or strings.

The _string type_ is used for storing Unicode text.  Strings are stored in memory as binary strings that are UTF-8 encoded.  The maximum string size is 65535 bytes in the binary UTF-8 encoding, which matches the limit given in the PDF specification.

The following subsections describe the different object types.

All Scent data types are immutable, which means that once the specific data value is pushed on the stack or stored in a variable or constant value, it will never change.

### Ream objects

A _ream object_ describes the dimensions of a page.  Each page in the PDF file comes from a ream that defines its dimensions.

Ream objects have the following properties:

1. Paper size
2. Boundaries
3. Rotation

The _paper size_ is the physical size of the paper.  Although this size is allowed to be in landscape orientation, the idiomatic way of handling landscape orientation is to define the paper size in portrait orientation and then apply transformations to the page axes.  The paper size is given as a width and height in points, where points are exactly 1/72 of an inch.  The following table shows common paper sizes, their official width and height in millimeters or inches, and their closest approximation in points:

      Size  |   Width    |   Height  |         Points
    ========+============+===========+========================
     A5     |     148 mm | 210 mm    | 419.52756 x  595.27559
     A4     |     210 mm | 297 mm    | 595.27559 x  841.88976
     A3     |     297 mm | 420 mm    | 841.88976 x 1190.55118
    --------+------------+-----------+------------------------
     B5     |     176 mm | 250 mm    | 498.89764 x  708.66142
     B4     |     250 mm | 353 mm    | 708.66142 x 1000.62992
    --------+------------+-----------+------------------------
     JIS-B5 |     182 mm | 257 mm    | 515.90551 x  728.50394
     JIS-B4 |     257 mm | 364 mm    | 728.50394 x 1031.81102
    --------+------------+-----------+------------------------
     letter |   8.5 inch | 11.0 inch | 612.00000 x  792.00000
     legal  |   8.5 inch | 14.0 inch | 612.00000 x 1008.00000
     ledger |  11.0 inch | 17.0 inch | 792.00000 x 1224.00000

These sizes match those defined by the Cascading Style Sheets (CSS) standard for the `size` descriptor of the `@page` at-rule.  Dimensions given in inches in the above table are converted to points by multiplying by 72.  Dimensions given in millimeters are converted to points by multiplying by 72, dividing by 25.4 and rounding to the fixed-point value.

The _boundaries_ define the printing areas on the page.  Printers are not able to print close against the edge of the paper.  To work around this problem, there are two different boundary methods: simple and complex.

In the simple boundary method, the size of the finished page matches the paper size defined by the ream.  There must be an _art box_ defined that is smaller than the paper size, leaving small margins around the edges of the paper.  Printing will be confined to the art box, allowing the printer to avoid the edges of the paper.  The disadvantage to the simple boundary method is that there must be small blank margins around the edges of the paper, so there is no way for graphics to extend all the way to the edge of the finished page.

In the complex boundary method, the paper size defined by the ream is larger than the desired finished page size.  The _bleed box_ must be smaller than the paper size of the ream, so that the printer can avoid the edges of the paper.  The finished paper size is defined by the _trim box,_ which must be smaller than the bleed box.  After the page is printed on the paper size defined by the ream, the page is sliced to the trim box.  The trimmed page can therefore have graphics that extend all the way to the edge of the finished page.  Since slicing the paper is always somewhat inaccurate, graphics on the edge of the page should extend into the bleed box, to allow for some error in trimming.

The complex boundary method also allows for there to be a trim box but no bleed box.  This is used in cases where the page will be finished by trimming but there is no need for bleed.

Scent allows an art box, bleed box, and trim box to be defined for each ream.  To match the style used in PDF/X, either an art box or a trim box must be defined for each ream.  The bleed box is optional and can be used with either the art box or the trim box.  Art boxes and trim boxes must be contained within the page, and also within the bleed box, if the bleed box is defined.

The _rotation_ property defines the orientation of the page.  The idiomatic way of handling landscape orientation in PDF files is to define the page in portrait orientation and then rotate it.  The valid rotation values are 0, 90, 180, and 270 degrees clockwise.  Transformation objects can be used to convert coordinates between landscape orientation and rotated portrait orientation.

### Color objects

Color objects represent the color that is used for drawing text and graphics.  All colors are specified in Cyan-Magenta-Yellow-Black (CMYK), with the value for each channel in range [0, 255].  The specific details of the CMYK color space are not defined, so the colors will vary depending on how the printer interprets CMYK.

You can get grayscale colors by using the black (K) channel and leaving the CMY channels zero.  Setting the K channel to 255 is full black.  The following table shows basic colors that can be achieved by simple combinations:

      Color  |  C  |  M  |  Y  |  K
    =========+=====+=====+=====+=====
     black   |   0 |   0 |   0 | 255
     yellow  |   0 |   0 | 255 |   0
     magenta |   0 | 255 |   0 |   0
     red     |   0 | 255 | 255 |   0
     cyan    | 255 |   0 |   0 |   0
     green   | 255 |   0 | 255 |   0
     blue    | 255 | 255 |   0 |   0

Embedded image objects handle their colors separately.

### Stroke objects

Stroke objects define the details of how paths are stroked.  Stroke objects apply both to stroking paths objects and to stroking the outlines of glyphs from a font in column objects.  The following parameters are stored in stroke objects:

1. Color object
2. Width of stroke in points
3. Cap style (`ButtCap`, `RoundCap`, or `SquareCap`)
4. Join style (`MiterJoin`, `RoundJoin`, or `BevelJoin`)
5. Miter limit ratio (for `MiterJoin` only)
6. Dash pattern array
7. Dash pattern phase

The most basic parameters of stroke objects are a color object defining the color of the stroke and the width of the stroke lines in points.

The next parameter defines how to render the end caps of strokes.  This parameter also applies to the ends of dashes if a dashing pattern is defined (see below).  The three possibilities are represented by the Scent atoms `ButtCap`, `RoundCap`, and `SquareCap`.  For a `ButtCap`, the stroke ends abruptly with a straight edge, making it appear as though the stroke were made by a flat-tipped pen.  For `RoundCap`, the stroke is closed off with a half circle, making it appear as though the stroke were made by a round-tipped pen.  `SquareCap` is similar to `ButtCap`, except the stroke proceeds half a line width further than the end of the stroke, making it appear as though the end of the stroke has been squared off.

The stroke object also defines what happens at corners within the stroke.  The three possibilities are represented by the Scent atoms `MiterJoin`, `RoundJoin`, and `BevelJoin`.  A `RoundJoin` rounds the corner, making it appear as though it were stroked with a round-tipped pen.  A `BevelJoin` draws the two edges that meet at the corner as if both edges were separate lines with `ButtCap` at the ends of them.  Then, any remaining space is filled in with a triangle.  The `BevelJoin` looks like a straight-edge join where the tip has been removed.  Finally, the `MiterJoin` extends the outer sides of both edges that meet at the corner until the outer edges meet at a point.  The `MiterJoin` yields the visual appearance of straight lines meeting at a sharp point.

However, the `MiterJoin` has bad boundary conditions.  If the angle between the two edges is too small, the line extensions needed to make the corner tip will extend too far.  For this reason, the `MiterJoin` requires a _miter limit ratio._  Let the _miter length_ be the distance between the inner point at which the two edges meet and the outer point at which the two edges meet if they were joined with a miter.  If the ratio of the miter length to the line width exceeds the miter limit ratio, then a `BevelJoin` will be used instead of the `MiterJoin` for that connection, to avoid an overly-long miter join.

The miter limit ratio can be computed from the minimum angle supported for miters.  To perform this computation, use the following formula:

                           1
    miter limit ratio = --------
                        sin(a/2)

where `a` is the minimum angle supported for miters.  Any lines that meet at an angle less than `a` will be rendered with a `BevelJoin` while any lines meeting at an angle greater than or equal to `a` will be rendered with a `MiterJoin`.  An operator is provided that can perform this computation.

The final stroke parameters are used for creating dashed lines.  The _dash pattern array_ defines the pattern of dashes.  This is an array of zero or more distances that are greater than zero.  If the dash pattern array is empty, then the stroke is one continuous line with no dashing.  If the dash pattern array has a single element, then the line is dashed with alternating dashes and gaps each having the length in points given as the array element.  If the dash pattern array has two or more elements, then it must have an even number of elements.  The first element in each pair is the length of a dash and the second element in each pair is the length of a gap.  The pattern is cycled through as many times as necessary to cover the full length of the stroke path.

If the dash pattern array is not empty, then there is also the _dash pattern phase_ parameter.  This is a length in points that is zero or greater.  At the beginning of the stroke, the dash pattern will start as though a distance of the dash pattern phase has already been stroked.  This allows the position within the dash pattern to be controlled.

### Font objects

Font objects represent the fonts that text can be rendered with.  There are two types of fonts:

1. Built-in fonts
2. TrueType/OpenType fonts

The built-in fonts are fonts that are available on all PDF implementations.  The built-in fonts are as follows:

- `Courier`
- `Courier-Bold`
- `Courier-BoldOblique`
- `Courier-Oblique`
- `Helvetica`
- `Helvetica-Bold`
- `Helvetica-BoldOblique`
- `Helvetica-Oblique`
- `Symbol`
- `Times-Bold`
- `Times-BoldItalic`
- `Times-Italic`
- `Times-Roman`
- `ZapfDingbats`

All built-in fonts except `Symbol` and `ZapfDingbats` can only be assumed to support the subset of Unicode codepoints covered by Windows-1252.

The PDF specification has an appendix containing all the symbols supported by the built-in `Symbol` and `ZapfDingbats` fonts.  However, Scent expects these symbols to be encoded in Unicode, rather than with the special encoding systems defined by the PDF specification.  Use the `glyphcode.pl` utility script provided by Scent to figure out the Unicode codepoints for characters in the `Symbol` and `ZapfDingbats` fonts.

Scent also supports TrueType and OpenType fonts.  You can load these fonts by providing the path to the font file.  TrueType and OpenType fonts will be embedded in the PDF file.  Kerning information, if provided by the font, will be used.  Scent will use the font's defined mapping of Unicode codepoints to glyphs, and this also functions correctly for codepoints in the supplemental range.  However, Scent's implementation of TrueType and OpenType has some important limitations.

The first limitation is that Scent always renders glyphs in left-to-right order.  If you want right-to-left text or bidirectional text, you need to reverse and reorder the codepoints so that they are in left-to-right order when they are passed to Scent.  If you want vertical text, you will somehow need to reorder the printing so that Scent can print everything in left-to-right, top-to-bottom order.  For example, if the vertical text forms a grid of square characters, you can iterate through this grid in left-to-right, top-to-bottom order when passing the codepoints to Scent.

The second limitation is that Scent uses a naive mapping of Unicode codepoints to glyphs.  In particular, Scent does not support complex shaping and context-sensitive selection of different glyphs for the same codepoint.  Scent also does not support automatically choosing ligatures.  To handle these cases, each individual glyph must have its own unique Unicode codepoint.  (You can make use of private Unicode codepoints if there are no official Unicode codepoints for specific glyphs.)  The text must then be shaped and mapped to these glyph-specific Unicode codepoints before passing the text into Scent.

### Image objects

Image objects represent a raster image file that is embedded in the PDF file.

Image objects are specified to Scent by a path to either a JPEG or PNG file.  However, only limited subsets of JPEG and PNG are supported by Scent due to limitations of PDF.  It is strongly recommended to use the `image_recode.pl` script to re-encode JPEG and PNG images for maximum compatibility.

The choice of JPEG or PNG file will determine the compression method used within the PDF file.  JPEG images will use DCT compression in the PDF file, where PDF's DCT compression method has been defined to match JPEG baseline.  PNG images will use Flate compression in the PDF file, where PDF's Flate compression method has been defined to match PNG compression, including PNG's predictor functions.

For JPEG files, the encoded colorspace must either be Grayscale or YCbCr.  The YCbCr colorspace will automatically be converted into RGB when the image is decompressed from the PDF file for display or printing.  Although some JPEG variants allow CMYK color, Scent does not support CMYK JPEG files.

For PNG files, the encoded colorspace must either be Grayscale, RGB, or Indexed-RGB.  PDF is capable of storing indexed (palette) images.  However, the alpha channel may _not_ be used.

None of the color channels stored in the provided JPEG or PNG images may exceed 8 bits per sample.  Interlacing or progressive display may not be used.

In the PDF file, the colorspace of grayscale images will be set to `DeviceGray` and the colorspace of color images will be set to `DeviceRGB`.  Color profile information that might be stored in the JPEG or PNG files is ignored.  No guarantees are made about the specific colorspace that is used for display or printing.  The most portable strategy is to use the sRGB colorspace and hope for the best.

Resolution information that may be present in the JPEG or PNG files is ignored.

### Path objects

Path objects are used to outline shapes that are stroked or filled for creating graphics.  Path objects are _not_ used for representing the shape of text, which is handled separately.

A path object is a sequence of one or more _subpaths._  Each subpath is either a _rectangle_ or a _motion._  Rectangles are specified by their lower-left corner and a width and height.  For purposes of the nonzero winding rule, rectangle edges move counterclockwise.  Motions are specified by the following information:

1. Starting point of the motion
2. Sequence of one or more lines or curves
3. Whether or not the motion is closed

The current point of the motion is set to the starting point at the beginning of the motion.  Each line or curve uses the current point as its starting point, and after each line or curve finishes, the current point is updated to the endpoint of the line or curve.  Curves are always cubic Bezier curves.  If a motion is closed, then at the end of the motion a straight line is drawn back to the starting point of the motion if necessary to make it a closed shape.

To determine which points are inside a path for purposes of filling, Scent supports both the _nonzero winding rule_ and the _even-odd rule._  Each path object stores which of these two rules it is designed for.  Note that the rule only has an effect if the path is filled or used as a clipping path.  If the path is only stroked, the rule is irrelevant and has no effect on the output.  Scent also defines the _null rule,_ which means that the path can only be stroked, and an error occurs if the path is filled or used for clipping.

Suppose the entire path is drawn on an area large enough to contain it, and drawn in a way that each stroke shows which direction it moves in.  Suppose you want to know whether a point P in the area is contained within the path.  Start at point P and move to the edge of the area.  As you move to the edge of the area, remember which edges you crossed and which directions the edges were heading in.

For the nonzero winding rule, start with a value of zero.  Each time you cross an edge that moves from left to right, add one to the count.  Each time you cross an edge that moves from right to left, subtract one from the count.  If the total count when you reach the edge of the area is zero, then the point P that you started at is not within the path.  In all other cases, the point P is within the path.

For the even-odd rule, just count the total number of edges that you cross while moving from point P to the edge of the area.  If you don't cross any edges or you cross an even number of edges, P is outside the path.  Otherwise, if you cross an odd number of edges, P is inside the path.

### Transform object

Transform objects are used to alter the coordinate system.

By default, the origin of the coordinate system is the bottom-left corner of the page, the X axis points rightwards, and the Y axis points upwards.  Sometimes, this default coordinate system is not convenient.  For example, on a landscape orientation page that is represented by a portrait page rotated 90 degrees clockwise, one may want the origin of the coordinate system to be the bottom-right corner of the unrotated page, the X axis to point upwards on the unrotated page, and the Y axis to point leftwards on the unrotated page.

Transformation objects can be provided to drawing operations to change the coordinate system used for that drawing operation.  The simplest transformation is the _identity_ transform which just leaves the axes at their default.  If a null value is provided in place of a transformation object, the identity transform will be assumed.

Scent provides three different transformations for changing the axes.  The _translation_ transform changes the origin of the coordinate system to a different location.  The location of the new origin is specified relative to the current coordinate system.  The _rotation_ transform rotates the axes counterclockwise around the origin of the current coordinate system.  The _scaling_ transform changes the size of units on the X and Y axes relative to their current scale.

Transformations can be combined in any way.  Note that the order of transformations is significant.  That is, translating and then rotating does not produce the same result as rotating and then translating.  Generally, if you want to change the coordinate system with translation, rotation, and scaling, you should usually perform translation first, rotation second, and scaling third.

### Style object

Style objects represent the style of how text is rendered.

Text style objects have the following parameters:

- Font object selecting the font to use
- Font size in points
- Extra space to add to each glyph
- Extra space to add to each space character
- Baseline vertical adjustment
- Horizontal scaling of font glyphs
- Stroke object or null for no stroking
- Color object for fill or null for no filling

The two extra space parameters allow for character spacing and word spacing adjustment.  The extra space is specified as an absolute measurement in points, independent of the font and font size.  Both properties are useful for justifying text to fill a given width.

The baseline vertical adjustment is an absolute measurement in points, independent of the font and font size.  It is useful for superscripts and subscripts.

Horizontal scaling allows glyphs within the fonts to be horizontally stretched or squeezed.

The stroke object and fill color object determine how the glyphs of the font are stroked and/or filled.  Both can be defined, one of the two can be null, or both can be null.  (Setting both to null is useful when using text purely for defining clipping areas.)

### Column object

Column objects represent a sequence of text operations that place text on the page using fonts.

The column object has an array of one or more _text lines._  Each text line defines its starting, leftmost baseline point and contains an array of one of more _text spans._  Each text span contains a Unicode string defining what text to render in the span and a text style object that determines the appearance of this text.  After each span is rendered, the next span begins where the previous span left off.

Baseline adjustments due to the baseline vertical adjustment parameter of text style objects only apply within a span.  They do not affect the baseline of any spans that follow.

### Clipping object

_Clipping objects_ define clipping areas.  Clipping areas can be used in any rendering operation to limit the areas on the page that are affected.  Only points on the page that are contained within the clipping area are rendered.  All points outside the clipping area are discarded.

Clipping objects contain a set of _clip components._  Each clip component contains either a path or a column object.  Each clip component also contains a transform object.  To generate the clipping area, begin with an area containing the whole printing area of the page.  For each clip component, project the clip component onto the page using the transform object and then reduce the clipping area to only those points that are present both in the current clipping area and in the projected clip component area.  The order of clip components does not matter.  The final clipping area is the intersection of the page area with each of the clipping areas.

(Recall, however, from the discussion under ream objects that the small region along the edge of the paper can not be printed, regardless of the clipping area.)

For clip components containing paths, the clipping region defined by the path is the same as the region that would result if the path were filled.  For clip components containing columns, the clipping region defined by the column is the same as the region that would result if each of the rendered glyphs were filled.

It is possible to use a null value in place of a clipping object.  The null value always refers to the whole printing page area without any clipping in effect.

## Interpreter state

The Shastina interpreter used by Scent has an interpreter stack as well as a namespace for storing defined variables and constants.  Both variables and constants share the same namespace.

The interpreter stack at the end of interpretation must be empty.

In addition to the Shastina state, the Scent interpreter also has a _page register._  The page register starts out set to the null value.  When a page is defined, the page register holds the ream object representing the current page and it also has internal state representing the page object that will be stored in the PDF file.  At the end of each page, the register is cleared back to the null value.

The page register is only present in standalone Scent files.  It is not used in embedded Scent files.

There is also an _accumulator register._  The accumulator is used for building complex objects in a sequence of operators.  Once the complex object has been fully defined in the accumulator, the completed object is pushed onto the interpreter stack and the accumulator is cleared.  Only one complex object may be built in the accumulator at a time.

The page and accumulator registers must be null at the end of interpretation.

## Shastina entities

After the header, the following Shastina entities are supported:

`EOF` is used to mark the end of interpretation.  Nothing after the `|;` token at the end of the file is read or parsed.

`STRING` is used both for pushing string literals on the interpreter stack and for pushing atoms on the stack.  Double-quoted strings push atoms, and the double-quoted value must be a case-sensitive match for an atom known to Scent.  (The atoms are defined in various locations in this specification.)  Curly-quoted strings push Unicode strings onto the stack.  The following escape codes are allowed within curly-quoted strings:

    \\ - literal backslash
    \{ - unbalanced left curly
    \} - unbalanced right curly
    \. - break to next line (see below)
    \n - Line Feed (LF)
    \u####   - Unicode codepoint with four digits
    \U###### - Unicode codepoint with six digits

Nested curly brackets are allowed unescaped within curly-quoted strings so long as they are properly balanced.  For unbalanced curly brackets, use the escape codes shown above.  The `\u` and `\U` escapes allow specific Unicode codepoints to be inserted; the only difference is that the lowercase version takes four base-16 digits while the uppercase version takes six base-16 digits.  Line breaks encountered within the curly-quoted string are included as an LF character in the string literal.  However, if the `\.` escape is used, then the escape and everything following it up to the next LF or the end of the string (whichever comes first) is discarded, including the next LF.  This allows long lines to be broken over multiple lines in the Scent source file.

No string prefixes are allowed.

`NUMERIC` is used to push integer literals on the stack.  Integer literals begin with an optional `+` or `-` sign, followed by a sequence of one or more decimal digits.  The supported range of values is [-9007199254740991, 9007199254740991].

`VARIABLE` and `CONSTANT` are used to declare variables and constants, respectively.  The name of the variable or constant must be a sequence of one to 31 ASCII alphanumerics and underscores, with the first character not being a decimal digit.  Names are case sensitive, and both variables and constants share the same namespace.  It is an error to attempt to declare the same name more than once.  Both `VARIABLE` and `CONSTANT` pop a value off the stack that is used to initialize the value of the variable or constant.

`ASSIGN` pops a value off the stack and replaces the named variable's value with this new value.  The name used in the `ASSIGN` entity must belong to a variable and not a constant, and it must already have been declared.

`GET` pushes a copy of the value stored in the named variable or constant onto the interpreter stack.  The named variable or constant must have already been declared.

`BEGIN_GROUP` and `END_GROUP` support grouping operations on the stack.  When a group begins, everything on the stack is hidden.  When a group ends, there must be exactly one value on the non-hidden part of the stack or there will be an error.  After the group ends, the visibility of items on the stack is restored to what it was before the group began.  Groups may be nested.

`ARRAY` pushes an integer on the stack counting the number of elements in the array.

`OPERATION` performs an operation using data on the interpreter stack.  The operations supported by Scent are described in the next section.

## Scent operations

The following subsections document all the operations that are available to Scent scripts.  The format of each operator is given as follows:

    [arg_1:type] ... [arg_n:type] opname [result_1:type] ... [result_n:type]

The name of the operation (`opname`) is given in the middle.  To the left of the operation name are the arguments that must be present on the stack when the operation is invoked, along with the type of each argument.  `[arg_n]` is the argument on top of the stack.  All of the arguments are popped off the stack by the operation.  To the right of the operation name are the results that are pushed back on the stack after the operation completes, along with their types.  `[result_n]` is the argument on top of the stack.

If an operation has no arguments, there will be a single hyphen to the left of the operation name.  If an operation has no results, there will be a single hyphen to the right of the operation.  If an operation has neither arguments nor results, the operation name will be surrounded by hyphens.

For each of the operation subsections that concern a specific kind of object, see also the corresponding object documentation earlier in this specification for more information.

Operations with a lot of arguments and/or results might split their definitions across multiple lines.

### Basic operations

    [x:any] pop -
    [x:any] dup [x:any] [x:any]

The `pop` operation simply discards the top element from the stack, which may have any type.  The `dup` operation pushes another copy of the top element of the stack onto the stack.

    - null [x:null]

The `null` operation pushes the null value on top of the stack.

    [s1:string] ... [sn:string] [n:integer] concat [result:string]

The `concat` operation takes an array of zero or more strings as input and pushes a new string onto the stack that has all the codepoints of the those strings combined.  If the input array is empty, the resulting string will be an empty string with no codepoints.

    - sep [result:string]

The `sep` operation pushes a string onto the stack that contains the platform-specific separator character for use in building paths.  On Windows this is a backslash, while on other platforms this is a forward slash.

### Ream operations

_Ream operations may not be used in embedded Scent files._

Ream objects are built in the accumulator register.  The following operations mark the boundaries of the definition:

    - start_ream -
    - finish_ream [result:ream]

When the `start_ream` operation is invoked, the accumulator register must be empty.  The accumulator is filled with the start of a new ream object definition.  All other operations within this section may only be used while the accumulator is filled with part of a ream object definition.  When the ream object has been fully defined in the accumulator, `finish_ream` pushes the completed ream object onto the interpreter stack and clears the accumulator register.

The paper dimensions of the ream in the accumulator are set with the following operation:

    [w:fixed] [h:fixed] ream_dim -

Both `[w]` and `[h]` are fixed-point values greater than zero that are measured in points, defining the width and height of the paper.  The width and height refer to the unrotated page.  For pages in landscape orientation, the idiomatic way of doing that is to define the paper dimensions in portrait orientation and then use a rotation (see below).  Paper dimensions must be defined before the ream object is finished.  If paper dimensions are already defined, this operation will overwrite any dimensions currently in the accumulator.

The paper rotation of the ream in the accumulator is set with the following operation:

    [rot:integer] ream_rotate -

The `[rot]` is an integer value of either 0, 90, 180, or 270, defining how the page is rotated clockwise to display it.  For landscape orientation of a page, you should normally define the page as if it were in portrait orientation, then set a `[rot]` value of 90 or 270 and apply appropriate transformations to rendering operations.

By default, `start_ream` sets the rotation of the ream to zero, so you do not need to use this operation if you do not require any rotation.  Each time this operation is invoked, it replaces any currently defined rotation value.

Boundary boxes of the ream in the accumulator are set with the following operation:

    [left:fixed] [right:fixed]
    [top:fixed] [bottom:fixed]
    [type:atom] ream_bound -

The `[type]` atom must be either `ArtBox`, `TrimBox`, or `BleedBox`.  The rest of the parameters define the distance between an edge of the unrotated paper and an edge of the selected boundary box.  Each distance must be greater than zero.

The `start_ream` operation does not define any boundary boxes.  Use the `ream_bound` operator to define one or more boundary boxes.  Attempting to define a specific boundary box more than once is allowed, but the new definition will just replace the old definition.

When `finish_ream` is invoked, either an `ArtBox` or a `TrimBox` must be defined, but not both.  The `BleedBox` is optional.  For each defined box, the left and right margins added together must be less than the page width, and the top and bottom margins added together must be less than the page height.  If a bleed box is defined, each margin in the art box or trim box must be greater than the corresponding margin in the bleed box.  All of these validity checks are performed only when `finish_ream` is invoked.

You can remove a defined boundary box with the following operation:

    [type:atom] ream_unbound -

The `[type]` atom must be either `ArtBox`, `TrimBox`, or `BleedBox`.  The named boundary box is removed from the ream currently in the accumulator.  This operation is useful when deriving reams from existing reams.

If you want to derive a new ream object from an existing ream object, use `start_ream` to start an new ream definition and then use the following operation:

    [source:ream] ream_derive -

This operation completely discards all ream information currently in the accumulator and replaces the information to match the provided source ream object.  After `ream_derive` has been invoked, you can then edit the ream state and use `finish_ream` to produce the derived ream object.

### Page operations

_Page operations may not be used in embedded Scent files._

In order to add a page to the output PDF file, use the following operations:

    [paper:ream] begin_page -
    - end_page -

Each `begin_page` operation must have a matching `end_page` operator, and page definitions may not be nested.  A ream object is passed to the `begin_page` operation to determine the size and boundaries of the page.

When `begin_page` is invoked, the page register must be empty.  It is filled with the start of a new page definition, which includes the passed ream object.  Each time a display operation is performed, it adds content to the page in the page register.  When `end_page` is invoked, the page and all its content is output to the PDF file.

### Color operations

The following operations define colors:

    [g:integer] gray [c:color]
    [c:integer] [m:integer] [y:integer] [k:integer] cmyk [c:color]
    [gf:fixed] fgray [c:color]
    [cf:fixed] [mf:fixed] [yf:fixed] [kf:fixed] fcmyk [c:color]

The `gray` and `fgray` operators are used for grayscale colors, where a value of zero is black and a maximum value is white, to match the usual grayscale definition.  The grayscale operations are equivalent to using the `cmyk` or `fcmyk` operations, setting the CMY channels to zero, and setting the K channel to the inverse of the grayscale value (so that K is zero when grayscale is at maximum and K is at maximum when grayscale is zero).  In other words, the result of the color operations is always a CMYK color, with grayscale values automatically converted.

The `cmyk` and `fcmyk` operations allow a CMYK color to be defined using all color channels.  No guarantees are made about the specific color space, except that the general meaning of the color channels are Cyan, Magenta, Yellow, and Black.

The difference between the `f` and non-`f` versions of the grayscale and CMYK operations is the type of arguments they take.  The non-`f` versions take integers, which must each be in the range [0, 255].  The `f` versions take fixed-point values, which must be in the range [0, 1.0].  The output color object always uses integer values, so fixed-point values will be automatically scaled to the integer range.

### Stroke operations

Stroke objects are built in the accumulator register.  The following operations mark the boundaries of the definition:

    - start_stroke -
    - finish_stroke [result:stroke]

When the `start_stroke` operation is invoked, the accumulator register must be empty.  The accumulator is filled with the start of a new stroke style object definition.  All other operations within this section may only be used while the accumulator is filled with part of a stroke style object definition.  When the stroke style object has been fully defined in the accumulator, `finish_stroke` pushes the completed stroke object onto the interpreter stack and clears the accumulator register.

For each stroke in the accumulator, you must use the following operation to set the width of the stroke:

    [w:fixed] stroke_width -

The `[w]` parameter is the width of the stroke in points, which must be greater than zero.  If a stroke width has already been defined for the object in the accumulator, the new value replaces the old one.  You must define a stroke width before `finish_stroke` is called, because there is no default value.

The following operation sets the color of the stroke:

    [c:color] stroke_color -

The `[c]` parameter is the color object defining the color to use for the stroke.  By default, `start_stroke` sets the stroke color to black (as if created by `0 gray`), so you do not need to use this operation unless you want a color other than black.  A newly-defined stroke color replaces any currently defined stroke color.

The following operation sets the line capping style:

    [v:atom] stroke_cap -

The `[v]` parameter must be either `ButtCap`, `RoundCap`, or `SquareCap`.  By default, `start_stroke` sets the line cap style to `RoundCap`.  A newly-defined line cap style replaces any currently defined line cap style.

The following operations set the line join style:

    [v:atom] stroke_join -
    [r:fixed] [v:atom] stroke_join_r -

The `[v]` parameter must be either `MiterJoin`, `RoundJoin`, or `BevelJoin`.  The `MiterJoin` must use the `stroke_join_r` operation, while the `RoundJoin` and `BevelJoin` must use the `stroke_join` operation.  The `stroke_join_r` operation also takes a fixed-point parameter greater than zero which defines the miter limit ratio.  If you want to compute this ratio from an angle, the following operation is available:

    [angle:fixed] miter_angle [ratio:fixed]

The `[angle]` must be in range [0.01, 180.0], specified in degrees.  The computed ratio can then be used for the `[r]` parameter of `stroke_join_r`.  The `miter_angle` operation does _not_ require a stroke object to be in the accumulator, since it does not alter or refer to the stroke object state in any way.

By default, the join style is set to `RoundJoin` by `start_stroke`.  A newly-defined join style replaces any currently defined join style.

The following operation sets a dashed-line pattern:

    [d1:fixed] ... [dn:fixed] [n:integer] [p:fixed] stroke_dash -

The array `[d1]` through `[dn]` can be defined with the Shastina array facility, which will then automatically compute and push the `[n]` parameter.

The array must have at least two values, and the total number of values must be an even number.  Values in the array are paired, with the first value in each pair storing the length in points of a dash and the second value in each pair storing the length in points of a gap.  All lengths in the array must be greater than zero.

The dash pattern will be cycled through as many times as is necessary to cover the full distance of the subpath that is being stroked.  The `[p]` parameter controls where we are in the pattern at the beginning of the subpath.  At the beginning of the subpath, the dash pattern will be positioned as if a distance of `[p]` points had already been covered.  `[p]` must be greater than or equal to zero.

To remove a dashed-line pattern, use the following operation:

    - stroke_undash -

By default, stroke objects do not have any dashed-line pattern when they are created in the accumulator register, which means that the whole subpath is stroked in one continuous stroke.

If you want to derive a new stroke object from an existing stroke object, use `start_stroke` to start an new stroke style definition and then use the following operation:

    [source:stroke] stroke_derive -

This operation completely discards all stroke information currently in the accumulator and replaces the information to match the provided source stroke object.  After `stroke_derive` has been invoked, you can then edit the stroke state and use `finish_stroke` to produce the derived stroke object.

### Font operations

The following operation defines built-in fonts:

    [name:atom] font_get [result:font]

The `[name]` argument is one of the following atoms:

- `Courier`
- `CourierBold`
- `CourierBoldOblique`
- `CourierOblique`
- `Helvetica`
- `HelveticaBold`
- `HelveticaBoldOblique`
- `HelveticaOblique`
- `Symbol`
- `TimesBold`
- `TimesBoldItalic`
- `TimesItalic`
- `TimesRoman`
- `ZapfDingbats`

The font object will represent the named built-in font.  Note that the atom names do not use hyphens, so they are not identical to the built-in font names.  If the same built-in font is loaded more than once, subsequent invocations of `font_get` will just return the same object for that particular built-in font that was returned earlier.

The following operation defines TrueType and OpenType fonts:

    [path:string] [name:string] font_load [result:font]

The `[path]` is the file system path to the TrueType or OpenType font file.

The `[name]` is a unique name that is assigned to this particular font when it is loaded.  If a `font_load` statement is run that uses a `[name]` that has already been defined, the provided path is ignored and the operation just returns the same font object that was returned earlier for that given `[name]`.  This ensures that the same font is not loaded more than once.

All types of fonts (built-in, TrueType, and OpenType) are interchangeable after they have been wrapped in font objects.

### Image operations

The following operation defines an image object:

    [path:string] [type:atom] [name:string] image_load [result:image]

The `[path]` is the file system path to either a JPEG or PNG file.  The `[type]` atom is either `JPEG` or `PNG`, selecting the type of image file.

The `[name]` is a unique name that is assigned to this particular image when it is loaded.  If an `image_load` statement is run that uses a `[name]` that has already been defined, the provided path and type are ignored and the operation just returns the same image object that was returned earlier for that given `[name]`.  This ensures that the same image is not loaded more than once.

It is strongly recommended to use the `image_recode.pl` script on the image files you are planning on embedding.  This minimizes the chance of the image using weird encoding settings that may cause problems when they are embedded in the PDF file.

### Path operations

Path objects are built in the accumulator register.  The following operations mark the boundaries of the definition:

    - start_path -
    [rule:atom|null] finish_path [result:path]

When the `start_path` operation is invoked, the accumulator register must be empty.  The accumulator is filled with the start of a new path object definition.  All other operations within this section may only be used while the accumulator is filled with part of a path object definition.  When the path object has been fully defined in the accumulator, `finish_path` pushes the completed path object onto the interpreter stack and clears the accumulator register.

The `finish_path` operation requires a `[rule]` atom that is either `Nonzero` or `EvenOdd`, or it may be the null value if the path will never be used for filling or as a clipping path.  This determines the rule for checking whether a point is "inside" the path or not.

When the accumulator is building a path object, it may be either in _initial mode_ or _subpath mode._  When `start_path` is first invoked, the path is in initial mode.  The path must be in initial mode when `finish_path` is called or an error occurs.

Subpath mode is used for appending a motion subpath to the path in the accumulator.  The following operations enter and exit subpath mode:

    [x:fixed] [y:fixed] start_motion -
    - finish_motion -
    - close_motion -

The `start_motion` operation may only be used when there is a path in the accumulator that is in initial mode.  The `[x]` and `[y]` arguments indicate the starting point of the motion.  The path in the accumulator will be switched to subpath mode.

The `finish_motion` and `close_motion` operations may only be used when there is a path in the accumulator that is in subpath mode _and_ at least one line or curve has been added to it.  Both operations finish the current motion and return the path in the accumulator to initial mode.  The difference between the two is that `close_motion` will close the subpath before adding it, while `finish_motion` will not close the subpath.

The following operations add lines and curves to a motion:

    [x2:fixed] [y2:fixed] motion_line -
    
    [x2:fixed] [y2:fixed]
    [x3:fixed] [y3:fixed]
    [x4:fixed] [y4:fixed] motion_curve -

The `motion_line` operation adds a line from the current point to the given coordinates and then updates the current point to the given coordinates.  The `motion_curve` adds a cubic Bezier curve where the starting point is the current point, (X2, Y2) and (X3, Y3) are the control points, and (X4, Y4) is the end point; then, it updates the current point to (X4, Y4).

When the accumulator holds a path object that is in initial mode, you can add a subpath representing a closed rectangle using the following operation:

    [x:fixed] [y:fixed] [w:fixed] [h:fixed] path_rect -

`[x]` and `[y]` are the bottom-left coordinates of the rectangle, and `[w]` and `[h]` are the width and height of the rectangle.  The width and height must both be greater than zero.  The rectangle edges move counterclockwise for purposes of the nonzero winding rule.

When the accumulator holds a path object that is in initial mode, you can append all the subpaths of an existing path object to it using the following operation:

    [source:path] path_include -

All the subpaths from the `[source]` path object will be copied into the path object in the accumulator.  Note that the fill rule is _not_ copied.

### Transform operations

Transform objects are created with operations detailed in this section.

    - tx_identity [result:transform]

Creates an identity transform that does not perform any transformation.

    [x:fixed] [y:fixed] tx_translate [result:transform]

Creates a translation transform that moves the origin of the coordinate system to the point `(x, y)` relative to whatever is the current coordinate system.

    [rot:fixed] tx_rotate [result:transform]

Creates a rotation transform that rotates the X and Y axes counterclockwise by `[rot]` degrees around the origin of whatever is the current coordinate system.

    [sx:fixed] [sy:fixed] tx_scale [result:transform]

Creates a scaling transform that scales the units on the X axis by `[sx]` and the units on the Y axis by `[sy]`.

A sequence of transformations can be combined as follows:

    [m1:transform] ... [mn:transform] [n:integer] tx_seq [result:transform]

The `[result]` transformation has the same effect as applying `m1...mn` transformations in that order.  If the given sequence of transformations is empty, an identity transform is produced.

### Style operations

Text style objects are built in the accumulator register.  The following operations mark the boundaries of the definition:

    - start_style -
    - finish_style [result:style]

When the `start_style` operation is invoked, the accumulator register must be empty.  The accumulator is filled with the start of a new text style object definition.  All other operations within this section may only be used while the accumulator is filled with part of a text style object definition.  When the text style object has been fully defined in the accumulator, `finish_style` pushes the completed style object onto the interpreter stack and clears the accumulator register.

The basic parameters of the text style are set with the operations, which affect the text style object currently in the accumulator:

    [f:font]  style_font -
    [s:fixed] style_size -
    [s:stroke|null] style_stroke -
    [s:color|null]  style_fill   -

Each of these four parameters start out in a special undefined state that must be somehow set before the `finish_style` operation or an error occurs.  The font size is specified in points, which must be greater than zero.  If the stroke is set to null, then the glyphs will not be stroked.  If the fill is set to null, then the glyphs will not be filled.

Each remaining parameter is optional, having default values that are set when the style object begins.

    [s:fixed] style_cspace -
    [s:fixed] style_wspace -

These two operations set the character space and word space, respectively.  Both take a distance measured in points, which must be zero or greater.  The character space is added to each glyph.  The word space is only added to the space glyph for ASCII space codepoint U+0020.  The default values of zero mean that there is no extra space, and each glyph has its regular spacing.  Values greater than zero add extra space.  This is especially useful for justifying text.

    [r:fixed] style_rise -

This operation sets the baseline vertical adjustment.  The default value of zero means that text in this style uses the same baseline as the rest of the line.  Values greater than zero move the text baseline higher than the regular baseline, creating a superscript effect.  Values less than zero move the text baseline lower than the regular baseline, creating a subscript effect.  The value `[r]` is measured in points.

    [s:fixed] style_hscale -

This operation sets the horizontal scaling value.  `[s]` is a percent value that must be greater than zero.  The default value of 100 means that each glyph is displayed normally.  Values less than 100 squeeze glyphs horizontally while values greater than 100 stretch glyphs horizontally.

To derive a new style from an existing style, create a new style with `start_style` and then use the following operation:

    [source:style] style_derive -

This operation replaces the text style currently in the accumulator register with all the parameters read from the given `[source]` text style.  You can then edit whichever individual parameters you want in the accumulator.

For justifying text, it is often necessary to derive new styles that just adjust the character and/or word spacing of an existing style.  The following operations are shortcuts that can derive a style in a single operation without using the accumulator:

    [source:style] [ws:fixed] style_setw [result:style]
    [source:style] [ws:fixed|null] [cs:fixed|null] style_setwc [result:style]

The `style_setw` takes a source text style object, copies it to a new style, and changes the word spacing in the new style to the given `[ws]` value.  The new style is then pushed onto the stack as the `[result]`.

The `style_setwc` takes a source text style object, copies it to a new style, and changes the word spacing and/or character spacing in the new style to the given `[ws]` and `[cs]` values, respectively.  The new style is then pushed onto the stack as the `[result]`.  If null is used in place of a value, that value is not altered.

### Column operations

Column objects are built in the accumulator register.  The following operations mark the boundaries of the definition:

    - start_column -
    - finish_column [result:column]

When the `start_column` operation is invoked, the accumulator register must be empty.  The accumulator is filled with the start of a new column object definition.  All other operations within this section may only be used while the accumulator is filled with part of a column object definition.  When the column object has been fully defined in the accumulator, `finish_column` pushes the completed column object onto the interpreter stack and clears the accumulator register.

When the accumulator is building a column object, it may be either in _initial mode_ or _line mode._  When `start_column` is first invoked, the column is in initial mode.  The column must be in initial mode when `finish_column` is called or an error occurs.  Furthermore, at least one line must have been added to the column when `finish_column` is called.

Line mode is used for appending a line to the column in the accumulator.  The following operations enter and exit line mode:

    [x:fixed] [y:fixed] start_line -
    - finish_line -

The `start_line` operation may only be used when there is a column in the accumulator that is in initial mode.  The `[x]` and `[y]` arguments indicate the starting point of the baseline of this text line.  The column in the accumulator will be switched to line mode.

The `finish_line` operation may only be used when there is a column in the accumulator that is in line mode _and_ at least one span has been added to it.  The operation finishes the current line and returns the column in the accumulator to initial mode.

For a column object in the accumulator in line mode, the following operation is used to append a span to it:

    [text:string] [s:style] line_span -

The `[text]` parameter is the Unicode representation of the text to render in this span, and the `[s]` parameter determines the style in which the text is rendered.

### Clipping operations

The following operation defines a clipping region:

    [s1:path|column|clip] [t1:transform|null]
    ...
    [sn:path|column|clip] [tn:transform|null]
    [m:integer] clip [result:clip]

The clipping region is built out of an array of clipping element pairs.  The value `[m]` is twice the number of clipping elements, since it counts individual array elements.  The first value in each clipping element is either a path object, a column object, or an existing clipping region.  The second value in each clipping element is either a transform to apply to the coordinate system while deriving the region for this element, or null to use the identity transform.  If the array is empty, the result is a clipping region containing the whole page.  Otherwise, the result is the intersection of all clipping element areas.

Paths that are used as clipping elements may not have a null rule.  The region selected by a path is equal to the region that would be filled.  Columns select a region that would result from filling all the glyphs in the column.

The order of elements in the array does not matter.

### Drawing operations

The drawing operations are the only operations that actually produce visible content on the page.  For standalone Scent files, drawing operations can only be used when the page register has a defined page.  For embedded Scent files, there is no page register and drawing operations can always be used.

The order of drawing operations is significant.  Later drawing operations draw on top of earlier drawing operations.

To draw a path, use the following operation:

    [src:path] [s:stroke|null] [f:color|null]
    [t:transform|null] [c:clip|null] draw_path -

The `[src]` is the path object to draw.  `[s]` is either a stroke object defining how the path is stroked, or null if the path will not be stroked.  `[f]` is either a color object defining the color to fill the interior of the path with, or null if the path will not be filled.  `[t]` is how to transform the coordinate system while drawing the path, or null for an identity transform.  `[c]` is the clipping region to limit drawing to, or null to draw on the whole page.

To draw a column of text, use the following operation:

    [src:column] [t:transform|null] [c:clip|null] draw_text -

The `[src]` is the column object specifying the text to draw and the style of the text.  `[t]` is how to transform the coordinate system while drawing the text, or null for an identity transform.  `[c]` is the clipping region to limit drawing to, or null to draw on the whole page.

To draw a raster image, use the following operation:

    [src:image]
    [x:fixed] [y:fixed] [w:fixed] [h:fixed]
    [t:transform|null] [c:clip|null] draw_image -

The `[src]` is the image object specifying the image to draw.  `[x]` and `[y]` give the coordinates of where to place the bottom-left corner of the image, while `[w]` and `[h]` are the width and height of the image in points.  The X, Y, width, and height are relative to the coordinate system established by the `[t]` transform, with a null value for the transform meaning to use the identity transform.  `[c]` is the clipping region to limit drawing to, or null to draw on the whole page.

To draw an embedded Scent file, use the following operation:

    [path:string] [t:transform|null] [c:clip|null] draw_embed -

The `[path]` is the path to the embedded Scent file to draw.  All drawing and clipping transformations in the embedded Scent file will have the `[t]` transformation prefixed to them, and all clipping parameters for drawing operations will be intersected with the `[c]` clipping region.  If `[t]` is null an identity transform is used, while if `[c]` is null the clipping region is the whole page.

Embedded drawings may have multiple levels of nesting.  That is, an embedded drawing may invoke another embedded drawing.  However, there is significant overhead to nested embedding calls, so avoid nesting `draw_embed` commands as much as possible.
