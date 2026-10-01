#!/usr/bin/env bash
# Compila qabal, lo instala en el emulador (arrancándolo si hace falta) o en un teléfono conectado,
# y lo abre.
#
#   ./scripts/run.sh              emulador, con ventana
#   ./scripts/run.sh --headless   emulador sin ventana (CI o sesiones remotas)
#   ./scripts/run.sh --device     usa el dispositivo ya conectado por USB/Wi-Fi, sin emulador
#   ./scripts/run.sh --shot FILE  además guarda una captura de pantalla en FILE
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$(dirname "$0")/.."

headless=0 device=0 shot=""
while [ $# -gt 0 ]; do
  case "$1" in
    --headless) headless=1 ;;
    --device) device=1 ;;
    --shot) shift; shot="${1:?--shot necesita una ruta}" ;;
    *) die "opción desconocida: $1" ;;
  esac
  shift
done

connected() { adb devices | awk 'NR>1 && $2=="device"' | grep -q .; }

if [ "$device" -eq 0 ] && ! connected; then
  avdmanager list avd -c | grep -qx "$AVD_NAME" || die "no existe el AVD '$AVD_NAME': ejecuta ./scripts/setup-emulator.sh"
  args=(-avd "$AVD_NAME" -no-snapshot-save -no-audio -gpu swiftshader_indirect)
  [ "$headless" -eq 1 ] && args+=(-no-window)
  echo "Arrancando el emulador '$AVD_NAME'..."
  nohup emulator "${args[@]}" >/tmp/qabal-emulator.log 2>&1 &
fi

echo "Esperando al dispositivo..."
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done

echo "Compilando e instalando..."
./gradlew installDebug

adb shell am start -n "$APP_ID/.MainActivity" >/dev/null
echo "qabal abierta."

if [ -n "$shot" ]; then
  sleep 2
  adb exec-out screencap -p >"$shot"
  echo "Captura guardada en $shot"
fi
