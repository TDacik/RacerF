#!/usr/bin/env bash

DIR="racerf"
ARCHIVE="racerf.zip"

set -euo pipefail

year=$(( $(date +%Y) + 1 ))

echo "Creating archive for SV-COMP'$year in $DIR..."

## Create archive

# Create tmp directory
if [[ -d "$DIR" ]]; then
    echo "Removing existing '$DIR' directory..."
    rm -rf -- "$DIR"
fi

mkdir -p -- "$DIR"

## Copy data and scripts
sed "s/\$YEAR/$year/g" data/README_template.md > "$DIR/README.md"
cp data/smoketest.sh "$DIR"
cp -r data/test_programs "$DIR/test_programs"
cp -r ../../LICENSE "$DIR"
cp -r ../../models "$DIR"
cp -r ../../scripts/*.py "$DIR"

## Patch racerf.py to ensure we are running in sv-comp mode
mv "$DIR/racerf.py" "$DIR/racerf-sv.py"

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "s/SV_COMP_MODE = False/SV_COMP_MODE = True/g" "$DIR/racerf-sv.py"
else
    sed -i "s/SV_COMP_MODE = False/SV_COMP_MODE = True/g" "$DIR/racerf-sv.py"
fi

## Build standalone binary
if [[ -d "$DIR" ]]; then
    echo "Directory _opam exists, skipping its creation"
else
    echo "Directory _opam doesn't exists, creating standalone executable"
    ./build_standalone_bin.sh
fi

cp -r _opam "$DIR"
