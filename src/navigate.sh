#!/usr/bin/env bash
# Action entry point.
#   navigate.sh workspace|agent back|forward
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source lib/herdr.sh
source lib/plugin.sh

on_navigate "${1:?usage: navigate.sh workspace|agent back|forward}" \
            "${2:?usage: navigate.sh workspace|agent back|forward}"
