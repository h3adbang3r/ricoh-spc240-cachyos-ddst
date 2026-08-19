# Reverse-engineering notes

## Runtime dependencies discovered

The original x86_64 macOS filter links against, among others:

```text
Foundation.framework
libcups.2.dylib
libcupsimage.2.dylib
ApplicationServices.framework
@executable_path/../Frameworks/libDJZModule.dylib
CoreServices.framework
CoreFoundation.framework
```

`libDJZModule.dylib` exports compression-related functions including:

```text
_JBIG_Compress
_JBIG_DeCompress
_djz_Compress
_djz_DeCompress
_jbigBlockCompress
_jbigCompressOneScan_c_code
```

This is one reason a future native implementation is more involved than simply
recreating the outer `GDIJ`/`JIDG` headers.

## Failure sequence observed under Darling

### PPD lookup

Initial failure:

```text
ASSERT: Unable to get ppd file
CUPSFilter initWithArgc:argv failed
```

Solved using `libppdshim.dylib` and a flat DYLD namespace.

### NSCalendarDate

After PPD lookup was fixed:

```text
NSCalendarDate initWithTimeIntervalSinceReferenceDate:
requires a subclass implementation
```

The incompatible date/destinyDate path was patched.

### End-of-page SIGFPE

After complete raster processing:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
Floating point exception: 8
```

Investigation showed an additional path involving `insertBlankPage:` after
`endPage:`. The final compatibility stages bypass this Darling-incompatible path
and preserve the successful return state.

### Final working state

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

The result is accepted by the physical printer.
