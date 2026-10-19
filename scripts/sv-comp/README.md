# Scripts for automating SV-COMP related tasks

## Standalone binary

Build a "standalone binary" of Frama-C with RacerF installed (requires Docker):

```shellSession
./build_standalone_bin.sh
```

This script uses Docker to install Frama-C with RacerF inside /tmp directory
such that all paths harcoded by opam are inside /tmp.

## Create submission archive

```shellSession
./prepare_archive.sh
```

Create a submission archive for SV-COMP'X (where X is current year + 1) containing:
- LICENSE (extracted from this repository)
- README.md (create from template in data/README\_template.md
- \_opam (opam switch buil using above described procedure)
- racerf-sv.py + several other python scripts (extracted from this repository)
- smoketest.sh + test\_programs (copied from data)
- models (extracted from this repository)
