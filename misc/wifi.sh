#!/bin/bash
# Connects to WPA2-Enterprise (PEAP) wifi networks listed in wifi_secrets.json.
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FILE="${1:-$DIR/wifi_secrets.json}"

jq -c '.networks[]' "$FILE" | while IFS= read -r net; do
    ssid=$(jq -r '.ssid' <<<"$net")
    eap=$(jq -r '.eap // "peap"' <<<"$net")
    phase2=$(jq -r '.phase2 // "mschapv2"' <<<"$net")
    identity=$(jq -r '.identity' <<<"$net")
    password=$(jq -r '.password' <<<"$net")

    nmcli connection delete "$ssid" 2>/dev/null || true
    nmcli connection add type wifi con-name "$ssid" ssid "$ssid" \
        wifi-sec.key-mgmt wpa-eap 802-1x.eap "$eap" 802-1x.phase2-auth "$phase2" \
        802-1x.identity "$identity" 802-1x.password "$password" 802-1x.system-ca-certs no
    nmcli connection up "$ssid"
done
