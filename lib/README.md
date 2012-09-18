Useful libraries
================

Compression
-----------

The emulator has a built-in ROM "drive".  Basically, this is a bunch of RK86 
files compiled into the binary of the emulator. I wanted to put all files 
from the "./files" subdirectory into there.  Unfortunately, the overall size
of these files is about 1MB which obviously doesn't fit into 512KB flash
of PIC32.  The plan was to compress them and decompress on-the-fly.

Two compression libraries were discovered:

* miniz - http://code.google.com/p/miniz/ (zlib and deflate algorithms)
* minilzo - http://www.oberhumer.com/opensource/lzo/#minilzo
  (LZO algorithm)

The selection criteria were:

* a single source library without any dependecies
* scrict ANSI C (I use the Microchip XC32 compilers)
* in-memory decompression
* a small amount of static temporary memory for decompression
  (no malloc/calloc) (ideally, it should use the output decompression
  buffer only)

On my data miniz provides 0.71 compress ratio and minilzo provides 0.78. So,
both don't squeeze my data into the PIC32 flash.

### Overall impression

* miniz is slightly easier to use from the API perspective.
* minilzo provides better compression

Also miniz use **only** the output buffer for decompression, but minilzo
requries at least 16K static buffer.
