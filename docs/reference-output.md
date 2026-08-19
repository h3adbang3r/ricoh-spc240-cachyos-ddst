# Known-good reference output

This document records observable properties of a successfully generated
Ricoh Aficio SP C240DN job.

It is intended as a regression reference for future patching or a possible native
DDST/GDI implementation.

## Test configuration

```text
Printer:        Ricoh Aficio SP C240DN
Resolution:     600 × 600 dpi
Paper:          A4
Color model:    Gray
Input:          CUPS Raster v3, little-endian
Raster size:    4761 × 6816
Bits/color:     8
Bits/pixel:     8
Bytes/line:     4761
Color order:    Chunked
Transport:      JetDirect/AppSocket TCP/9100
```

The original filter logged:

```text
Page header: Duplex = no
Page header: HWResolution = 600 x 600
Page header: PageSize = 595 x 842
Page header: cupsWidth = 4761
Page header: cupsHeight = 6816
Page header: cupsBitsPerColor = 8
Page header: cupsBitsPerPixel = 8
Page header: cupsBytesPerLine = 4761
Page header: cupsColorOrder = chunked
```

## Job start

Known-good output begins with:

```text
00000000  47 44 49 4a 00 00 00 78  00 64 00 01 00 00 00 00  |GDIJ...x.d......|
00000010  00 00 00 a8 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  01 00 00 02 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000030  00 00 00 00 00 00 00 00  43 61 63 68 79 4f 53 20  |........CachyOS |
00000040  52 69 63 6f 68 20 52 65  66 65 72 65 6e 63 65 00  |Ricoh Reference.|
```

ASCII signature:

```text
GDIJ
```

A `GJET` structure follows in the observed stream.

## Raster processing

For the reference page, the filter created 27 raster bands:

```text
PlanarFilter startPage: page 0
Planar channel size: 32450976, channelCount: 1
RasterBandBuffer initWithPixelHeight: height: 6816, rowBytes: 608, bandHeight: 256
RasterBandBuffer initWithPixelHeight: totalBands: 27, fileSize: 4144128
PlanarFilter loading screen set: FastPlainMono
...
band total 27
band num 27
ditherBandCount num 27
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
```

## Successful job finalization

The final working filter logs:

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

Process exit status:

```text
0
```

## Job end

A completed stream ends with:

```text
00000010  00 00 00 00 00 00 00 00  00 00 00 00 4a 49 44 47  |............JIDG|
```

ASCII signature:

```text
JIDG
```

## Physical validation

The generated stream was sent directly to TCP port 9100 and produced a physical
page containing:

```text
CachyOS DDST TEST
```

The same CUPS integration subsequently printed successfully from a normal
browser-based spreadsheet application.

## Regression checks

For future changes, verify at minimum:

```bash
head -c 4 output.gdi
tail -c 4 output.gdi
```

Expected:

```text
GDIJ
JIDG
```

Also verify:

- converter exit status is `0`
- physical printer accepts the job
- no CUPS filter error is reported
- output dimensions match the requested page
