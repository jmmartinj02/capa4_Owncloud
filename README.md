
# CMS de 4 capas con WordPress
>*Realizado por José Manuel Martín Jaén*
>
>##ÍNDICE
  1. [Introducción](#introducción)
  2. [Configuración Vagrantfile y Scripts](#configuración-base)
  3. [Comprobación de funcionamiento](#comprobación-de-funcionamiento)
  4. [Conclusión](#conclusión)
## Introducción
Este proyecto despliega un CMS (OwnCloud) sobre una infraestructura en alta disponibilidad basada en la pila LAMP, utilizando Nginx en lugar de Apache. La infraestructura se organiza en tres capas: un balanceador con Nginx como primera capa, dos servidores web con Nginx y un servidor NFS con PHP-FPM como segunda capa, y una base de datos MariaDB como tercera capa. El objetivo es garantizar la disponibilidad mediante un balanceador de carga, almacenar los datos en un servidor NFS y gestionar la base de datos de manera segura.
## Configuración Vagrantfile y Scripts
El archivo `Vagrantfile` define y configura las máquinas virtuales necesarias, asegurando el orden correcto de creación y configuración. Los scripts de Bash automatizan la instalación y configuración de cada máquina:
- **Servidor de Base de Datos**: Instala MariaDB y configura el acceso remoto.
- **Servidor NFS**: Configura NFS para compartir archivos y prepara OwnCloud.
- **Servidores Web**: Instalan Nginx, montan la carpeta NFS y configuran PHP-FPM.
- **Balanceador**: Configura Nginx como balanceador de carga.
>```bash
>Vagrant.configure("2") do |config|
>  config.vm.box = "debian/bullseye64"
>
>  config.vm.define "JMMartinBBDD" do |app|
>    app.vm.hostname = "JMMartinBBDD"
>    app.vm.network "private_network", ip: "192.168.60.10", virtualbox_intnet: "red_BBDD"
>    app.vm.provision "shell", path: "BBDD.sh"
>  end
>
>  config.vm.define "JMMartinNFS" do |app|
>    app.vm.hostname = "JMMartinNFS"
>    app.vm.network "private_network", ip: "192.168.56.12", virtualbox_intnet: "red1"
>    app.vm.network "private_network", ip: "192.168.60.13", virtualbox_intnet: "red_BBDD"
>    app.vm.provision "shell", path: "nfs.sh"
>  end
>
>  config.vm.define "JMMartinWEB1" do |app|
>    app.vm.hostname = "JMMartinWEB1"
>    app.vm.network "private_network", ip: "192.168.56.10", virtualbox_intnet: "red1"
>    app.vm.network "private_network", ip: "192.168.60.11", virtualbox_intnet: "red_BBDD"
>    app.vm.provision "shell", path: "webs.sh"
>  end
>
>  config.vm.define "JMMartinWEB2" do |app|
>    app.vm.hostname = "JMMartinWEB2"
>    app.vm.network "private_network", ip: "192.168.56.11", virtualbox_intnet: "red1"
>    app.vm.network "private_network", ip: "192.168.60.12", virtualbox_intnet: "red_BDDD"
>    app.vm.provision "shell", path: "webs.sh"
>  end
>
>  config.vm.define "JMMartinBAL" do |app|
>    app.vm.hostname = "JMMartinBAL"
>    app.vm.network "public_network"
>    app.vm.network "private_network", ip: "192.168.56.1", virtualbox_intnet: "red1"
>    app.vm.provision "shell", path: "balanceador.sh"
>  end 
>end

+ Estos son los scripts que usaremos para que las máquinas estén listas al iniciarlas.
>*Script de las maquinas nginx:*
>```bash
>#!/bin/bash
>
># Actualizar repositorios e instalar nginx, nfs-common y PHP 7.4
>sudo apt-get update -y
>sudo apt upgrade -y
>sudo apt-get install -y nginx nfs-common php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4->curl php7.4-zip php7.4-intl php7.4-ldap mariadb-client 
># Crear directorio para montar la carpeta compartida por NFS
>sudo mkdir -p /var/www/html
>
># Montar la carpeta NFS desde el servidor NFS
>sudo mount -t nfs 192.168.56.12:/var/www/html /var/www/html
>
># Añadir entrada al /etc/fstab para montaje persistente, añadiendo la linea con echo al archivo /etc/fstab
>echo "192.168.56.12:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab
>
># Configuración de Nginx, introduciendo cambios con un cat  junto con un EOF.
>cat <<EOF > /etc/nginx/sites-available/default
>server {
>    listen 80;
>
>    root /var/www/html/owncloud;
>    index index.php index.html index.htm;
>
>    location / {
>        try_files \$uri \$uri/ /index.php?\$query_string;
>    }
>
>    location ~ \.php\$ {
>        include snippets/fastcgi-php.conf;
>        fastcgi_pass 192.168.56.12:9000;
>        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
>        include fastcgi_params;
>    }
>
>    location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {
>        deny all;
>    }
>}
>EOF
>
>nginx -t
>
>sudo systemctl restart nginx
>
>sudo systemctl restart php7.4-fpm
>
>sudo ip route del default 

>*Script de configuracion de la base de datos:*
>```bash
>#!/bin/bash
>
># Actualizar repositorios e instalar MariaDB
>sudo apt-get update -y
>sudo apt upgrade -y
>sudo apt-get install -y mariadb-server
>
># Configurar MariaDB para permitir acceso remoto desde los servidores web
>sed -i 's/bind-address.*/bind-address = 192.168.60.10/' /etc/mysql/mariadb.conf.d/50-server.cnf
>
>sudo systemctl restart mariadb
>
>mysql -u root <<EOF
>CREATE DATABASE owncloud;
>CREATE USER 'owncloud'@'192.168.60.%' IDENTIFIED BY '1234';
>GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud'@'192.168.60.%';
>FLUSH PRIVILEGES;
>EOF
>
>sudo ip route del default 

*Script de configuracion del servidor NFS:* 
>```bash
>#!/bin/bash
># Actualizar repositorios e instalar NFS y PHP 7.4
>sudo apt-get update -y
>sudo apt upgrade -y
>sudo apt-get install -y nfs-kernel-server php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap unzip
># Crear carpeta compartida para OwnCloud y configurar permisos
>sudo mkdir -p /var/www/html
>sudo chown -R www-data:www-data /var/www/html
>sudo chmod -R 755 /var/www/html
># Configurar NFS para compartir la carpeta, tus direcciones ip de los dos servidores web.
>echo "/var/www/html 192.168.56.11(rw,sync,no_subtree_check)" >> /etc/exports
>echo "/var/www/html 192.168.56.10(rw,sync,no_subtree_check)" >> /etc/exports
># Reiniciar NFS para aplicar cambios
>sudo exportfs -a
>sudo systemctl restart nfs-kernel-server
># Descargar, descomprimir y mover owncloud al directorio html
>cd /tmp
>wget https://download.owncloud.com/server/stable/owncloud-10.9.1.zip
>unzip owncloud-10.9.1.zip
>mv owncloud /var/www/html/
># Configurar permisos de OwnCloud
>sudo chown -R www-data:www-data /var/www/html/owncloud
>sudo chmod -R 755 /var/www/html/owncloud
># Crear archivo de configuración inicial para OwnCloud
>cat <<EOF > /var/www/html/owncloud/config/autoconfig.php
><?php
>\$AUTOCONFIG = array(
>  "dbtype" => "mysql",
>  "dbname" => "owncloud",
>  "dbuser" => "owncloud",
>  "dbpassword" => "1234",
>  "dbhost" => "192.168.60.10",
>  "directory" => "/var/www/html/owncloud/data",
>  "adminlogin" => "jose",
>  "adminpass" => "jose"
>);
>EOF
># Modificar el archivo config.php 
>echo "Añadiendo dominios de confianza a la configuración de OwnCloud."
>php -r "
>  \$configFile = '/var/www/html/owncloud/config/config.php';
>  if (file_exists(\$configFile)) {
>    \$config = include(\$configFile);
>    \$config['trusted_domains'] = array(
>      'localhost',
>      'localhost:8080',
>     '192.168.56.10',
>      '192.168.56.11',
>      '192.168.56.12',
>    );
>    file_put_contents(\$configFile, '<?php return ' . var_export(\$config, true) . ';');
>  } else {
>    echo 'No se pudo encontrar el archivo config.php';
>  }
>"
>sed -i 's/^listen = .*/listen = 192.168.56.12:9000/' /etc/php/7.4/fpm/pool.d/www.conf
>sudo systemctl restart php7.4-fpm
>sudo ip route del default

>
*Script de configuracion del Balanceador:*
>```bash
>#!/bin/bash
>
># Actualizar repositorios e instalar nginx
>sudo apt-get update -y
>sudo apt upgrade -y
>sudo apt-get install -y nginx
>
># Configuracion de Nginx como balanceador de carga, se deben de colocar las dos direcciones ip de sus backends
>cat <<EOF > /etc/nginx/sites-available/default
>upstream backend_servers {
>    server 192.168.56.10;
>    server 192.168.56.11;
>}
>
>server {
>    listen 80;
>    server_name localhost;
>
>    location / {
>        proxy_pass http://backend_servers;
>        proxy_set_header Host \$host;
>        proxy_set_header X-Real-IP \$remote_addr;
>        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
>    }
>}
>
>EOF
>
>sudo systemctl restart nginx
## Comprobación de funcionamiento
(He tenido ciertos problemas técnicos con mi portatil, he pasado el fin de semana en badajoz y estaba realizando la práctica en mi ordenador de sobremesa, a lo largo del fin de semana subiré la prueba de funcionamiento, ya que en el portatil me daba un error con un archivo al intentar descargar el box, y como tenia OBS en el portatil, pensaba grabarlo todo en él.)
## Conclusión
Aunque la infraestructura es compleja y presenta desafíos técnicos, especialmente en el direccionamiento IP, el proceso está completamente automatizado. Esto permite desplegar OwnCloud de manera eficiente y garantizar su disponibilidad. Durante el desarrollo del proyecto, tuve que pedir consejo a algunos compañeros(sobretodo con el direccionamiento IP) para resolver ciertos problemas técnicos, lo que me ayudó a comprender mejor los fallos que llevo arrastrando desde el año pasado.
