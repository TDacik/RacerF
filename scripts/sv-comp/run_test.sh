#!/usr/bin/env bash

set -euo pipefail

docker build --no-cache -f Dockerfile.test -t racerf_test:latest .
docker run --rm -it racerf_test:latest
