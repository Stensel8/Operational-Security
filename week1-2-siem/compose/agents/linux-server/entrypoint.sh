#!/bin/bash
set -e

: "${WAZUH_MANAGER:?WAZUH_MANAGER env var moet gezet zijn (bv. wazuh.manager)}"

# Manager-adres instellen in de agent-config
sed -i "s|<address>.*</address>|<address>${WAZUH_MANAGER}</address>|" /var/ossec/etc/ossec.conf

# FIM: realtime bewaking van de testmap toevoegen, naast de standaard-syscheck
# die Wazuh al meeneemt (/etc, /usr/bin, /usr/sbin, enz., elke ~12 uur).
if ! grep -q wazuh-fim-test /var/ossec/etc/ossec.conf; then
    sed -i 's|</syscheck>|  <directories realtime="yes" report_changes="yes">/etc/wazuh-fim-test</directories>\n</syscheck>|' /var/ossec/etc/ossec.conf
fi

# Registreren bij de manager (wacht tot die bereikbaar is, duurt even bij de allereerste start)
until /var/ossec/bin/agent-auth -m "$WAZUH_MANAGER" 2>&1; do
    echo "Wachten op $WAZUH_MANAGER..."
    sleep 5
done

/usr/sbin/sshd
/var/ossec/bin/wazuh-control start
exec tail -F /var/ossec/logs/ossec.log /var/log/auth.log
