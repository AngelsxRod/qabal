#!/usr/bin/env bash
# Muestra el logcat de qabal (solo los procesos de la app). Ctrl+C para salir.
set -euo pipefail
source "$(dirname "$0")/env.sh"

pid=$(adb shell pidof "$APP_ID" | tr -d '\r' || true)
[ -n "$pid" ] || die "qabal no está en ejecución: ábrela con ./scripts/run.sh"
exec adb logcat --pid="$pid"
