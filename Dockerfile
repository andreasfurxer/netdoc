# netDoc – Netzwerk-Dokumentation & VLAN-Tracker
# Wird von GitHub Actions gebaut und nach ghcr.io/andreasfurxer/netdoc veröffentlicht.
FROM php:8.3-apache

LABEL org.opencontainers.image.title="netDoc" \
      org.opencontainers.image.version="2.0.1" \
      org.opencontainers.image.source="https://github.com/andreasfurxer/netdoc"

ENV TZ=Europe/Vienna \
    NETDOC_PORT=8080 \
    NMAP_PRIVILEGED=1

# nmap + Capabilities: so liefert nmap auch als www-data MAC-Adresse und Hersteller
# (Voraussetzung: Container läuft im Host-Netzwerk, siehe docker-compose.yml)
RUN apt-get update \
 && apt-get install -y --no-install-recommends nmap libcap2-bin iproute2 tzdata \
 && setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip "$(command -v nmap)" \
 && rm -rf /var/lib/apt/lists/*

COPY apache-netdoc.conf /etc/apache2/conf-available/netdoc.conf
COPY netdoc.ini /usr/local/etc/php/conf.d/netdoc.ini
RUN a2enconf netdoc

COPY src/ /var/www/html/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && mkdir -p /var/www/html/data \
 && chown -R www-data:www-data /var/www/html

VOLUME ["/var/www/html/data"]
EXPOSE 8080

HEALTHCHECK --interval=60s --timeout=5s --start-period=15s --retries=3 \
  CMD php -r 'exit(@file_get_contents("http://127.0.0.1:".getenv("NETDOC_PORT")."/?asset=manifest.json") === false ? 1 : 0);'

ENTRYPOINT ["docker-entrypoint.sh"]
