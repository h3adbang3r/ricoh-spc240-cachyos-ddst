#!/bin/bash
set -euo pipefail

PRINTER="Ricoh_SPC240"
DEVICE_URI="socket://172.26.47.1:9100"

if [[ $EUID -ne 0 ]]; then
    echo "Bitte mit sudo ausführen:"
    echo "  sudo ./install.sh"
    exit 1
fi

BASE="$(cd "$(dirname "$0")" && pwd)"

echo "==> Ricoh SP C240DN DDST für CachyOS installieren"

echo "==> Ricoh/Darling-Payload installieren"
mkdir -p /opt/ricoh-spc240
cp -a "$BASE/payload/." /opt/ricoh-spc240/
chmod -R a+rX /opt/ricoh-spc240

ICC="/opt/ricoh-spc240/RicohAficioSPC240DNFilter.app/Contents/Resources/RICOH Aficio SP C240DN CS.icc"

if [[ -f "$ICC" ]]; then
    chown root:root "$ICC"
    chmod 0644 "$ICC"
fi

echo "==> Darling-Wrapper installieren"
install -o root -g root -m 0755 \
    "$BASE/ricoh-spc240-ddst" \
    /usr/local/libexec/ricoh-spc240-ddst

echo "==> CUPS-Filter installieren"
install -d -m 0755 /usr/lib/cups/filter

install -o root -g root -m 0755 \
    "$BASE/cups/rastertoricohspc240" \
    /usr/lib/cups/filter/rastertoricohspc240

echo "==> sudoers-Regel installieren"
install -o root -g root -m 0440 \
    "$BASE/sudoers/ricoh-spc240" \
    /etc/sudoers.d/ricoh-spc240

visudo -cf /etc/sudoers.d/ricoh-spc240

echo "==> PPD prüfen"
cupstestppd "$BASE/cups/RicohAficioSPC240DN-CachyOS.ppd"

echo "==> CUPS-Queue einrichten"
lpadmin \
    -p "$PRINTER" \
    -E \
    -v "$DEVICE_URI" \
    -P "$BASE/cups/RicohAficioSPC240DN-CachyOS.ppd"

echo "==> CUPS neu starten"
systemctl restart cups

echo
echo "============================================"
echo " Ricoh SP C240DN Installation abgeschlossen"
echo "============================================"
echo

lpstat -p "$PRINTER" || true
lpstat -v "$PRINTER" || true

echo
echo "Testdruck z.B.:"
echo "  lp -d $PRINTER /pfad/zur/datei.pdf"
