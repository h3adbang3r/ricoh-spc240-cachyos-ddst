# Ricoh Aficio SP C240DN – DDST Driver for CachyOS/Linux

Working CUPS setup for the **Ricoh Aficio SP C240DN** using the original
Ricoh macOS DDST/GDI filter executed through **Darling**.

This project exists because the printer uses Ricoh's proprietary DDST/GDI
printing language and the original macOS filter cannot run natively on Linux.

The original Ricoh filter has been patched to work around incompatibilities
between the old macOS driver and Darling.

Tested on **CachyOS / Arch Linux** with CUPS and a Ricoh Aficio SP C240DN
connected over JetDirect/AppSocket (`socket://...:9100`).

> **Status:** Working. Real pages have successfully been printed from CachyOS.

---

## Overview

The printing path is:

```text
Linux application
       │
       ▼
      CUPS
       │
       ▼
CUPS raster data
       │
       ▼
rastertoricohspc240
       │
       ▼
ricoh-spc240-ddst
       │
       ▼
sudo: cups → desktop user
       │
       ▼
Darling
       │
       ▼
patched Ricoh macOS DDST filter
       │
       ▼
Ricoh GDI/DDST stream
       │
       ▼
socket://PRINTER_IP:9100
       │
       ▼
Ricoh Aficio SP C240DN
```

The resulting printer data starts with the expected Ricoh GDI header:

```text
GDIJ
```

and a successfully completed job ends with:

```text
JIDG
```

---

## Why Darling is required

Ricoh supplied a macOS filter for this printer which contains the proprietary
logic required to convert rasterized print data into the GDI/DDST format
understood by the printer.

Rather than reimplementing the complete proprietary output format, this setup
runs the original x86_64 macOS filter through Darling.

Unfortunately, the original filter is old enough to hit several compatibility
problems in Darling. Therefore the executable used by this project contains
small binary patches.

---

## Repository layout

```text
.
├── README.md
├── install.sh
├── ricoh-spc240-ddst
├── cups
│   ├── rastertoricohspc240
│   └── RicohAficioSPC240DN-CachyOS.ppd
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
│               ├── RICOH Aficio SP C240DN CS.icc
│               ├── ScreenSets.plist
│               ├── Screens/
│               └── ...
└── sudoers
    └── ricoh-spc240
```

The intermediate filter binaries are intentionally retained. They document the
reverse-engineering and compatibility work that led to the working filter.

---

## Patched filter binaries

The `MacOS` directory contains the original Ricoh executable and the different
stages created while debugging the driver under Darling.

| Binary | Description |
|---|---|
| `RicohAficioSPC240DNFilter` | Original, unmodified Ricoh macOS filter |
| `RicohAficioSPC240DNFilter-patched` | First compatibility patch |
| `RicohAficioSPC240DNFilter-test2` | Experimental patched version |
| `RicohAficioSPC240DNFilter-final` | Intermediate working/debugging version |
| `RicohAficioSPC240DNFilter-final2` | Later control-flow fix; generates complete GDI output |
| `RicohAficioSPC240DNFilter-final3` | **Current production version; generates valid GDI output and exits successfully** |

The production wrapper uses:

```text
RicohAficioSPC240DNFilter-final3
```

The older binaries are not required for normal printing but are intentionally
kept as documentation of the reverse-engineering process.

---

## Compatibility patches

### 1. NSCalendarDate crash

The original filter calls:

```objc
[NSCalendarDate date]
```

followed by:

```objc
destinyDate
```

Under Darling this resulted in:

```text
NSCalendarDate initWithTimeIntervalSinceReferenceDate:
requires a subclass implementation
```

and terminated the filter with:

```text
Abort trap: 6
Exit-Code: 134
```

The relevant original code path was:

```asm
movq    *OBJC_CLASS*$_NSCalendarDate, %rdi
callq   ...                 ; date
leaq    ..., %rsi           ; destinyDate
movq    %rax, %rdi
callq   ...
bswapl  %eax
movl    %eax, 0x14(%rbx)
```

This timestamp generation is not required for producing usable printer data,
so the incompatible code path was bypassed.

After this patch the filter progressed into actual raster processing.

---

### 2. End-of-page / control-flow issue

After bypassing the calendar crash, the complete raster page was processed:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
```

but the process could terminate with:

```text
Floating point exception: 8
Exit-Code: 136
```

Further analysis identified an incompatible control-flow path around the
end-of-page handling.

The later patches bypass this path and allow the filter to finish the job.

The final version reports:

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

and exits with:

```text
Exit-Code: 0
```

---

## Successful output

A successful generated stream begins with:

```text
47 44 49 4a
G  D  I  J
```

Example:

```text
00000000  47 44 49 4a 00 00 00 78  00 64 00 01 00 00 00 00
00000010  00 00 00 a8 00 00 00 00  00 00 00 00 00 00 00 00
```

and ends with:

```text
4a 49 44 47
J  I  D  G
```

A real print job using this output was successfully printed by the
Ricoh Aficio SP C240DN.

---

## Requirements

The host requires:

- Linux
- CUPS
- Darling
- `sudo`
- the original Ricoh filter resources included in `payload/`
- a network-accessible Ricoh Aficio SP C240DN

The current setup was developed and tested on CachyOS.

The printer is accessed using raw JetDirect/AppSocket on TCP port 9100.

---

## CUPS user

On the tested CachyOS installation, CUPS runs print filters as:

```text
User 209
Group 209
```

which corresponds to:

```text
cups:x:209:209:cups helper user:/:/usr/bin/nologin
```

Darling cannot directly operate normally under this service account because
it requires a usable user environment/prefix.

The wrapper therefore executes Darling as the desktop user via a tightly
restricted sudo rule.

---

## sudo configuration

The required rule is stored in:

```text
sudoers/ricoh-spc240
```

Contents:

```sudoers
Defaults:cups !pam_acct_mgmt
cups ALL=(h3adbang3r) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```

The `pam_acct_mgmt` override is required because the `cups` service account has
a `nologin` system-account configuration which otherwise causes sudo to fail
with an account/PAM error.

The permission is intentionally narrow:

**`cups` may execute only `/usr/local/libexec/ricoh-spc240-ddst` as the
configured desktop user without a password.**

Validate the file before installation:

```bash
sudo visudo -cf sudoers/ricoh-spc240
```

Expected result:

```text
sudoers/ricoh-spc240: parsed OK
```

or, with a German locale:

```text
Analyse OK
```

---

## Installation

Run:

```bash
sudo ./install.sh
```

The installer deploys the required files to the system.

The important components are:

```text
/opt/ricoh-spc240/
/usr/local/libexec/ricoh-spc240-ddst
/usr/lib/cups/filter/rastertoricohspc240
/etc/cups/ppd/
/etc/sudoers.d/ricoh-spc240
```

The exact installed paths can be inspected in `install.sh`.

---

## PPD validation

The supplied PPD can be checked with:

```bash
cupstestppd -v cups/RicohAficioSPC240DN-CachyOS.ppd
```

The final PPD passes validation with:

```text
KEINE FEHLER GEFUNDEN
```

Some warnings remain for legacy paper-size names and the old PPD 8.3 filename
recommendation. These do not prevent operation.

---

## Adding the printer

Replace `PRINTER_IP` with the address of the printer:

```bash
sudo lpadmin \
    -p Ricoh_SPC240 \
    -E \
    -v socket://PRINTER_IP:9100 \
    -P cups/RicohAficioSPC240DN-CachyOS.ppd
```

Example:

```bash
sudo lpadmin \
    -p Ricoh_SPC240 \
    -E \
    -v socket://172.26.47.1:9100 \
    -P cups/RicohAficioSPC240DN-CachyOS.ppd
```

Recent CUPS versions may display:

```text
lpadmin: Printer drivers are deprecated and will stop working in a future
version of CUPS.
```

This is expected because this project deliberately uses the classic
PPD/filter CUPS architecture.

---

## Check printer status

```bash
lpstat -p Ricoh_SPC240
```

and:

```bash
lpstat -v Ricoh_SPC240
```

The device URI should resemble:

```text
socket://PRINTER_IP:9100
```

---

## Test the wrapper

A raster file can be passed directly through the wrapper for debugging.

The wrapper ultimately invokes the patched filter through Darling with:

```text
DYLD_FORCE_FLAT_NAMESPACE=1
DYLD_INSERT_LIBRARIES=/Volumes/SystemRoot/tmp/libppdshim.dylib
```

A successful conversion should:

1. process all raster bands,
2. write a GDI stream,
3. append `JIDG`,
4. exit with status `0`.

Example log ending:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

---

## Debugging generated output

Check the beginning of a generated file:

```bash
head -c 128 output.gdi | hexdump -C
```

A valid stream should begin with:

```text
47 44 49 4a
```

or:

```text
GDIJ
```

Check the end:

```bash
tail -c 32 output.gdi | hexdump -C
```

A completed job should end with:

```text
4a 49 44 47
```

or:

```text
JIDG
```

---

## Troubleshooting

### `NSCalendarDate ... requires a subclass implementation`

The unpatched original filter is being executed.

Make sure the wrapper uses:

```text
RicohAficioSPC240DNFilter-final3
```

and not:

```text
RicohAficioSPC240DNFilter
```

---

### `Library not loaded: @executable_path/../Frameworks/libDJZModule.dylib`

The filter was copied out of its application bundle and executed separately.

It must remain in:

```text
RicohAficioSPC240DNFilter.app/Contents/MacOS/
```

because it loads:

```text
../Frameworks/libDJZModule.dylib
```

relative to its executable location.

---

### Darling tries to create `//.darling`

Example:

```text
Setting up a new Darling prefix at //.darling
Cannot create //.darling: Permission denied
```

This occurs when Darling is executed directly as the CUPS service user.

The supplied wrapper/sudo setup executes Darling using the configured desktop
user and its existing Darling environment.

---

### sudo fails for the CUPS account

An error similar to:

```text
The account is expired or the PAM configuration lacks an account section
```

means the CUPS system account is being rejected by PAM.

Verify:

```bash
sudo visudo -cf /etc/sudoers.d/ricoh-spc240
```

and ensure the file contains:

```sudoers
Defaults:cups !pam_acct_mgmt
cups ALL=(h3adbang3r) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```

---

### Empty GDI output

If the generated file is zero bytes, verify that the raster input path is
visible from inside Darling.

Linux:

```bash
ls -lh /tmp/ricoh-test.raster
```

Darling:

```bash
darling shell ls -lh /Volumes/SystemRoot/tmp/ricoh-test.raster
```

When manually invoking the macOS filter, use the Darling-visible path:

```text
/Volumes/SystemRoot/tmp/ricoh-test.raster
```

rather than:

```text
/tmp/ricoh-test.raster
```

---

## Security notes

The CUPS account is **not** granted unrestricted sudo access.

The sudoers configuration permits only:

```text
/usr/local/libexec/ricoh-spc240-ddst
```

to be executed as the configured desktop user.

Because that wrapper crosses a privilege boundary, its ownership and
permissions should prevent modification by the `cups` user.

Verify after installation:

```bash
ls -l /usr/local/libexec/ricoh-spc240-ddst
```

The wrapper should be owned by `root` and must not be writable by `cups`.

---

## CUPS deprecation notice

Classic PPD-based printer drivers and CUPS filters are deprecated upstream.

CUPS currently warns:

```text
Printer drivers are deprecated and will stop working in a future version of CUPS.
```

Therefore this project should be considered a compatibility solution for
systems where traditional CUPS driver/filter support is still available.

A future implementation may need to package the driver as a Printer
Application or otherwise isolate a compatible CUPS environment.

---

## Preservation

This repository intentionally contains:

- the original Ricoh macOS filter,
- Ricoh framework and resource files,
- the ICC profile,
- the Darling compatibility shim,
- intermediate patched binaries,
- the final working patched binary,
- the CUPS PPD and filter,
- the wrapper,
- the sudo configuration,
- and the installation script.

The intermediate binaries are deliberately preserved because they document
the reverse-engineering process rather than being ordinary disposable build
artifacts.

A future improvement would be to provide reproducible patch scripts that
generate each patched executable from the untouched original binary.

---

## Tested configuration

```text
OS:       CachyOS / Arch Linux
Printing: CUPS
Runtime:  Darling
Printer:  Ricoh Aficio SP C240DN
Protocol: JetDirect / AppSocket
Port:     TCP 9100
Driver:   Original Ricoh macOS DDST/GDI filter
Filter:   RicohAficioSPC240DNFilter-final3
Result:   WORKING
```

Successfully tested with an actual printed page:

```text
CachyOS DDST TEST
```

---

## Disclaimer

This is an unofficial compatibility project and is not affiliated with,
endorsed by, or supported by Ricoh.

The project relies on an old proprietary Ricoh macOS printer driver and on
binary compatibility patches required to execute that driver through Darling.

Use at your own risk.

---

## Result

After a rather unreasonable amount of debugging:

**Ricoh Aficio SP C240DN DDST printing works on CachyOS.** 🎉
