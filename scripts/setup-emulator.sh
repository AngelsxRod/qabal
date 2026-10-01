#!/usr/bin/env bash
# Prepara lo necesario para probar qabal: imagen de sistema, AVD y comprobación de KVM.
# Es idempotente: se puede ejecutar las veces que haga falta.
set -euo pipefail
source "$(dirname "$0")/env.sh"

[ -r /dev/kvm ] && [ -w /dev/kvm ] || echo "aviso: /dev/kvm no es accesible; el emulador irá muy lento (añade tu usuario al grupo 'kvm')." >&2

if [ ! -d "$ANDROID_HOME/system-images/$(echo "$AVD_IMAGE" | cut -d';' -f2-4 | tr ';' '/')" ]; then
  echo "Instalando la imagen $AVD_IMAGE..."
  yes | sdkmanager --install "$AVD_IMAGE" >/dev/null
fi

if avdmanager list avd -c | grep -qx "$AVD_NAME"; then
  echo "El AVD '$AVD_NAME' ya existe."
else
  echo "Creando el AVD '$AVD_NAME' ($AVD_DEVICE)..."
  # avdmanager avisa de un devices.xml ausente en la imagen (inofensivo) y no siempre falla con
  # código distinto de cero, así que se comprueba el resultado.
  echo no | avdmanager create avd --name "$AVD_NAME" --package "$AVD_IMAGE" --device "$AVD_DEVICE" >/dev/null 2>&1 || true
  avdmanager list avd -c | grep -qx "$AVD_NAME" || die "no se pudo crear el AVD '$AVD_NAME'"
  # Más memoria y teclado de hardware para escribir desde el PC.
  cfg="$HOME/.android/avd/$AVD_NAME.avd/config.ini"
  sed -i 's/^hw.ramSize=.*/hw.ramSize=3072/; s/^hw.keyboard=.*/hw.keyboard=yes/' "$cfg"
fi

echo "Listo. Siguiente paso: ./scripts/run.sh"
