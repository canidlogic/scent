# Scent Specification

Scent is a Shastina dialect that is used for compiling PDF files.  A specification for Shastina is available at [libshastina](https://github.com/canidlogic/libshastina).

## Header

Scent files must begin with the following kind of header:

    %scent 1.0;

More specifically, the first four Shastina entities read from the file must be as follows:

1. `BEGIN_META`
2. `META_TOKEN` with value `scent`
3. `META_TOKEN` with version number
4. `END_META`

The `scent` value is case sensitive.

The version number allows implementations supporting future versions of this specification to remain backwards compatible.  Implementations targeting this specification of Scent should refuse to parse anything that does not have a version exactly matching `1.0`.

## Data types

Scent supports the following data types both on the Shastina interpreter stack and also in variables and constants:

1. Null
2. Integer
3. Fixed-point
4. Atom
5. String
6. Dictionary
7. Ream object
8. Color object
9. Stroke object
10. Font object
11. Image object
12. Path object
13. Transform object
14. Column object
15. Clipping object

The _null type_ includes only a single data value that represents a null, undefined value.

The _integer type_ supports all signed values in the range [-2147483648, +2147483647].  This matches the allowed range for integers set out in the PDF specification.

The _fixed-point type_ supports fractional values.  This is stored as a signed-integer value encoding a fixed-point decimal number with five fractional places after the decimal point.  The smallest supported value that is greater than zero is 0.00001.  The largest supported value is 32767.00000.  The largest supported value that is less than zero is -0.00001.  The smallest supported value is -32767.00000.  This range is very close to the real type defined by the PDF specification.

Integers can be automatically promoted to fixed-point values.  This means that an integer can be used anywhere a fixed-point value is expected, and the integer will be automatically converted to an equivalent fixed-point value.  However, automatic promotion only works for integers in the range [-32767, 32767].  Integers outside that range cause an error if they are used in place of a fixed-point value.

The _atom type_ is used for various special constants.  An atom is a predefined constant string value that is mapped to a unique integer value.  Only the unique integer value needs to be stored on the interpreter stack and as variable and constant values.  However, atoms are not interchangeable with integers or strings.

The _string type_ is used for storing Unicode text.  Strings are stored in memory as binary strings that are UTF-8 encoded.  The maximum string size is 65535 bytes in the binary UTF-8 encoding, which matches the limit given in the PDF specification.

The _dictionary type_ is a mapping of atom keys to values of any type.  It is used especially for passing complex sets of parameters to operations.

The following subsections describe the different object types.

All Scent data types are immutable, which means that once the specific data value is pushed on the stack or stored in a variable or constant value, it will never change.

### Ream objects

A _ream object_ describes the dimensions of a page.  Each page in the PDF file comes from a ream that defines its dimensions.

Ream objects have the following properties:

1. Paper size
2. Boundaries
3. Rotation

The _paper size_ is the physical size of the paper.  Although this size is allowed to be in landscape orientation, the idiomatic way of handling landscape orientation is to define the paper size in portrait orientation and then apply a rotation.  The paper size is given as a width and height in points, where points are exactly 1/72 of an inch.  The follow table shows common paper sizes, their official width and height in millimeters or inches, and their closest approximation in points:

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

The _boundaries_ define the printing areas on the page.  Printers are not able to print close against the edge of the paper.  To work around this problem, there are two different boundary styles that can be defined: simple and complex.

In the simple boundary style, the size of the finished page matches the paper size defined by the ream.  There must be an _art box_ defined that is smaller than the paper size, leaving small margins around the edges of the paper.  Printing will be confined to the art box, allowing the printer to avoid the edges of the paper.  The disadvantage to the simple boundary style is that there must be small blank margins around the edges of the paper, so there is no way for graphics to extend all the way to the edge of the finished page.

In the complex boundary style, the paper size defined by the ream is larger than the desired finished page size.  The _bleed box_ must be smaller than the paper size of the ream, so that the printer can avoid the edges of the paper.  The finished paper size is defined by the _trim box,_ which must be smaller than the bleed box.  After the page is printed on the paper size defined by the ream, the page is sliced to the trim box.  The trimmed page can therefore have graphics that extend all the way to the edge of the finished page.  Since slicing the paper is always somewhat inaccurate, graphics on the edge of the page should extend into the bleed box, to allow for some error in trimming.

The complex boundary style also allows for there to be a trim box but no bleed box.  This is used in cases where the page will be finished by trimming but there is no need for bleed.

The _rotation_ property defines the orientation of the page.  The idiomatic way of handling landscape orientation in PDF files is to define the page in portrait orientation and then rotate it.  The valid rotation values are 0, 90, 180, and 270 degrees clockwise.  Transformation objects can be used to orient display elements from landscape orientation into the rotated portrait orientation.

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

Font objects represent the fonts that text can be rendered with.  There are three types of fonts:

1. Built-in fonts
2. TrueType/OpenType fonts
3. Synthetic fonts

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

The final font type is the synthetic font.  A synthethic font is derived from another font, which may be a built-in font, a TrueType or OpenType font, or another synthetic font.  The derivation allows the original font to be altered in the following ways within the synthetic font:

- **Horizontal scaling:** both squeezing and stretching
- **Obliqueness:** lean glyphs left or right for an oblique effect
- **Boldness:** expand glyph outlines to create a bold effect
- **Small-caps:** replace lowercase letters with small uppercase letters
- **Character spacing:** add more space between glyphs

Synthetic fonts may specify any combination of these alterations.

Deriving a synthetic font A from another synthetic font B that is based on non-synthetic font C works as follows.  Font A will be derived directly from font C.  Any alterations specified by font A are used as-is while ignoring their settings in font B.  Any alterations not specified by font A are inherited from font B if present in font B.

### Image objects

Image objects represent a raster image file that is embedded in the PDF file.  Scent supports JPEG and PNG files, which are imported by path.  Keeping the image files in grayscale is recommended if possible, since PDF may not be able to guarantee the specific RGB colorspace used in printing.  Avoiding an alpha channel in PNG files is also recommended.

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

Transform objects represent a transformation of coordinates from the user coordinates that are provided in path and text operations into page coordinates.  Transforms are stored as a 3x3 matrix.  User coordinates are represented as a vector `[x y 1]`.  These user coordinate vectors are multiplied by the 3x3 transform matrix in order to get a page coordinate vector `[x' y' 1]` that specifies where on the page the coordinate lies.

Within each page, there is an operator that pushes a transform object onto the stack that represents the transformation of oriented page coordinates into the rotated page.  For example, when landscape pages are represented as a portrait page with a rotation in their ream object definition, this page transform operator will push a matrix that transforms coordinates intended for landscape orientation into the rotated portrait page.

Transform objects can be defined by specifying translation, rotation, scale, and skew operations, which are then encoded into a proper transform matrix.  When multiple transform operations are specified at the same time they are always in that order, with translation first and skew last.  Transform objects can also be defined by concatenating a sequence of existing transform objects together.  The resulting transform performs all the transform operations encoded within that sequence of transforms.

### Column object

Column objects represent a sequence of text operations that place text on the page using fonts.

The column object has an array of one or more _text lines._  Each text line defines its starting, leftmost baseline point and contains an array of one of more _text spans._  Each text span contains a Unicode string defining what text to render in the span and a _text style_ that determines the appearance of this text.  After each span is rendered, the next span begins where the previous span left off.

The text style has the following parameters:

- Font object selecting the font to use
- Font size in points
- Extra space to add to each glyph
- Extra space to add to each space character
- Baseline vertical adjustment
- Horizontal scaling of font glyphs
- Stroke object or null for no stroking
- Color object for fill or null for no filling

The two extra space parameters allow for character spacing and word spacing adjustment, respectively.  The extra space is specified as an absolute measurement in points, independent of the font and font size.  Both properties are useful for justifying text to fill a given width.  The default value of each is zero, meaning the normal spacing for the font.

The baseline vertical adjustment is an absolute measurement in points, independent of the font and font size.  It applies only to this specific span.  It is useful for superscripts and subscripts.  The default value is zero, meaning the text is directly on the baseline for the line.

Horizontal scaling allows glyphs within the fonts to be horizontally stretched or squeezed.  The default value is 100, which means 100% width, with each glyph in its customary width.

The stroke object and fill color object determine how the glyphs of the font are stroked and/or filled within the span.  Both can be defined, one of the two can be null, or both can be null.  (Setting both to null is useful when using a column purely for defining clipping areas.)

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

The page register must be null at the end of interpretation.

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

Operations with a lot of arguments and/or results might split their definitions across multiple lines.

### Basic operations

    [x:any] pop -
    [x:any] dup [x:any] [x:any]

The `pop` operation simply discards the top element from the stack, which may have any type.  The `dup` operation pushes another copy of the top element of the stack onto the stack.

    - null [x:null]

The `null` operation pushes the null value on top of the stack.

    [k_1:atom] [v_1:any]
    ...
    [k_n:atom] [v_n:any] [m:integer] dict [d:dictionary]

The `dict` operation creates a dictionary.  The dictionary is defined as a set of zero or more key/value pairs, where the keys must be atoms and the values may be any type.  The order of key/value pairs does not matter.  Each key must be a unique atom.  The argument on top of the stack, `[m]`, must be twice the number of key/value pairs.  This allows it to be computed with a Shastina array:

    ["LeftMargin"  , 72,
     "RightMargin" , 72,
     "TopMargin"   , 72,
     "BottomMargin", 72 ] dict

### Ream and page operations

The following operation creates a ream object:

    [w:fixed] [h:fixed]
    [boundaries:dictionary]
    [rot:integer] ream [r:ream]

The `ream` operation defines a ream object.  See the earlier section for further information about ream objects.

The `[rot]` parameter on top of the stack defines the page rotation.  This must be an integer value of either 0, 90, 180, or 270, defining how the page is rotated clockwise to display it.  For landscape orientation of a page, you should normally define the page as if it were in portrait orientation, then set a `[rot]` value of 90 or 270 and apply appropriate transformations to rendering operations.

Below the rotation parameter is the `[boundaries]` parameter, which must be a dictionary.  This dictionary is actually a dictionary of dictionaries, where the values in the `[boundaries]` dictionary are themselves dictionaries.

The keys in the top-level `[boundaries]` dictionary define the boundary boxes.  The three supported atom keys are `ArtBox`, `TrimBox`, and `BleedBox`.  For a simple ream, just have an `ArtBox`.  For a complex ream, have either a `TrimBox` or both a `TrimBox` and a `BleedBox`.  See the discussion in the earlier section for further information.

Each boundary box key maps to a value that is another dictionary object.  These nested dictionary objects must have exactly four atom keys `LeftMargin` `RightMargin` `TopMargin` and `BottomMargin` that each map to a fixed-point value that is greater than zero.  These define the margins around the boundary box, in units of points.

For simple reams, each of the margins are the distance between the edge of the art box and the edge of the paper.  The left and right margins added together must be less than the width of the ream, and the top and bottom margins added together must be less than the height of the ream.  When a `[rot]` rotation is defined, these margins are orientated to the _unrotated_ page.

For complex reams with only a trim box, the margins are the distance between the edge of the trim box and the edge of the paper.  The left and right margins added together must be less than the width of the ream, and the top and bottom margins added together must be less than the height of the ream.  When a `[rot]` rotation is defined, these margins are orientated to the _unrotated_ page.

For complex reams with both a trim box and a bleed box, the margins of the bleed box are the distance between the edge of the bleed box and the edge of the paper.  The margins of the trim box are the margins between the edge of the trim box and the edge of the paper.  Each trim box margin must be greater than the corresponding bleed box margin.  The left and right margins of the trim box added together must be less than the width of the ream, and the top and bottom margins of the trim box added together must be less than the height of the ream.  When a `[rot]` rotation is defined, these margins are oriented to the _unrotated_ page.

The final arguments are the width `[w]` and the height `[h]` of the _unrotated_ page, in points.  Both must be greater than zero.

Example of a simple ream definition of an A4 landscape page where the art box margins are each 36 points:

    595.27559 841.88976
    [
      "ArtBox", [
        "LeftMargin"  , 36,
        "RightMargin" , 36,
        "TopMargin"   , 36,
        "BottomMargin", 36
      ] dict
    ] dict 90 ream

In order to add a page to the output PDF file, use the following operators:

    [paper:ream] begin_page -
    - end_page -

Each `begin_page` operator should have a matching `end_page` operator, and page operators may not be nested.  A ream object is passed to the `begin_page` operator to determine the size and boundaries of the page.

### Color operations

The following operators define colors:

    [g:integer] gray [c:color]
    [c:integer] [m:integer] [y:integer] [k:integer] cmyk [c:color]
    [gf:fixed] fgray [c:color]
    [cf:fixed] [mf:fixed] [yf:fixed] [kf:fixed] fcmyk [c:color]

The `gray` and `fgray` operators are used for grayscale colors, where a value of zero is black and a maximum value is white, to match the usual grayscale definition.  The grayscale operators are equivalent to using the `cmyk` or `fcmyk` operators, setting the CMY channels to zero, and setting the K channel to the inverse of the grayscale value (so that K is zero when grayscale is at maximum and K is at maximum when grayscale is zero).  In other words, the result of the color operators is always a CMYK color, with grayscale values automatically converted.

The `cmyk` and `fcmyk` operators allow a CMYK color to be defined.  See the earlier section on color objects for further information about color spaces.

The difference between the `f` and non-`f` versions of the grayscale and CMYK operators is on the type of arguments they take.  The non-`f` versions take integers, which must each be in the range [0, 255].  The `f` versions take fixed-point values, which must be in the range [0, 1.0].  The output color object always uses integer values, so fixed-point values will be automatically scaled to the integer range.

### Stroke operations

Stroke styles need a special _dash pattern array_ type for their definitions, which is created with the following operator:

    [a_1:fixed] ... [a_n:fixed] [n:integer] dash_pattern [dp:dash_pattern]

There may be zero or more elements.  If there are two or more elements, the number of elements must be even.  Each element must be a fixed-point value that is greater than zero, measuring a length in points.  See the earlier section for more about dash pattern arrays.

The following operator defines a stroke object for storing styling information about strokes:

    [param:dictionary] stroke_style [s:stroke]

All the parameters that define the stroke style are provided within a dictionary passed as a parameter.  Each style parameter is optional except the width, which is required.  The optional parameters each have default values that are used if they are not provided in the dictionary.

- `Color` - color object storing the stroke color to use; default is black
- `Width` - width of the stroke in points
- `Cap` - `ButtCap`, `RoundCap`, or `SquareCap`; default is `RoundCap`
- `Join` - `MiterJoin`, `RoundJoin`, or `BevelJoin`; default is `RoundJoin`
- `MiterLimit` - miter limit ratio if `Join` is `MiterJoin`, else null; default is null
- `DashPattern` - the dash pattern array; default is empty pattern, meaning no dashes
- `DashPhase` - distance in points to start within the dash pattern; default is zero

The `Width`, `MiterLimit`, and `DashPhase` keys have fixed-point values that must be zero or greater.  Additionally, the `Width` and `MiterLimit` may not be zero.

The `Color` must be a color object.  The default is as if created by `0 gray`

The `DashPattern` must be a dash pattern array.  The default is as if created by `[] dash_pattern`

The `Cap` and `Join` keys must have atom values with one of the specified values.

If you wish to compute the `MiterLimit` from an angle in degrees as described earlier, the following operator is available:

    [angle:fixed] miter_angle [ratio:fixed]

The `[angle]` must be in range [0.01, 180.0].  The computed result can then be used for the `MiterLimit`.

You can derive a new stroke style object from an existing one with the following operator:

    [basis:stroke] [param:dictionary] stroke_derive [s:stroke]

The newly-created stroke style object will inherit all values from the `[basis]` stroke object, except values defined in the given `[param]` dictionary will replace the inherited values.

