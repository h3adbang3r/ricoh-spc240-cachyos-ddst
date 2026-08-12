# Ricoh Aficio SP C240DN DDST on CachyOS/Linux

Working CUPS integration for the **Ricoh Aficio SP C240DN** on Linux using the original Ricoh macOS DDST/GDI filter executed through **Darling**.

> ⚠️ This is an experimental compatibility solution using a patched proprietary Ricoh macOS printer filter.
> The repository should remain private unless redistribution rights for the original Ricoh components have been verified.

## Status

**Working.**

Tested successfully on CachyOS:

- CUPS accepts normal print jobs
- CUPS generates raster data
- the original Ricoh macOS filter runs through Darling
- DDST/GDI output is generated
- output is sent to the printer via JetDirect / RAW port 9100
- physical pages print successfully

Test printer:

**Ricoh Aficio SP C240DN**

Printer connection:

```text
socket://172.26.47.1:9100
```

CUPS queue:

```text
Ricoh_SPC240
```

---

## Architecture

The resulting printing pipeline is:

```text
Application
    │
    ▼
   CUPS
    │
    │ CUPS Raster
    ▼
rastertoricohspc240
    │
    ▼
ricoh-spc240-ddst
    │
    │ sudo → user running Darling
    ▼
  Darling
    │
    ▼
Patched Ricoh macOS filter
RicohAficioSPC240DNFilter-final3
    │
    │ DDST / GDI
    ▼
CUPS socket backend
    │
    │ TCP/9100
    ▼
Ricoh Aficio SP C240DN
```

The printer therefore remains usable as a normal CUPS printer from Linux applications.

---

## Why this exists

The Ricoh Aficio SP C240DN uses Ricoh's proprietary DDST/GDI printing protocol.

The original Ricoh macOS driver contains a filter capable of converting CUPS raster data into the format expected by the printer.

Instead of reimplementing the complete proprietary raster-to-DDST conversion, this project runs the original x86_64 macOS filter through Darling.

Several incompatibilities between the old macOS driver and Darling had to be worked around before the filter could complete a print job.

---

## Requirements

The current setup requires:

- x86_64 Linux
- CUPS
- Darling
- sudo
- a working Darling prefix
- network access to the printer
- original Ricoh SP C240DN macOS driver components

The current wrapper expects the Darling prefix belonging to:

```text
h3adbang3r
```

The supplied configuration therefore needs modification if installed for another Linux user.

---

## Repository layout

```text
.
├── cups
│   ├── rastertoricohspc240
│   └── RicohAficioSPC240DN-CachyOS.ppd
├── install.sh
├── payload
│   ├── libppdshim.dylib
│   └── RicohAficioSPC240DNFilter.app
│       └── Contents
│           ├── Frameworks
│           │   └── libDJZModule.dylib
│           ├── MacOS
│           │   ├── RicohAficioSPC240DNFilter
│           │   ├── RicohAficioSPC240DNFilter-patched
│           │   ├── RicohAficioSPC240DNFilter-test2
│           │   ├── RicohAficioSPC240DNFilter-final
│           │   ├── RicohAficioSPC240DNFilter-final2
│           │   └── RicohAficioSPC240DNFilter-final3
│           └── Resources
├── ricoh-spc240-ddst
└── sudoers
    └── ricoh-spc240
```

`RicohAficioSPC240DNFilter-final3` is the currently working filter binary.

---

# Reverse engineering notes

## 1. Missing PPD lookup

The original filter expects to obtain its PPD through the macOS/CUPS environment.

Under Darling this failed with:

```text
ASSERT: Unable to get ppd file
CUPSFilter initWithArgc:argv failed
```

A small compatibility library was therefore created:

```text
libppdshim.dylib
```

It supplies the PPD expected by the original Ricoh filter.

The filter is started with:

```text
DYLD_FORCE_FLAT_NAMESPACE=1
DYLD_INSERT_LIBRARIES=.../libppdshim.dylib
```

After this workaround the Ricoh filter successfully parses the PPD and begins processing CUPS raster data.

---

## 2. NSCalendarDate incompatibility

The next failure occurred during creation of the Ricoh GDI job header:

```text
NSCalendarDate initWithTimeIntervalSinceReferenceDate:
requires a subclass implementation
```

Disassembly showed the original filter calling:

```text
[NSCalendarDate date]
[date destinyDate]
```

while constructing the file header.

The resulting timestamp is not required for raster conversion itself, so the problematic date-generation sequence was patched out and the corresponding header field is written without invoking the incompatible Darling implementation.

This allowed processing to reach the raster conversion stage.

---

## 3. End-of-page floating point exception

After successfully processing all raster bands, the filter initially terminated with:

```text
Floating point exception: 8
```

The failure occurred after:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
```

The generated output already contained valid Ricoh GDI data but the process crashed during its end-of-page logic.

Further inspection of the Mach-O binary identified problematic control flow around the page finalization path.

The relevant branch logic was patched to bypass the incompatible path.

After this modification the filter reached:

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
```

and produced a complete GDI stream ending with:

```text
JIDG
```

---

## 4. Correct return status

Although the generated GDI stream was complete, an intermediate version still returned failure:

```text
RasterFilter run: exiting - result: 0
rasterToGDI ending with result 1
```

The final patch adjusts the success path so that the filter terminates normally.

The working version reports:

```text
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

and exits with:

```text
0
```

This binary is stored as:

```text
RicohAficioSPC240DNFilter-final3
```

---

# Successful reference run

A successful monochrome A4/600 dpi job produced:

```text
HWResolution = 600 x 600
PageSize = 595 x 842
cupsWidth = 4761
cupsHeight = 6816
cupsBitsPerColor = 8
cupsBitsPerPixel = 8
cupsBytesPerLine = 4761
cupsColorOrder = chunked
```

The page was processed in 27 raster bands:

```text
band total 27
band num 27
ditherBandCount num 27
RasterFilter run: Processed 6816 lines
```

Job finalization:

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

The generated stream starts with the Ricoh GDI job signature:

```text
GDIJ
```

and terminates with:

```text
JIDG
```

The resulting data was successfully printed by a physical Ricoh Aficio SP C240DN.

---

# CUPS integration

The included PPD uses:

```text
application/vnd.cups-raster
```

as the input to:

```text
rastertoricohspc240
```

The CUPS filter copies the spool input to a temporary raster file that is accessible from the Darling environment.

It then invokes:

```text
/usr/local/libexec/ricoh-spc240-ddst
```

under the user owning the configured Darling prefix.

The wrapper translates Linux paths into Darling paths:

```text
/tmp/example.raster
```

becomes:

```text
/Volumes/SystemRoot/tmp/example.raster
```

The Ricoh filter's stdout becomes the CUPS backend input and is ultimately sent to the printer.

---

# Installation

Before installation, make sure Darling works for the configured user:

```bash
sudo -u h3adbang3r darling shell uname -a
```

A working installation should return a Darwin environment.

Then install with:

```bash
sudo ./install.sh
```

The installer:

1. installs the Ricoh/Darling payload into `/opt/ricoh-spc240`
2. installs the Darling wrapper
3. installs the CUPS raster filter
4. installs the required sudoers rule
5. validates the sudoers configuration
6. validates the PPD
7. creates the CUPS printer queue
8. restarts CUPS

---

## Test print

For example:

```bash
lp -d Ricoh_SPC240 test.pdf
```

Check the queue with:

```bash
lpstat -p Ricoh_SPC240
lpstat -v Ricoh_SPC240
```

Expected device URI:

```text
socket://172.26.47.1:9100
```

---

# Debugging

The original Ricoh filter contains extensive debugging support.

Creating:

```text
/tmp/gdidebug
```

enables additional logging.

The resulting log can be inspected at:

```text
/tmp/CUPSDebug.log
```

Do not leave debugging enabled permanently unless required.

Useful commands:

```bash
tail -f /tmp/CUPSDebug.log
```

CUPS status:

```bash
lpstat -t
```

Recent CUPS service messages:

```bash
journalctl -u cups -n 100
```

---

# PPD validation

The modified PPD can be checked with:

```bash
cupstestppd -v cups/RicohAficioSPC240DN-CachyOS.ppd
```

The working PPD passes validation without errors.

Some warnings remain because the original Ricoh PPD uses legacy names such as:

```text
JISB5
HalfLetter
FS
Foolscap
Kai16
Monarch
```

and an old-style `PCFileName`.

These warnings have deliberately not been modified because they do not prevent printing and unnecessary changes to the original driver's option definitions are avoided.

---

# CUPS deprecation warning

Current CUPS versions may display:

```text
Printer drivers are deprecated and will stop working in a future version of CUPS.
```

This project deliberately uses the classic PPD/filter architecture because the original proprietary Ricoh raster converter is being reused.

The warning does not currently prevent the driver from working.

A future implementation could potentially package the compatibility layer as a modern Printer Application / IPP-based solution.

---

# Security notes

The current design permits the CUPS service account to execute the Ricoh wrapper as the user owning the Darling prefix through a narrowly scoped sudoers rule.

Do **not** replace this with unrestricted passwordless sudo access.

The sudoers configuration should grant access only to:

```text
/usr/local/libexec/ricoh-spc240-ddst
```

Review:

```text
sudoers/ricoh-spc240
```

before installation.

---

# Known limitations

Currently tested:

- Ricoh Aficio SP C240DN
- network printing over TCP port 9100
- A4
- 600 dpi
- monochrome/Gray
- single-page printing
- CachyOS
- x86_64 Darling

Additional features such as:

- color printing
- duplex
- multiple pages
- alternate trays
- alternate paper types
- other resolutions

should be tested separately before being considered fully supported.

---

# Preservation

This repository intentionally retains several intermediate patched binaries.

They document the reverse-engineering process that resulted in the working `final3` binary and may be useful if future Darling or CUPS changes require revisiting individual patches.

A future improvement would be to replace the stored intermediate binaries with reproducible patch scripts that generate `final3` directly from the untouched original Ricoh executable.

---

## Disclaimer

Ricoh trademarks and proprietary driver components belong to their respective owners.

This project is an experimental Linux compatibility setup and is not affiliated with or supported by Ricoh.
