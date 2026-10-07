#!/bin/bash
# Write each script's -h output to build/help/, included by the docs script pages

set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out_dir="${repo_dir}/build/help"
mkdir -p "$out_dir"

for script in "$repo_dir"/scripts/*_*.sh; do
    name="$(basename "$script" .sh)"
    bash "$script" -h > "${out_dir}/${name}.txt"
done
