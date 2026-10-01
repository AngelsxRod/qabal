#!/usr/bin/env bash
# Entorno común de los scripts: ubica el SDK de Android y define los nombres del AVD y la app.
# Se usa con `source`; no ejecutar directamente.

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

AVD_NAME="${AVD_NAME:-qabal_pixel}"
AVD_DEVICE="${AVD_DEVICE:-pixel_7}"
AVD_IMAGE="${AVD_IMAGE:-system-images;android-36;google_apis;x86_64}"
APP_ID="com.draskint.qabal"

die() { echo "error: $*" >&2; exit 1; }

[ -d "$ANDROID_HOME" ] || die "no encuentro el SDK de Android en $ANDROID_HOME (define ANDROID_HOME)"
for tool in adb emulator avdmanager; do
  command -v "$tool" >/dev/null || die "falta '$tool' en el SDK ($ANDROID_HOME)"
done
