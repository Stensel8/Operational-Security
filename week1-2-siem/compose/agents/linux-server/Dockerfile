# "linux-server": een gewone Debian-bak met SSH en een Wazuh-agent erop, zodat
# er echte SSH-auth-logs en FIM-events binnenkomen i.p.v. alleen UniFi-data.
FROM debian:12

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl gnupg openssh-server ca-certificates \
    && curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --dearmor -o /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list \
    && apt-get update && apt-get install -y wazuh-agent=4.14.9-1 \
    && rm -rf /var/lib/apt/lists/*

# SSH met wachtwoord-login aan (expres, om brute-force te kunnen demonstreren/testen)
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo 'root:ChangeMe123!' | chpasswd

# FIM-doelwit: een map die niet standaard al door Wazuh bewaakt wordt, zodat we
# zelf realtime-monitoring erop kunnen zetten voor een snelle demo (zie entrypoint.sh).
RUN mkdir -p /etc/wazuh-fim-test \
    && echo "originele inhoud, $(date -u +%FT%TZ)" > /etc/wazuh-fim-test/belangrijk-bestand.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
