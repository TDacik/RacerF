# RacerF (SV-COMP $YEAR)

RacerF is a data race detector for C, implemented as a plugin of the
[Frama-C](https://frama-c.com/) platform. The source code of RacerF
can be found at [github](https://github.com/TDacik/Deadlock\_Racer).

## Usage

The SV-COMP wrapper for RacerF is invoked as:

```
./racerf-sv.py -machdep=[gcc_x86_32|gcc_x86_64] <source_files>
```

The `machdep` option specifies the target architecture, with values corresponding
to ILP\_32 and LP64 as used in SV-COMP, respectively.

## Content

The content of this archive is:

* racerf-sv.py ... Wrapper for setting the environment and running RacerF.

* {preprocess, check\_sources, transformations}.py ... Helper scripts for the analysis

* smoketest.sh ... Smoke test.

* test\_programs ... Simple test programs used by smoke test.

* models/ ... RacerF's models for atomic types.

* \_opam/bin/frama-c ... Frama-C binary, needs to be run via the wrapper script.

* \_opam/lib ... Dynamically-linked libraries needed by Frama-C/RacerF. The licenses and READMEs
                 are included in corresponding folders in _opam/_opam/doc.

* \_opam/share ... Models used by Frama-C.

## License

RacerF is licensed under MIT license.

Licenses for Frama-C and its dynamic dependencies are available in `_opam/doc/<package_name>`.
