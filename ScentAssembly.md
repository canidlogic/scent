# Scent Assembly

Scent Assembly is a low-level format that contains a sequence of instructions for generating a PDF file.  The main Scent format described by the Scent Specification is a high-level format where the document is specified descriptively as a graph of objects.  Scent Assembly, on the other hand, is structured like a state machine where the document is specified sequentially as a list of instructions, which closely matches the actual content that is compiled into the PDF file.

## Basic format

Scent Assembly files are UTF-8 text files.  Line breaks may either be LF or CR+LF.  An optional Byte Order Mark (BOM) is allowed at the start of the first line.  Trailing spaces and tabs are allowed on any line, with no significant effect.  However, leading spaces or tabs are _not_ allowed on any line.  Except within quoted strings, a sequence of one or more space and tab characters is always collapsed into a sequence space character.

The first line in a Scent Assembly must be the following:

    scent-assembly 1.0

The version number specified by this document is 1.0.  If a parser is following this specification, it should not accept any version number except 1.0.  The version numbers are provided so that future versions can enter backward-compatibility modes when they read a lower version number.

After the first line, each line is either an instruction, a comment, or blank.  Comment lines always begin with an apostrophe.  Blank lines are either empty or contain only space and tab characters.  Comment lines and blank lines are ignored by parsers.  Instructions are always entirely contained within a single text line.

### Numeric format

All numeric values are stored in fixed-point.  Fixed-point values have the following format:

1. Sign `+` or `-`
2. Sequence of up to five decimal digits
3. Decimal point `.`
4. Sequence of up to five decimal digits

Each of these four elements is optional, but only certain combinations are valid.  If (4) is present, then (3) must also be present.  Either (2) or (4) must be present.  If (2) is present, its unsigned value may not exceed 32767.  If (2) and (4) are both present _and_ (2) is equal to 32767, then (4) may only contain zero digits.

### String format

Strings values are surrounded by double quotes.  Two escape codes are supported within strings.  `\\` produces a literal backslash and `\'` produces a literal double quote.  No line breaks are allowed within string values, and all backslahses and double quotes must be escaped.  Otherwise, strings may include any codepoints.

### Name format

Names are a sequence of one or more ASCII alphanumeric characters and underscores, where the first character is not a decimal digit.  Names may have up to 31 characters.

### Color format

Colors are a sequence of exactly eight base-16 digits, which may use any mixture of uppercase and lowercase.  Each pair of digits specifies a color channel value in range 0-255 (`00`-`ff`).  The first pair is cyan, the second is magenta, the third is yellow, and the fourth is black.

## Assembly structure

Scent Assembly files define a sequence of _assembly elements._  Each assembly element is either a page, a font, or a raster image.  Pages in the PDF file will appear in the order they are defined in the Scent Assembly.  The position of font and raster images in the Scent Assembly does not matter, except that fonts and raster images must be defined before they are referenced from instructions within a page.

## Font elements

The following instruction loads a built-in font:

    font_standard [name] [standard-name]

The `[name]` parameter is in name format, which indicates how the font will be referenced from instructions in pages.  This `[name]` will not actually be stored in the PDF file.  The `[name]` must not have already been defined in another font instruction.  `[standard-name]` is a string storing the built-in PDF font name, which must be one of the following:

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

The following instruction loads an OpenType or TrueType font that will be embedded within the PDF file:

    font_file [name] [path]

The `[name]` parameter is in name format, which indicates how the font will be referenced from instructions in pages.  This `[name]` will not actually be stored in the PDF file.  The `[name]` must not have already been defined in another font instruction.  `[path]` is a string storing the path to the TrueType or OpenType font that will be loaded and embeded in the PDF file.

The namespace for `font_standard` and `font_file` are the same.  However, the namespace for the font instructions is not the same as the namespace for images.

Font element instructions may not be used while a page definition is open.

## Image elements

The following instructions load a raster image that will be embedded within the PDF file:

    image_jpeg [name] [path]
    image_png  [name] [path]

The `[name]` parameter is in name format, which indicates how the image will be referenced from instructions in pages.  This `[name]` will not actually be stored in the PDF file.  The `[name]` must not have already been defined in another image instruction.

The `[path]` is the path to a JPEG file or a PNG file, depending on which instruction is used.  It is strongly recommended to use the `image_recode.pl` script on JPEG and PNG files before referencing them from Scent Assemblies, to avoid weird encodings that could cause problems.

The namespace for `image_jpeg` and `image_png` are the same.  However, the namespace for the image instructions is not the same as the namespace for fonts.

Note that PDF does not embed the full JPEG or PNG file.  Instead, it only embeds certain parts of the image file.  This is why it is important to use the `image_recode.pl` script to keep the image as simple as possible.

## Page structure

Scent Assembly files describe a sequence of pages that will be compiled into the PDF file.  All instructions must be contained within a page.  The following instruction lines mark the boundaries of a single page:

    begin page
    end page

Each `begin page` instruction must have a matching `end page` instruction.  Page definitions can not be nested.

When the `begin page` instruction is given, the page starts out in _header mode._  It is an error if the page is still in header mode when the `end page` instruction is given.  To leave header mode, use the following instruction:

    body

The `body` instruction may only be used when a page is in header mode.  Furthermore, the `body` instruction may only be given after the dimensions of the page have been defined in the page header.  The page dimensions start out in an undefined state after `begin page`.  To set the page dimensions, use the following instruction:

    dim [width] [height]

The `[width]` and `[height]` are both numeric values that must be greater than zero, specifying the width and height of the page in points (1/72 inch).  If the page is rotated for display such as in landscape orientation, then these dimensions are for the _unrotated_ page.  If this instruction is given more than once in a header, subsequent invocations overwrite the values established by previous invocations.  You may only use the `dim` instruction when a page is in header mode.

When a new page is defined with `begin page`, its boundary boxes start out empty.  You may define a bleed box, a trim box, and/or an art box.  (See the Scent Specification for the meaning of these boxes.)  It is recommended to define either a trim box or an art box, with the bleed box being optional.  The box instructions have the following format:

    bleed_box [min_x] [min_y] [max_x] [max_y]
    trim_box  [min_x] [min_y] [max_x] [max_y]
    art_box   [min_x] [min_y] [max_x] [max_y]

These instructions may only be used when a page is in header mode.  If a specific boundary box is defined more than once, subsequent definitions overwrite earlier ones.  The four parameters that each of these instructions take are numeric.  The parameters define a rectangular area on the page where `[min_x]` and `[min_y]` are the bottom-left corner where the coordinates are at their minimum values and `[max_x]` and `[max_y]` are the top-right corner where the coordinates are at their maximum values.  If the page is rotated for display such as in landscape orientation, then these boxes rae for the _unrotated_ page.

For each of the box instructions, the minimum coordinate must be greater than or equal to zero and less than the maximum coordinate.  The maximum coordinate must be less than the relevant page dimension (width for X or height for Y).  In other words, each box must be contained entirely within the page.  Scent Assembly does not enforce any requirements between how the boxes relate to each other.

Pages by default are shown such that the default coordinate system has the origin at the bottom-left corner of the page, the X axis points right, and the Y axis points up.  It is possible to define a rotation angle of 0, 90, 180, or 270 degrees clockwise, which merely affects how the page is rotated when it is viewed in a PDF viewer application:

    view_rotate [angle]

The `[angle]` must be one of the following:

- `none` (zero degrees)
- `right` (90 degrees clockwise)
- `twice` (180 degrees)
- `left` (270 degrees clockwise)

If the instruction is used more than once in the header, subsequent invocations overwrite earlier invocations.  The default rotation is `none`, which is used if no `view_rotate` instruction is given in the header of a page.

All instructions that are defined in subsequent sections of this specification may only be used when a page is defined but it is not in header mode.

## Content instructions

Content instructions may only be used when a page definition is open and the page is not in header mode.

Content instructions are used in three different modes:  _initial,_ _path,_ and _text._  When the `body` instruction switches a page out of header mode, the content instructions will always begin in initial mode.  When the `end page` instruction ends the page, the content instructions must be in initial mode.

The following instructions are used to enter and leave path mode:

    begin path [stroke] [fill] [clip]
    end path

The `[stroke]` parameter determines whether the path will be stroked.  It must be either `-` (no stroking) or `stroke`.  The details of how stroking is rendered are determined by graphics state parameters described later.

The `[fill]` parameter determines whether the path will be filled.  It must be either `-` (no fill), `fillnz` (fill with nonzero winding rule), or `filleo` (fill with even-odd rule).  The details of how filling is rendered are determined by graphics state parameters described later.

The `[clip]` parameter determines whether the clipping area should be reduced by intersecting it with the interior of this path.  It must be either `-` (no clipping region update), `clipnz` (update clipping area using nonzero winding rule), or `clipeo` (update clipping area using even-odd rule).

The `begin path` instruction may only be used when the page is in initial content mode.  After the instruction, the page enters path mode.  The `end path` instruction may only be used when the page is in path content mode.  After the instruction, the page returns to initial mode.  The `end path` instruction may cause the path to be rendered and/or the clipping area to be updated, depending on the provided parameters.

The following instructions are used to enter and leave text mode:

    begin text [clip]
    end text

The `begin text` instruction may only be used when the page is in initial content mode.  After the instruction, the page enters text mode.  The `end text` instruction may only be used when the page is in text content mode.  After the instruction, the page returns to initial mode.

The `[clip]` parameter is either `-` (no clipping update) or `clip`.  If set the `clip`, then the regions defined by all glyphs rendered during the text block will be accumulated.  When the `end text` instruction is reached, the clipping region will be updated by intersecting the current clipping region with the union of all the glyph areas that were rendered during the block.

In contrast to `end path`, `end text` never causes anything to be rendered, because text is rendered by instructions within the text block.  However, `end text` _does_ cause the clipping area to be updated if clipping mode was enabled for this text block.

### Common state instructions

Common state instructions are content instructions that may be used both in initial content mode and text content mode.  (They may not, however, be used in path mode.)

All common state instructions are used to set parameters of the graphics state that control how text and graphics are rendered.  At the start of each page with the `begin page` instruction, the graphics state is reset to default settings.  Common state instructions are used to modify the settings of the graphics state.  When a rendering instruction is issued that makes use of graphics state parameters, the current values of the graphics state parameters at the time of the rendering instruction are used.

Scent Assembly will automatically save graphics state at the start of the page and restore it at the end of the page, to make doubly sure that graphics state is local to each page.  Also, Scent Assembly will explicitly set all common state defaults at the start of each page after saving the graphics state, to make sure the initial state is well defined.

    line_width [width]

Sets the width of stroked lines and curves.  `[width]` is a numeric parameter that must be greater than zero and is measured in points (1/72 inch).  Default value is a width of one point.  Line width is used by `end path` when the path is stroked and also by text rendering when stroking glyph outlines is enabled.

    line_cap [style]

Sets the line cap style.  `[style]` must be either `butt`, `round`, or `square`.  Butt caps end with a straight edge abruptly at the end of the line.  Round caps round the line off with a semicircle.  Square caps are like butt caps except they proceed half the line width beyond the endpoint.  Default value is a round cap.  Line caps apply everywhere that the line width applies.  They are used at the end of unclosed lines and curves and also at the ends of dashes when a dashing pattern is in effect.

    line_join [style]
    line_join miter [miter-ratio]

Sets the line join style.  `[style]` must be either `round` or `bevel`.  When a `miter` join is specified, the instruction also requires a numeric `[miter-ratio]` that is greater than zero.  If the ratio of the miter length to the stroke width exceeds the given miter ratio, then a bevel join is substituted.  Default value is a round join.  Line joins apply everywhere that the line width applies.  They are used for corners between lines and curves.

    line_dash [phase] [d1] [g1] ... [dn] [gn]
    line_undash

Sets or clears dashed line style.  All parameters to `line_dash` are numeric and must be greater than zero, except `[phase]` must be greater than or equal to zero.  All parameters after the first parameter form a dash pattern array.  The dash pattern array contains pairs of numeric values where the first value in the pair is the length of a dash and the second value in the pair is the length of a gap.  There must be at least one such pair.  The `[phase]` parameter controls where in the pattern the stroke should start.  At the beginning of the stroke, the dash pattern will be in the position as though `[phase]` points of distance had already been stroked.  The `line_undash` command clears any dashed line pattern.  Default value is no dashed line pattern.  Dashed lines, if set, apply everywhere that the line width applies.

    stroke_color [color]
    fill_color   [color]

Sets the color used for stroking and filling.  The stroke color applies everywhere that the line width applies.  The fill color is used when filling paths and filling glyphs.  Default values are solid black (`000000FF`) for both colors.

### Initial instructions

Initial instructions are content instructions that can only be used in initial content mode.

    save
    restore

These two instructions save the current graphics state to a stack and restore the graphics state from a stack.  Each page has an independent state, so each `save` instruction must be paired with a later `restore` instruction in the same page.  Save and restore blocks may be nested.

    matrix [a] [b] [c] [d] [e] [f]

Adjust the current transformation matrix (CTM) by premultiplying a new transformation matrix to it.  The CTM is a 3x3 matrix that maps points in user space `(x, y)` to points in page space `(x', y')` according to the following formula:

    | x' y' 1 | = | x y 1 | × CTM

The `matrix` operation modifies `CTM` to a new value `CTM'` according to the following formula, using the six numeric arguments passed to the `matrix` instruction:

           | a b 0 |
    CTM' = | c d 0 | × CTM
           | e f 1 |

Note that this is premultiplication!  The new matrix is the first argument in the matrix multiplication operation.

At the start of each page, the CTM defines the mapping so that the origin in user space is the bottom-left corner of the unrotated page, the X axis points right with a single unit being a point (1/72 inch), and the Y axis points up with a single unit being a point.  Note that if you are working with a page in landscape orientation that has been defined in the idiomatic way as a rotated portrait page, the CTM at the start of the page will be in unrotated portrait orientation, not in landscape orientation.

The following instruction draws an embedded image on the page:

    image [name]

The `[name]` parameter is a name that must have been defined earlier by an `image_jpeg` or `image_png` instruction.  The image will always be drawn with its bottom-left corner at (0, 0) in user coordinate space, its height exactly one point, and its width exactly one point.  If the image is not square, it will be stretched to fit into this unit square.

This unit square is usually not how you actually want to display the image.  To display the image properly, you should use the `matrix` instruction first to transform this unit square at the origin into the proper position on the page.  Different scaling values can be applied to the X and Y axis to get the correct image display dimensions.

### Path instructions

Path instructions are content instructions that can only be used in path content mode.  Paths are defined as a sequence of subpaths.  The following instruction begins a new subpath:

    moveto [x] [y]

The `[x]` and `[y]` parameters are numeric parameters that indicate the user space coordinates where the subpath begins.

Once a subpath has begun, you can append lines and curves with the following instructions:

    line  [x2] [y2]
    curve [x2] [y2] [x3] [y3] [x4] [y4]

Each of these parameters is a numeric parameter.  Lines and curves always begin at the current point in the path.  After the line or curve, the current point is updated to the end of the line or curve that was just appended.  Curves are always cubic Bezier curves with two control points.

Subpaths end either when a new subpath begins, or when path content mode is left, or when the following instruction is given:

    close

The `close` instruction closes the current subpath by connecting the end of the subpath to the beginning with a line, if necessary.

There is also a shortcut instruction that appends a whole rectangular subpath in a single operation:

    rect [x] [y] [width] [height]

The `[x]` and `[y]` coordinates are the bottom-left of the rectangle.  The `[width]` and `[height]` must be greater than zero.  For purposes of the nonzero winding rule, the edges of the rectangle run in counter-clockwise direction.

### Text instructions

Text instructions are content instructions that can only be used in text content mode.

There are several text instructions that are used to set text-specific rendering parameters.  Each of these parameters is initialized to a default value at the start of each page.  Text state instructions are used to modify the settings of the text state.  When a text rendering instruction is issued, the current values of the text state parameters at the time of the rendering instruction are used.

Note that text state is _not_ reset each time text mode is entered with `begin text`.  Text state only resets on `begin page`.

Text spacing is controlled with the following instructions:

    cspace [extra]
    wspace [extra]

The `cspace` instruction sets the extra amount of space to add to each glyph.  The `wspace` instruction sets the extra amount of space to add to rendered ASCII space characters.  The `[extra]` parameters must be numeric parameters that are zero or greater and expressed in points.  The default for both is zero, meaning no extra space.

    hscale [percent]

The `hscale` instruction horizontally scales glyphs to stretch them or squeeze them along the baseline.  The `[percent]` parameter is numeric and greater than zero.  The default value of 100 means that no stretching or squeezing should be applied.  Values less than 100 squeeze the glyphs and values greater than 100 stretch the glyphs.

    lead [distance]

The `lead` instruction sets the distance in points between text lines.  Its default value of zero causes text lines to be rendered on top of each other.  The `[distance]` is a numeric parameter that must be zero or greater.  It is measured in points.

    font [name] [size]

The `font` instruction sets the font that will be used for drawing text.  The default value is undefined, so you must define a font before drawing any text.  The `[name]` must be the name of a font that was defined previously with `font_standard` or `font_file`.  The `[size]` is a numeric parameter greater than zero that specifies the font size in points.

    text_render [stroke] [fill]

The `text_render` instruction sets the text rendering mode.  `[stroke]` is either `-` (no stroke) or `stroke`.  `[fill]` is either `-` (no fill) or `fill`.  The default is to fill but not stroke.  When fill is selected, glyphs will be filled using the fill color selected by the graphics state.  When stroke is selected, glyph outlines will be stroked using the stroke graphics parameters selected by the graphics state.  When both fill and stroke are selected, fill happens first and then stroke.  It is also possible to set neither stroke nor fill.  This is useful when clipping mode is active for the text block, and you want to use text to update the clipping path but not actually draw the glyphs.

    rise [distance]

The `rise` instruction causes text to be rendered above or below the baseline, for superscript and subscript effects.  The default value of zero means that text is rendered directly on the baseline.  `[distance]` is a numeric value, measured in points.  If greater than zero, it creates a superscript.  If less than zero, it creates a subscript.

    advance [x] [y]
    advance

At the start of each text block, the text position and line position are both set to the origin of user space.  Writing text updates the text position but not the line position.  The `advance` instruction updates the line position and then sets the text position equal to the new line position.  If specified without any parameters, `advance` subtracts the leading distance (established by `lead`) from from the Y coordinate of the line position and leaves the X coordinate of the line position alone.  If specified with two numeric parameters, `[x]` is added to the X coordinate of the line position and `[y]` is added to the Y coordinate of the line position.

    write [string]

Render text.  `[string]` is a string parameter that stores the Unicode codepoints to render.  The current text and graphics state determines the details of how the text is rendered.  Text is rendered starting at the current text position, and then the text position is updated to move after the text that was just rendered.  If clipping is in effect for this text block, the glyphs will be added to the path being accumulated for the clipping update.
