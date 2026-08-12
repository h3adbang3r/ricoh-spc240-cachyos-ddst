#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Ricoh Aficio SP C240DN – CachyOS / CUPS / Darling DDST
# Installer
# ============================================================

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PAYLOAD_SRC="$BASE/payload"
CUPS_SRC="$BASE/cups"
SUDOERS_SRC="$BASE/sudoers/ricoh-spc240"

INSTALL_BASE="/opt/ricoh-spc240"
APP="$INSTALL_BASE/RicohAficioSPC240DNFilter.app"

WRAPPER_SRC="$BASE/ricoh-spc240-ddst"
WRAPPER_DST="/usr/local/libexec/ricoh-spc240-ddst"

CUPS_FILTER_SRC="$CUPS_SRC/rastertoricohspc240"
CUPS_FILTER_DST="/usr/lib/cups/filter/rastertoricohspc240"

PPD_SRC="$CUPS_SRC/RicohAficioSPC240DN-CachyOS.ppd"
PPD_DST="/usr/share/cups/model/RicohAficioSPC240DN-CachyOS.ppd"

SUDOERS_DST="/etc/sudoers.d/ricoh-spc240"


# ------------------------------------------------------------
# Root prüfen
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "FEHLER: Dieses Script muss als root ausgeführt werden."
    echo
    echo "Bitte verwenden:"
    echo "  sudo ./install.sh"
    exit 1
fi


# ------------------------------------------------------------
# Voraussetzungen prüfen
# ------------------------------------------------------------

echo "==> Voraussetzungen prüfen"

if ! command -v darling >/dev/null 2>&1; then
    echo "FEHLER: Darling wurde nicht gefunden."
    echo "Darling muss vor der Installation eingerichtet sein."
    exit 1
fi

if ! command -v cupstestppd >/dev/null 2>&1; then
    echo "FEHLER: cupstestppd wurde nicht gefunden."
    echo "Bitte CUPS installieren."
    exit 1
fi

if ! command -v visudo >/dev/null 2>&1; then
    echo "FEHLER: visudo wurde nicht gefunden."
    echo "Bitte sudo installieren."
    exit 1
fi


# ------------------------------------------------------------
# Repo-Struktur prüfen
# ------------------------------------------------------------

echo "==> Repository prüfen"

for path in \
    "$PAYLOAD_SRC" \
    "$WRAPPER_SRC" \
    "$CUPS_FILTER_SRC" \
    "$PPD_SRC" \
    "$SUDOERS_SRC"
do
    if [[ ! -e "$path" ]]; then
        echo "FEHLER: Benötigte Datei/Verzeichnis fehlt:"
        echo "  $path"
        exit 1
    fi
done


# ------------------------------------------------------------
# Ricoh/Darling Payload
# ------------------------------------------------------------

echo "==> Ricoh/Darling-Payload installieren"

rm -rf "$INSTALL_BASE"
mkdir -p "$INSTALL_BASE"

cp -a "$PAYLOAD_SRC/." "$INSTALL_BASE/"


# ------------------------------------------------------------
# Sichere Eigentümer und Rechte
#
# Wichtig für CUPS:
# Ressourcen und ICC-Profil dürfen nicht einem normalen
# Benutzer gehören.
# ------------------------------------------------------------

echo "==> Payload-Rechte setzen"

chown -R root:root "$INSTALL_BASE"

find "$INSTALL_BASE" -type d -exec chmod 0755 {} +
find "$INSTALL_BASE" -type f -exec chmod 0644 {} +


# ------------------------------------------------------------
# Mach-O-Binaries ausführbar machen
# ------------------------------------------------------------

echo "==> Ricoh-Binaries ausführbar machen"

for binary in \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter" \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter-patched" \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter-test2" \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter-final" \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter-final2" \
    "$APP/Contents/MacOS/RicohAficioSPC240DNFilter-final3"
do
    if [[ -f "$binary" ]]; then
        chmod 0755 "$binary"
    fi
done


# ------------------------------------------------------------
# Darling Wrapper
# ------------------------------------------------------------

echo "==> Darling-Wrapper installieren"

install -d -m 0755 /usr/local/libexec

install \
    -o root \
    -g root \
    -m 0755 \
    "$WRAPPER_SRC" \
    "$WRAPPER_DST"


# ------------------------------------------------------------
# CUPS Filter
# ------------------------------------------------------------

echo "==> CUPS-Filter installieren"

install -d -m 0755 /usr/lib/cups/filter

install \
    -o root \
    -g root \
    -m 0755 \
    "$CUPS_FILTER_SRC" \
    "$CUPS_FILTER_DST"


# ------------------------------------------------------------
# PPD
# ------------------------------------------------------------

echo "==> PPD installieren"

install -d -m 0755 /usr/share/cups/model

install \
    -o root \
    -g root \
    -m 0644 \
    "$PPD_SRC" \
    "$PPD_DST"


# ------------------------------------------------------------
# sudoers
#
# CUPS läuft als UID/GID 209 (cups).
# Der Darling-Wrapper wird über den Benutzer h3adbang3r
# gestartet.
# ------------------------------------------------------------

echo "==> sudoers-Regel installieren"

if ! visudo -cf "$SUDOERS_SRC"; then
    echo "FEHLER: sudoers-Datei ist ungültig."
    exit 1
fi

install \
    -o root \
    -g root \
    -m 0440 \
    "$SUDOERS_SRC" \
    "$SUDOERS_DST"

if ! visudo -cf "$SUDOERS_DST"; then
    echo "FEHLER: Installierte sudoers-Datei ist ungültig."
    rm -f "$SUDOERS_DST"
    exit 1
fi


# ------------------------------------------------------------
# PPD validieren
# ------------------------------------------------------------

echo "==> PPD validieren"

if ! cupstestppd -q "$PPD_DST"; then
    echo
    echo "FEHLER: PPD-Konformitätstest fehlgeschlagen."
    echo
    cupstestppd -v "$PPD_DST" || true
    exit 1
fi


# ------------------------------------------------------------
# Installationsrechte kontrollieren
# ------------------------------------------------------------

echo "==> Installationsrechte kontrollieren"

if [[ "$(stat -c '%U:%G' "$INSTALL_BASE")" != "root:root" ]]; then
    echo "FEHLER: $INSTALL_BASE gehört nicht root:root."
    exit 1
fi

if [[ "$(stat -c '%a' "$APP/Contents/Resources")" != "755" ]]; then
    echo "FEHLER: Resources-Verzeichnis besitzt falsche Rechte."
    exit 1
fi

ICC="$APP/Contents/Resources/RICOH Aficio SP C240DN CS.icc"

if [[ -f "$ICC" ]]; then
    if [[ "$(stat -c '%U:%G' "$ICC")" != "root:root" ]]; then
        echo "FEHLER: ICC-Profil gehört nicht root:root."
        exit 1
    fi

    if [[ "$(stat -c '%a' "$ICC")" != "644" ]]; then
        echo "FEHLER: ICC-Profil besitzt falsche Rechte."
        exit 1
    fi
fi


# ------------------------------------------------------------
# CUPS neu laden
# ------------------------------------------------------------

echo "==> CUPS neu starten"

if command -v systemctl >/dev/null 2>&1; then
    systemctl restart cups.service
fi


# ------------------------------------------------------------
# Fertig
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Ricoh Aficio SP C240DN DDST Installation abgeschlossen"
echo "============================================================"
echo
echo "Installiert:"
echo "  Payload : $INSTALL_BASE"
echo "  Wrapper : $WRAPPER_DST"
echo "  Filter  : $CUPS_FILTER_DST"
echo "  PPD     : $PPD_DST"
echo "  sudoers : $SUDOERS_DST"
echo
echo "PPD-Test:"
cupstestppd -q "$PPD_DST" && echo "  OK"
echo
echo "Drucker kann beispielsweise so angelegt werden:"
echo
echo "  sudo lpadmin \\"
echo "      -p Ricoh_SPC240 \\"
echo "      -E \\"
echo "      -v socket://172.26.47.1:9100 \\"
echo "      -P $PPD_DST"
echo
echo "Danach Testseite senden mit:"
echo
echo "  lp -d Ricoh_SPC240 /usr/share/cups/data/testprint"
echo
