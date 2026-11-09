#!/usr/bin/env bash
# Start Chispa in public mode: requires CHISPA_PASSWORD, refuses to start without it.
cd "$(dirname "$0")"
if [ -z "${CHISPA_PASSWORD:-}" ]; then echo "ERROR: define CHISPA_PASSWORD para el modo público." >&2; exit 1; fi
export CHISPA_PUBLIC=1
exec ./run.sh
