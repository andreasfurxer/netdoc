#!/bin/sh
set -e

PORT="${NETDOC_PORT:-8080}"
sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf

mkdir -p /var/www/html/data
# Bei NFS mit root-squash ist chown nicht erlaubt - das ist kein Abbruchgrund
chown -R www-data:www-data /var/www/html/data 2>/dev/null \
  || echo "Hinweis: chown auf /var/www/html/data nicht moeglich (NFS-Rechte der Freigabe pruefen)" >&2
if ! runuser -u www-data -- sh -c 'touch /var/www/html/data/.write-test && rm -f /var/www/html/data/.write-test'; then
  echo "WARNUNG: /var/www/html/data ist fuer den Webserver nicht beschreibbar. NFS-Freigabe/Rechte pruefen." >&2
fi

# Hintergrund-Scan (ersetzt den Cronjob): prüft jede Minute, ob laut Einstellungen
# ein Scan fällig ist. Läuft als www-data, damit die Datenbank dem Webserver gehört.
(
  while true; do
    runuser -u www-data -- php /var/www/html/index.php >/dev/null 2>&1 || true
    sleep 60
  done
) &

exec apache2-foreground
