#!/bin/bash
apt-get update -y
apt-get install -y nginx
sed -i 's/listen 80 default_server;/listen 8080 default_server;/' /etc/nginx/sites-available/default
sed -i 's/listen \[::\]:80 default_server;/listen [::]:8080 default_server;/' /etc/nginx/sites-available/default
INTERNA=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
cat > /var/www/html/index.html <<HTML
<h2>Dato servido por la maquina privada</h2>
<p>TU NOMBRE. Host: $(hostname) &middot; IP interna: $INTERNA &middot; sin IP publica</p>
HTML
systemctl restart nginx