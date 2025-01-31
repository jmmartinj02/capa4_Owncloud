#!/bin/bash

# Actualizar repositorios e instalar nginx
sudo apt-get update -y
sudo apt upgrade -y
sudo apt-get install -y nginx

# Configuracion de Nginx como balanceador de carga
cat <<EOF > /etc/nginx/sites-available/default
upstream backend_servers {
    server 192.168.56.10;
    server 192.168.56.11;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

EOF

sudo systemctl restart nginx