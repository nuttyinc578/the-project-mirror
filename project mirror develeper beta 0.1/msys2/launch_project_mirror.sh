#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
ruby launch_project_mirror.rb "$@"
