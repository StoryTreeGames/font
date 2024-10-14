# StoryTree Font

A library for parsing fonts files, resolving glyphs, and generating new font information/data.

## Goal

A powerful yet dead simple font API. Parse any font file and immediatly get font family information.
Query for glyph and layout data and get everything you would need to render text.

Additionally since all the ground work is here. This library could have stretch goal of having a builder API around
generating new font files and converting multiple font families into a font collection, etc...

## References

- [`Microsoft OTF Docs`](https://learn.microsoft.com/en-us/typography/opentype/spec/otff)
- [`Apple's TrueType Reference Manual`](https://developer.apple.com/fonts/TrueType-Reference-Manual/)
- [`ttf-parsing (rust)`](https://github.com/RazrFalcon/ttf-parser/blob/master/src/tables/glyf.rs)
- [`fontaine (zig)`](https://github.com/ziglibs/fontaine)
