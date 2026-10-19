#!/usr/bin/env bash

set -euo pipefail

docker build -t racerf_builder:latest .
docker rm -f racerf_builder 2>/dev/null || true
docker run --name racerf_builder racerf_builder:latest
docker cp racerf_builder:/racerf/_opam _opam
