# Roadmap

The project currently solves Ricoh Aficio SP C240DN printing by reusing and
patching Ricoh's original macOS DDST/GDI filter under Darling.

## V1 — Darling + original Ricoh filter ✅

**Status: working**

Goal: make the physical printer usable from normal Linux applications.

Implemented:

- CUPS integration
- CUPS raster → Ricoh filter pipeline
- original Ricoh macOS DDST/GDI filter executed through Darling
- PPD compatibility fixes
- `libppdshim.dylib` for the original driver's PPD lookup
- Darling compatibility patches
- CUPS service-user → Darling-user handoff
- JetDirect/AppSocket output over TCP/9100
- installer and uninstaller
- successful printing from normal applications, including browser-based office software

Production binary:

```text
RicohAficioSPC240DNFilter-final3
```

## V2 — Reproducible compatibility patches 🚧

Goal: make every change to the proprietary Mach-O binary transparent and
reproducible.

Planned / in progress:

- exact byte-level patch manifest
- SHA256 verification of every binary stage
- rebuild `final3` from the untouched original
- document the reason for every modified instruction/range
- reduce dependence on preserved intermediate binaries
- add regression/reference outputs for known-good jobs
- verify monochrome, color, duplex and multi-page jobs independently

The `patches/` directory is the foundation for this stage.

## V3 — Native DDST/GDI filter 🔬

Goal: remove Darling and the proprietary Ricoh binary from the runtime path.

Possible direction:

```text
CUPS Raster
    ↓
native rastertoricohspc240
    ↓
Ricoh DDST/GDI
    ↓
TCP/9100
```

Research topics:

- fully document `GDIJ`, `GJET`, `GDIB`, `JIDG` structures
- compare known raster input with Ricoh-filter output
- document band headers and page/job metadata
- understand DJZ/JBIG usage in `libDJZModule.dylib`
- identify whether an existing open-source Ricoh/DDST implementation can be adapted
- reproduce monochrome output first
- add color and duplex only after the base stream is understood

V3 is intentionally considered research. V1 remains the stable practical solution
until a native implementation can reproduce real print jobs reliably.

## Non-goals

- replacing CUPS itself
- modifying printer firmware
- claiming support for unrelated Ricoh models without hardware testing
