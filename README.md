
# CMS de 4 capas con WordPress
>*Realizado por José Manuel Martín Jaén*
>##ÍNDICE
  1. [Introducción](#introducción)
  2. [Configuración base](#configuración-base)
  3. [Configuración Apache y PHP](#configuración-apache-y-php)
  4. [Configuración de MariaDB](#configuración-de-mariadb)
  5. [Comprobación de funcionamiento](#comprobación-de-funcionamiento)
  6. [Conclusión](#conclusión)
  7. ## Introducción: 
+ La práctica consiste en desplegar un CMS (OwnCloud) sobre una infraestructura en alta disponibilidad basada en la pila LAMP, solo que esta vez será con nginx en vez de apache.
+ Esta infraestructura está organizada en tres capas: un balanceador con Nginx como primera capa, dos servidores web con Nginx y un servidor NFS con PHP-FPM como segunda capa, y una base de datos MariaDB como tercera capa.
+ Para aumentar nuestra seguridad tanto la segunda capa como la tercera, no tendrán acceso a la capa publica, a excepcion de la primera, el balanceador, ya que será necesario que tenga acceso público.
+ Uno de los objetivos es garantizar la disponibilidad mediante la configuración de un balanceador de carga, almacenar los datos de nuestro CMS en un servidor NFS y un sistema gestor de base de datos.
## Configuración base
+ Configuración de vagrantfile.
> Este es el contenido que debemos tener en nuestro archivo para que todo se configure correctamente, es extremadamente importante el orden de creacion y configuración de nuestras máquinas virtuales, en este supuesto práctico, debemos de tener en cuenta las máquinas que en un principio son independientes y que no dependen de otras, en este caso lo son, nuestro servidor de base de datos y el servidor NFS, debemos asegurarnos de que son los primeros en configurarse, ya que de ellos dependen los demas, el orden sería el siguiente, Servidor BBDD, servidor NFS, servidores WEB, Balanceador.
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
>![image](https://github.com/user-attachments/assets/7f7c4b62-4bdc-414c-8bd1-07d376eea2bb)
>*Script de configuracion del servidor NFS:*  
## Configuración Apache y PHP
+ Despues de inciar las máquinas con vagrant up y de hacer un vagrant provision, iniciamos la maquina de apache con vagrant ssh JoseMMartApache, donde creamos y modificamos el archivo info.php en el directorio /var/www/html.
>*Aquí se puede observar el contenido del archivo*
>![image](https://github.com/jmmartinj02/Pila-LAMP/assets/146434706/0fa43350-3222-442c-8330-e6ad34c1e7f2)
+ Comprobamos desde nuestro navegador que podemos acceder al archivo, utilizando la ip de la máquina que tiene apache, si se muestra significa que la máquina Apache funciona correctamente:
>*Se puede observar en la barra de navegación lo que es necesario escribir (172.16.2.14/info.php).*
>![image](https://github.com/jmmartinj02/Pila-LAMP/assets/146434706/d821f401-558b-407e-a94a-ef583ac7bdc9)
+ Realizamos una clonación de los archivos de los repositorios remotos a la máquina Apache con este comando y le cambiamos el nombre a uno mas sencillo:
>*Se puede observar en qué directorio debemos realizar la clonación y el nombre que le damos.*
>![image](https://github.com/user-attachments/assets/8c170be3-0f18-4c22-a506-4e4189d40dba)
>*Entramos en la nueva carpeta, en SRC y movemos su contenido directamente al directorio LAMP:*
![image](https://github.com/user-attachments/assets/0dd2e190-5f3d-4df3-95e2-d9fa9e9c5b3d)
+ Modificamos el archivo config.php del directorio /var/www/html/LAMP
>*Introducimos el nombre de la base datos, usuario, contraseña que crearemos mas adelante y la dirección IP de la máquina con Mariadb.
>![image](https://github.com/user-attachments/assets/eb80d428-c609-4855-81cd-4768710e22ae)
+ Creamos en el directorio (/etc/apache2/sites-available) el archivo LAMP.conf que será una copia del archivo 000-default.conf.
+ Editamos el archivo LAMP.cnf, añadimos el directorio clonado en DocumentRoot:
>*Añadimos a DocumentRoot LAMP*
>![image](https://github.com/user-attachments/assets/1b059d47-fe3c-4362-859b-86cf2dd286b6)
>![image](https://github.com/user-attachments/assets/d615de2c-fc0d-46e2-950c-99ecf15dbfd7)
+ Habilitamos el archivo con este comando:
>![image](https://github.com/user-attachments/assets/6498833e-fd22-444b-857a-2d3ff6b57825)
+ Deshabilitamos el antiguo fichero de configuración.
>![image](https://github.com/user-attachments/assets/b9c7f273-1e04-4498-ac18-e5bb2429cd99)
## Configuración de MariaDB
+ Cambiamos de máquina y modificamos el archivo en el que se especifica a que servidor debe "enlazarse" el cliente, donde colocaremos la IP de nuestra máquina que tiene MariaDB.
>*El archivo se encuentra en /etc/mysql/mariadb.conf.d .La IP de la máquina que tiene MariaDB en nuestro caso es: 172.16.2.15*
>![image](https://github.com/jmmartinj02/Pila-LAMP/assets/146434706/a5b75ee4-e365-4beb-9bf5-a5d62069fd99)
>![image](https://github.com/jmmartinj02/Pila-LAMP/assets/146434706/c7f07ad9-e183-4d7a-8061-bc9d40f9300b)
+ Clonamos el repositorio, para importar la base de datos:
>![image](https://github.com/user-attachments/assets/6e56b027-15b8-43aa-9db9-d1e9a604f786)
+ Importamos la base de datos:
>![image](https://github.com/user-attachments/assets/bc9ca53c-3204-4a32-96ee-728693ea627c)
+ Creamos el usuario entrando en mysql como root y proporcionamos permisos:
>*Le colocamos al usuario la IP de la máquina con Mariadb, porque será hacia ella con la que accederemos de forma remota.*
>![image](https://github.com/user-attachments/assets/24066053-8661-42f5-a1d8-9fe331751f8c)
## Comprobación de funcionamiento
+ Volvemos a la máquina de Apache e iniciamos sesión con el usuario creado anteriormente en mysql usando la IP de la máquina con Mysql y accedemos a la base de datos.
>![image](https://github.com/user-attachments/assets/0b99cc7d-dfa7-4a25-a8a7-92c4e832a8d8)
+ Finalmente introducimos en el navegador la ip del servidor apache, en mi caso 172.16.2.14.
>*En la barra de busqueda tendríamos que poner algo tal que así http://172.16.2.14*
>![image](https://github.com/user-attachments/assets/8bbb833b-3c0e-48fe-bc6c-5992398dee37)
+ Para comprobar que todo se ha hecho correctamente introducimos información en la base de datos.
>![image](https://github.com/user-attachments/assets/e70a3f6f-3361-42ab-a62a-29602fb4b98b)
## Conclusión
+ Una infraestructura sencilla, dos niveles, no hay muchas complicaciones, pero en ciertos puntos uno puede llegar a perderse, o que algo no funcione, normalmente suele ser algún error de sintaxis, en mi caso porque en el bind-address coloqué 127.16.2.15 en lugar de 172.16.2.15.
