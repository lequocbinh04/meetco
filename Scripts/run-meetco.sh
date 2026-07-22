#!/bin/bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$project_root/dist/Meetco.app"

if [[ ! -d "$bundle" ]]; then
    "$project_root/Scripts/build-app-bundle.sh"
fi

open "$bundle"
