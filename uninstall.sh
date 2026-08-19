#!/usr/bin/env bash
set -euo pipefail

PRINTER="${PRINTER:-Ricoh_SPC240}"

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root:"
    echo "  sudo ./uninstall.sh"
    exit 1
fi

echo "==> Removing CUPS queue (if present)"
if lpstat -p "$PRINTER" >/dev/null 2>&1; then
    lpadmin -x "$PRINTER"
else
    echo "    Queue '$PRINTER' not present."
fi

echo "==> Removing Ricoh CUPS filter"
rm -f /usr/lib/cups/filter/rastertoricohspc240

echo "==> Removing Darling wrapper"
rm -f /usr/local/libexec/ricoh-spc240-ddst

echo "==> Removing sudoers rule"
rm -f /etc/sudoers.d/ricoh-spc240

echo "==> Removing generated configuration"
rm -f /etc/ricoh-spc240.conf

echo "==> Removing installed PPD/model"
rm -f /usr/share/cups/model/RicohAficioSPC240DN-CachyOS.ppd

echo "==> Removing Ricoh payload"
rm -rf /opt/ricoh-spc240

echo "==> Restarting CUPS"
if command -v systemctl >/dev/null 2>&1; then
    systemctl restart cups.service
fi

echo
echo "Ricoh SP C240DN compatibility driver removed."
echo "Darling itself and the user's Darling prefix were intentionally left untouched."
