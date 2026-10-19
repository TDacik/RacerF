#!/usr/bin/env bash

set -euo pipefail

docker build -t racerf_builder:latest .
docker rm racerf_builder
docker run --name racerf_builder -it racerf_builder:latest
docker cp racerf_builder:_opam _opam
