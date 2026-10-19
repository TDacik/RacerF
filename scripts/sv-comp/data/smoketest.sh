#!/usr/bin/env sh

trap 'rc=$?; [ $rc -ne 0 ] && echo ": ERROR $rc"' EXIT

set -e

echo -n "Testing Frama-C installation"
./_opam/bin/frama-c -version >/dev/null 2>&1
echo ": OK"

echo -n "Testing Racer-F installation"
python3 racerf-sv.py --version >/dev/null 2>&1
echo ": OK"

echo -n "Testing program with a race"
python3 racerf-sv.py test_programs/simple_race.c >/dev/null 2>&1
echo ": OK"

echo -n "Testing program without races"
python3 racerf-sv.py test_programs/simple_no_race.c >/dev/null 2>&1
echo ": OK"
