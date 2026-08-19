# Ricoh Aficio SP C240DN – DDST Driver for CachyOS/Linux

[🇬🇧 English](#-english) · [🇩🇪 Deutsch](#-deutsch)

> **Status:** Working / Funktioniert. Real pages have successfully been printed from CachyOS.

---

# 🇬🇧 English

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
cups ALL=(<DARLING_USER>) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```
<DARLING_USER> is automatically determined from the user who invokes
sudo ./install.sh.

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
cups ALL=(<DARLING_USER>) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```
<DARLING_USER> is automatically determined from the user who invokes
sudo ./install.sh.

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

---

# 🇩🇪 Deutsch

## Ricoh Aficio SP C240DN – DDST-Treiber für CachyOS/Linux

Funktionierende CUPS-Lösung für den **Ricoh Aficio SP C240DN**, bei der der originale
Ricoh-macOS-DDST/GDI-Filter über **Darling** ausgeführt wird.

Dieses Projekt existiert, weil der Drucker Ricohs proprietäre DDST/GDI-Druckersprache
verwendet und der originale macOS-Filter nicht nativ unter Linux ausgeführt werden kann.

Der originale Ricoh-Filter wurde gepatcht, um Inkompatibilitäten zwischen dem alten
macOS-Treiber und Darling zu umgehen.

Getestet unter **CachyOS / Arch Linux** mit CUPS und einem Ricoh Aficio SP C240DN,
angebunden über JetDirect/AppSocket (`socket://...:9100`).

> **Status:** Funktioniert. Reale Seiten wurden erfolgreich aus CachyOS gedruckt.

---

## Übersicht

Der Druckpfad lautet:

```text
Linux-Anwendung
       │
       ▼
      CUPS
       │
       ▼
CUPS-Rasterdaten
       │
       ▼
rastertoricohspc240
       │
       ▼
ricoh-spc240-ddst
       │
       ▼
sudo: cups → Desktop-Benutzer
       │
       ▼
Darling
       │
       ▼
gepatchter Ricoh-macOS-DDST-Filter
       │
       ▼
Ricoh-GDI/DDST-Datenstrom
       │
       ▼
socket://DRUCKER_IP:9100
       │
       ▼
Ricoh Aficio SP C240DN
```

Die erzeugten Druckerdaten beginnen mit dem erwarteten Ricoh-GDI-Header:

```text
GDIJ
```

und ein erfolgreich abgeschlossener Auftrag endet mit:

```text
JIDG
```

---

## Warum Darling benötigt wird

Ricoh lieferte für diesen Drucker einen macOS-Filter aus, der die proprietäre Logik
enthält, um gerasterte Druckdaten in das vom Drucker verstandene GDI/DDST-Format
umzuwandeln.

Anstatt das komplette proprietäre Ausgabeformat neu zu implementieren, führt diese
Lösung den originalen x86_64-macOS-Filter über Darling aus.

Der ursprüngliche Filter ist allerdings alt genug, um auf mehrere
Kompatibilitätsprobleme in Darling zu treffen. Deshalb enthält die von diesem Projekt
verwendete ausführbare Datei einige kleine Binär-Patches.

---

## Repository-Struktur

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

Die Zwischenversionen des Filters werden absichtlich aufbewahrt. Sie dokumentieren
die Reverse-Engineering- und Kompatibilitätsarbeit, die zum funktionierenden Filter
geführt hat.

---

## Gepatchte Filter-Binaries

Das Verzeichnis `MacOS` enthält das originale Ricoh-Programm sowie die verschiedenen
Versionen, die während des Debuggings unter Darling entstanden sind.

| Binary | Beschreibung |
|---|---|
| `RicohAficioSPC240DNFilter` | Originaler, unveränderter Ricoh-macOS-Filter |
| `RicohAficioSPC240DNFilter-patched` | Erster Kompatibilitäts-Patch |
| `RicohAficioSPC240DNFilter-test2` | Experimentell gepatchte Version |
| `RicohAficioSPC240DNFilter-final` | Zwischenversion für Funktionstests/Debugging |
| `RicohAficioSPC240DNFilter-final2` | Späterer Control-Flow-Fix; erzeugt vollständige GDI-Ausgabe |
| `RicohAficioSPC240DNFilter-final3` | **Aktuelle Produktivversion; erzeugt gültige GDI-Ausgabe und beendet sich erfolgreich** |

Der produktive Wrapper verwendet:

```text
RicohAficioSPC240DNFilter-final3
```

Die älteren Binaries werden für den normalen Druckbetrieb nicht benötigt, bleiben
aber bewusst als Dokumentation des Reverse-Engineering-Prozesses erhalten.

---

## Kompatibilitäts-Patches

### 1. NSCalendarDate-Absturz

Der originale Filter ruft auf:

```objc
[NSCalendarDate date]
```

gefolgt von:

```objc
destinyDate
```

Unter Darling führte dies zu:

```text
NSCalendarDate initWithTimeIntervalSinceReferenceDate:
requires a subclass implementation
```

und beendete den Filter mit:

```text
Abort trap: 6
Exit-Code: 134
```

Der relevante originale Codepfad war:

```asm
movq    *OBJC_CLASS*$_NSCalendarDate, %rdi
callq   ...                 ; date
leaq    ..., %rsi           ; destinyDate
movq    %rax, %rdi
callq   ...
bswapl  %eax
movl    %eax, 0x14(%rbx)
```

Diese Zeitstempelerzeugung ist für brauchbare Druckerdaten nicht erforderlich,
deshalb wurde der inkompatible Codepfad umgangen.

Nach diesem Patch gelangte der Filter in die eigentliche Rasterverarbeitung.

---

### 2. End-of-page-/Control-Flow-Problem

Nach dem Umgehen des Calendar-Absturzes wurde die komplette Rasterseite verarbeitet:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
```

der Prozess konnte jedoch mit folgendem Fehler abbrechen:

```text
Floating point exception: 8
Exit-Code: 136
```

Die weitere Analyse identifizierte einen inkompatiblen Control-Flow-Pfad im Bereich
der End-of-page-Verarbeitung.

Die späteren Patches umgehen diesen Pfad und erlauben dem Filter, den Auftrag
ordnungsgemäß abzuschließen.

Die finale Version meldet:

```text
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

und beendet sich mit:

```text
Exit-Code: 0
```

---

## Erfolgreiche Ausgabe

Ein erfolgreich erzeugter Datenstrom beginnt mit:

```text
47 44 49 4a
G  D  I  J
```

Beispiel:

```text
00000000  47 44 49 4a 00 00 00 78  00 64 00 01 00 00 00 00
00000010  00 00 00 a8 00 00 00 00  00 00 00 00 00 00 00 00
```

und endet mit:

```text
4a 49 44 47
J  I  D  G
```

Ein realer Druckauftrag mit dieser Ausgabe wurde erfolgreich vom
Ricoh Aficio SP C240DN gedruckt.

---

## Voraussetzungen

Der Host benötigt:

- Linux
- CUPS
- Darling
- `sudo`
- die in `payload/` enthaltenen originalen Ricoh-Filter-Ressourcen
- einen über das Netzwerk erreichbaren Ricoh Aficio SP C240DN

Die aktuelle Lösung wurde unter CachyOS entwickelt und getestet.

Der Drucker wird über Raw JetDirect/AppSocket auf TCP-Port 9100 angesprochen.

---

## CUPS-Benutzer

Auf der getesteten CachyOS-Installation führt CUPS Druckfilter aus als:

```text
User 209
Group 209
```

Dies entspricht:

```text
cups:x:209:209:cups helper user:/:/usr/bin/nologin
```

Darling kann unter diesem Service-Account nicht ohne Weiteres normal arbeiten, da
eine verwendbare Benutzerumgebung bzw. ein Darling-Prefix benötigt wird.

Der Wrapper führt Darling deshalb über eine eng begrenzte sudo-Regel als
Desktop-Benutzer aus.

---

## sudo-Konfiguration

Die benötigte Regel befindet sich in:

```text
sudoers/ricoh-spc240
```

Inhalt:

```sudoers
Defaults:cups !pam_acct_mgmt
cups ALL=(<DARLING_USER>) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```
<DARLING_USER> wird automatisch aus dem Benutzer ermittelt,
der sudo ./install.sh aufruft.

Der `pam_acct_mgmt`-Override wird benötigt, weil der `cups`-Service-Account als
Systemkonto mit `nologin` konfiguriert ist und sudo andernfalls mit einem
Account-/PAM-Fehler abbricht.

Die Berechtigung ist bewusst eng gefasst:

**`cups` darf ausschließlich `/usr/local/libexec/ricoh-spc240-ddst` als den
konfigurierten Desktop-Benutzer ohne Passwort ausführen.**

Vor der Installation validieren:

```bash
sudo visudo -cf sudoers/ricoh-spc240
```

Erwartetes Ergebnis:

```text
sudoers/ricoh-spc240: parsed OK
```

oder bei deutscher Locale:

```text
Analyse OK
```

---

## Installation

Ausführen:

```bash
sudo ./install.sh
```

Der Installer installiert die benötigten Dateien ins System.

Die wichtigsten Komponenten sind:

```text
/opt/ricoh-spc240/
/usr/local/libexec/ricoh-spc240-ddst
/usr/lib/cups/filter/rastertoricohspc240
/etc/cups/ppd/
/etc/sudoers.d/ricoh-spc240
```

Die exakten Installationspfade können in `install.sh` eingesehen werden.

---

## PPD validieren

Die mitgelieferte PPD kann geprüft werden mit:

```bash
cupstestppd -v cups/RicohAficioSPC240DN-CachyOS.ppd
```

Die finale PPD besteht die Prüfung mit:

```text
KEINE FEHLER GEFUNDEN
```

Einige Warnungen zu älteren Papierformatnamen sowie zur historischen
8.3-Dateinamensempfehlung der PPD-Spezifikation bleiben bestehen. Sie verhindern
den Betrieb nicht.

---

## Drucker hinzufügen

`DRUCKER_IP` durch die Adresse des Druckers ersetzen:

```bash
sudo lpadmin \
    -p Ricoh_SPC240 \
    -E \
    -v socket://DRUCKER_IP:9100 \
    -P cups/RicohAficioSPC240DN-CachyOS.ppd
```

Beispiel:

```bash
sudo lpadmin \
    -p Ricoh_SPC240 \
    -E \
    -v socket://172.26.47.1:9100 \
    -P cups/RicohAficioSPC240DN-CachyOS.ppd
```

Aktuelle CUPS-Versionen können melden:

```text
lpadmin: Printer drivers are deprecated and will stop working in a future
version of CUPS.
```

Das ist zu erwarten, weil dieses Projekt bewusst die klassische
PPD-/Filter-Architektur von CUPS verwendet.

---

## Druckerstatus prüfen

```bash
lpstat -p Ricoh_SPC240
```

und:

```bash
lpstat -v Ricoh_SPC240
```

Die Device-URI sollte ungefähr so aussehen:

```text
socket://DRUCKER_IP:9100
```

---

## Wrapper testen

Zum Debugging kann eine Rasterdatei direkt durch den Wrapper geschickt werden.

Der Wrapper ruft den gepatchten Filter letztlich über Darling mit folgenden
Variablen auf:

```text
DYLD_FORCE_FLAT_NAMESPACE=1
DYLD_INSERT_LIBRARIES=/Volumes/SystemRoot/tmp/libppdshim.dylib
```

Eine erfolgreiche Konvertierung sollte:

1. alle Raster-Bänder verarbeiten,
2. einen GDI-Datenstrom schreiben,
3. `JIDG` anhängen,
4. mit Status `0` enden.

Beispiel für das Ende des Logs:

```text
RasterFilter run: Processed 6816 lines
RasterFilter endPage: blankAccumulator = 0xff
GDIFilter endJob:
GDIFilter endJob: sending JIDG
RasterFilter run: exiting - result: 1
rasterToGDI ending with result 0
```

---

## Debugging der erzeugten Ausgabe

Anfang einer erzeugten Datei prüfen:

```bash
head -c 128 output.gdi | hexdump -C
```

Ein gültiger Datenstrom sollte beginnen mit:

```text
47 44 49 4a
```

oder:

```text
GDIJ
```

Ende prüfen:

```bash
tail -c 32 output.gdi | hexdump -C
```

Ein abgeschlossener Auftrag sollte enden mit:

```text
4a 49 44 47
```

oder:

```text
JIDG
```

---

## Fehlerbehebung

### `NSCalendarDate ... requires a subclass implementation`

Der ungepatchte Originalfilter wird ausgeführt.

Sicherstellen, dass der Wrapper verwendet:

```text
RicohAficioSPC240DNFilter-final3
```

und nicht:

```text
RicohAficioSPC240DNFilter
```

### `Library not loaded: @executable_path/../Frameworks/libDJZModule.dylib`

Der Filter wurde aus seinem Application-Bundle herauskopiert und separat ausgeführt.

Er muss verbleiben unter:

```text
RicohAficioSPC240DNFilter.app/Contents/MacOS/
```

weil er:

```text
../Frameworks/libDJZModule.dylib
```

relativ zu seinem Programmverzeichnis lädt.

### Darling versucht `//.darling` anzulegen

Beispiel:

```text
Setting up a new Darling prefix at //.darling
Cannot create //.darling: Permission denied
```

Das passiert, wenn Darling direkt als CUPS-Service-Benutzer ausgeführt wird.

Das mitgelieferte Wrapper-/sudo-Setup führt Darling mit dem konfigurierten
Desktop-Benutzer und dessen vorhandener Darling-Umgebung aus.

### sudo schlägt für den CUPS-Account fehl

Ein Fehler ähnlich:

```text
The account is expired or the PAM configuration lacks an account section
```

bedeutet, dass der CUPS-Systemaccount von PAM abgewiesen wird.

Prüfen:

```bash
sudo visudo -cf /etc/sudoers.d/ricoh-spc240
```

und sicherstellen, dass die Datei enthält:

```sudoers
Defaults:cups !pam_acct_mgmt
cups ALL=(<DARLING_USER>) NOPASSWD: /usr/local/libexec/ricoh-spc240-ddst
```
<DARLING_USER> wird automatisch aus dem Benutzer ermittelt,
der sudo ./install.sh aufruft.

### Leere GDI-Ausgabe

Wenn die erzeugte Datei null Byte groß ist, prüfen, ob der Raster-Eingabepfad
innerhalb von Darling sichtbar ist.

Linux:

```bash
ls -lh /tmp/ricoh-test.raster
```

Darling:

```bash
darling shell ls -lh /Volumes/SystemRoot/tmp/ricoh-test.raster
```

Beim manuellen Aufruf des macOS-Filters den für Darling sichtbaren Pfad verwenden:

```text
/Volumes/SystemRoot/tmp/ricoh-test.raster
```

anstatt:

```text
/tmp/ricoh-test.raster
```

---

## Sicherheitshinweise

Der CUPS-Account erhält **keinen** uneingeschränkten sudo-Zugriff.

Die sudoers-Konfiguration erlaubt ausschließlich:

```text
/usr/local/libexec/ricoh-spc240-ddst
```

als den konfigurierten Desktop-Benutzer auszuführen.

Da der Wrapper eine Privilegiengrenze überschreitet, müssen Eigentümer und
Dateirechte verhindern, dass der Benutzer `cups` ihn verändern kann.

Nach der Installation prüfen:

```bash
ls -l /usr/local/libexec/ricoh-spc240-ddst
```

Der Wrapper sollte `root` gehören und darf für `cups` nicht schreibbar sein.

---

## CUPS-Deprecation-Hinweis

Klassische PPD-basierte Druckertreiber und CUPS-Filter sind upstream als veraltet
markiert.

CUPS warnt derzeit:

```text
Printer drivers are deprecated and will stop working in a future version of CUPS.
```

Dieses Projekt sollte daher als Kompatibilitätslösung für Systeme betrachtet werden,
auf denen die traditionelle CUPS-Treiber-/Filter-Unterstützung noch verfügbar ist.

Eine zukünftige Implementierung könnte den Treiber als Printer Application
paketieren oder anderweitig eine kompatible CUPS-Umgebung isolieren.

---

## Archivierung

Dieses Repository enthält absichtlich:

- den originalen Ricoh-macOS-Filter,
- Ricoh-Framework- und Ressourcendateien,
- das ICC-Profil,
- den Darling-Kompatibilitäts-Shim,
- Zwischenversionen der gepatchten Binaries,
- das finale funktionierende gepatchte Binary,
- die CUPS-PPD und den Filter,
- den Wrapper,
- die sudo-Konfiguration
- sowie das Installationsskript.

Die Zwischen-Binaries bleiben bewusst erhalten, weil sie den Reverse-Engineering-
Prozess dokumentieren und keine gewöhnlichen wegwerfbaren Build-Artefakte darstellen.

Eine zukünftige Verbesserung wäre die Bereitstellung reproduzierbarer Patch-Skripte,
die jede gepatchte ausführbare Datei aus dem unveränderten Original-Binary erzeugen.

---

## Getestete Konfiguration

```text
OS:       CachyOS / Arch Linux
Drucken:  CUPS
Runtime:  Darling
Drucker:  Ricoh Aficio SP C240DN
Protokoll: JetDirect / AppSocket
Port:     TCP 9100
Treiber:  Originaler Ricoh macOS DDST/GDI-Filter
Filter:   RicohAficioSPC240DNFilter-final3
Ergebnis: FUNKTIONIERT
```

Erfolgreich mit einer tatsächlich gedruckten Seite getestet:

```text
CachyOS DDST TEST
```

Zusätzlich erfolgreich aus einer browserbasierten Tabellenkalkulation über CUPS
auf dem realen Drucker getestet.

---

## Haftungsausschluss

Dies ist ein inoffizielles Kompatibilitätsprojekt und steht in keiner Verbindung
zu Ricoh, wird nicht von Ricoh unterstützt und ist nicht von Ricoh autorisiert.

Das Projekt verwendet einen alten proprietären Ricoh-macOS-Druckertreiber sowie
Binär-Kompatibilitäts-Patches, die erforderlich sind, um diesen Treiber über Darling
auszuführen.

Nutzung auf eigene Gefahr.

---

## Ergebnis

Nach einer eher unangemessenen Menge Debugging:

**DDST-Drucken mit dem Ricoh Aficio SP C240DN funktioniert unter CachyOS.** 🎉
