#!/usr/bin/env bash

set -euo pipefail

ORIG_DIR=$(realpath .)
SWITCH="ocaml-variants.5.3.0+options ocaml-option-flambda"
REPO="https://github.com/TDacik/Deadlock_and_Racer"

# Cleanup
rm -rf _opam
rm -rf /tmp/_opam
rm -rf /tmp/racer

cd /tmp
opam switch create . $SWITCH

## Install RacerF
git clone $REPO racer
opam install racer/ --deps-only -y
opam install racer/ -y

## Prune switch
##
## The following needs to be preserved:
##  * bin/frama-c
##  * META files
##  * .cmxs files

# Delete switch metadata
rm -rf _opam/.opam-switch

# Delete all binaries except frama-c
rm -rf _opam/sbin
find _opam/bin -type f ! -name "frama-c" -delete

# Delete all sources
find _opam -type f -name "*.ml" -delete
find _opam -type f -name "*.mli" -delete

# Delete documentation except licenses
find _opam/doc -type f ! -name '*LICENSE*' -delete
rm -rf _opam/man

# Delete all shared files except those of Frama-C
rm -rf _opam/share/alt-ergo
rm -rf _opam/share/emacs
rm -rf _opam/share/frama-c-e-acsl
rm -rf _opam/share/ocaml
rm -rf _opam/share/why3

rm -rf _opam/share/frama-c/share/_frama-c
rm -rf _opam/share/frama-c/share/autocomplete_frama-c
rm -rf _opam/share/frama-c/share/Makefile*
rm -rf _opam/share/frama-c/share/e-acsl
rm -rf _opam/share/frama-c/share/emacs
rm -rf _opam/share/frama-c/share/mt
rm -rf _opam/share/frama-c/share/theme
rm -rf _opam/share/frama-c/share/wp

# Delete misc
find _opam -type f -name "dune-package" -delete
find _opam -type f -name "opam" -delete
find _opam -type f -name "*.exe" -delete
find _opam -type f -name "*.ico" -delete
find _opam -type f -name "*.js" -delete
find _opam -type f -name "*.png" -delete
find _opam -type f -name "*.tgz" -delete
find _opam -type f -name "*.txt" -delete

# Delete compiled files
find _opam -type f -name "*.a" -delete
find _opam -type f -name "*.o" -delete
find _opam -type f -name "*.cma" -delete
find _opam -type f -name "*.cmi" -delete
find _opam -type f -name "*.cmo" -delete
find _opam -type f -name "*.cmt" -delete
find _opam -type f -name "*.cmti" -delete
find _opam -type f -name "*.cmx" -delete
find _opam -type f -name "*.cmxa" -delete

# Deleted selected libraries
# rm -rf _opam/lib/alt-ergo*
# rm -rf _opam/lib/dune*
# rm -rf _opam/lib/ocaml*
# rm -rf _opam/lib/stdlib-shims
# rm -rf _opam/lib/stdune
# rm -rf _opam/lib/stublibs
# rm -rf _opam/lib/jane-street-headers
# rm -rf _opam/lib/zip

# Delete broken symlinks
rm _opam/bin/ocaml*

# Finally, remove all empty directories
find _opam -type d -empty -delete

# Strip all object files
find _opam -type f -name '*.so' -exec strip --strip-unneeded {} +
find _opam -type f -name '*.cmxs' -exec strip --strip-unneeded {} +
strip --strip-unneeded _opam/bin/frama-c

cp -r /tmp/_opam $ORIG_DIR

chmod +x _opam/bin/frama-c
