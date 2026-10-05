#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
runtime_root=$(mktemp -d -t desktop-clock-runtime.XXXXXXXX)
trap 'rm -rf -- "$runtime_root"' EXIT

mkdir -- "$runtime_root/Plugin"
cp -- "$project_root"/*.qml "$runtime_root/Plugin/"
cp -r -- "$project_root/renderer" "$runtime_root/Plugin/renderer"
cp -- "$project_root/tests/Runtime.qml" "$runtime_root/shell.qml"
ln -s -- "$omarchy_root/shell/Commons" "$runtime_root/Commons"
ln -s -- "$omarchy_root/shell/Ui" "$runtime_root/Ui"
QT_QUICK_BACKEND=software QSG_RENDER_LOOP=basic timeout 20s quickshell -p "$runtime_root" --no-color 2>&1 | tee "$runtime_root/output.log"
rg -q '^.*CLOCK_RUNTIME_TESTS_PASSED$' "$runtime_root/output.log"
if rg -q 'CLOCK_RUNTIME_TESTS_FAILED|TypeError|ReferenceError|Binding loop|Unable to assign' "$runtime_root/output.log"; then exit 1; fi
