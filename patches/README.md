# Binary patch reproduction

This directory documents the byte-level changes made to the original
`RicohAficioSPC240DNFilter` while making it usable under Darling.

The repository deliberately preserves the intermediate binaries because they were
created during the reverse-engineering process. The scripts here turn those
historical artifacts into a reproducible patch chain.

## Generate the manifest

From the repository root:

```bash
python patches/generate_patchset.py
```

This creates:

```text
patches/patchset.json
```

The manifest records for every stage:

- SHA256 of the input binary
- SHA256 of the output binary
- exact file offsets
- exact bytes before the patch
- exact replacement bytes
- a short description of the stage

The chain is:

```text
RicohAficioSPC240DNFilter
        ↓
RicohAficioSPC240DNFilter-patched
        ↓
RicohAficioSPC240DNFilter-test2
        ↓
RicohAficioSPC240DNFilter-final
        ↓
RicohAficioSPC240DNFilter-final2
        ↓
RicohAficioSPC240DNFilter-final3
```

## Rebuild from the untouched original

```bash
python patches/apply_patchset.py
```

Output:

```text
build/patched-filters/
```

Each generated stage is checked against the SHA256 stored in the manifest. If any
source byte differs, patching stops rather than modifying an unknown executable.

## Important

`patchset.json` should be committed after it has been generated and reviewed.
Once committed, `apply_patchset.py` can reproduce `final3` directly from the
untouched original without relying on the preserved intermediate binaries.
