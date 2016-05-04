#!/bin/bash
#
# POSTINSTALL para Centos 6
# Basado en Postinstall original de centos 5
#
#
################################################################################

# Configurar los servicios que deben estar arriba
# cd /etc/init.d/ ; for serv in * ; do echo Apagando $serv... ; chkconfig $serv off ; done ; cd -
# echo Apagando sgi_fam... ; chkconfig sgi_fam off
# cd /etc/init.d/ ; for serv in atd autofs cpuspeed crond gpm irqbalance netfs network ntpd portmap readahead snmpd sshd syslog sendmail ; do echo Encendiendo $serv... ; chkconfig $serv on ; done ; cd -

# Se suprime el alias de la copia interactiva
unalias cp
################################################################################
# Se obtiene el nombre del Host, el servicio y la capa en la que operara

HOST_NAME=`grep HOSTNAME /etc/sysconfig/network | cut -d= -f 2 | cut -d. -f 1`
hostname $HOST_NAME
SERVICIO=`cat /etc/sysconfig/servicio`
CAPA=`cat /etc/sysconfig/capa`
GATEWAY=`grep GATEWAY /etc/sysconfig/network | cut -d= -f2`
################################################################################

# Se debe validar si hay claves respaldadas para el host
ARCHIVOS=`ls -l /mnt/backups/ssh/$SERVICIO/$CAPA/$HOST_NAME*-ssh.tgz` 
#echo "$ARCHIVOS"|grep "$HOST_NAME"> /dev/null

BACKUPS=$?

if [ "$BACKUPS" == "0" ]; then
                        echo Hay archivos respaldados del servidor
                        echo Restauro las configuracion ssh del servidor, las llaves, authorized_keys y known_hosts del usuario root
                        ULTIMA_SSH=`find /mnt/backups/ssh/$SERVICIO/$CAPA/ -name "$HOST_NAME*" | sort | tail -1`
                        for file in $ULTIMA_SSH
                        do
                                echo "Restaurando archivo $file"
                                tar -zxvf $file -C /
                        done

else
	# Configuro el sshd_config para que de servicio por la interfaz privada
	cp /etc/ssh/sshd_config /etc/ssh/sshd_config.old
	echo
	echo Arreglo el sshd_config

	# La siguiente variable registra el posible valor del segundo octeto de la red mgmt. Si dicha red
	# es 10.128.x.x (cha), el valor sera 128.. si es 10.71.x.x (bto) el valor sera 71
	mynetworkis=`/sbin/ifconfig | egrep '('10\.128\.'|'10\.71\.')' | cut -d: -f 2 | cut -d' ' -f 1 | cut -d. -f2`
	#
	# Esta variable toma el posible caso de una red desconocida. En tal situacion, invalida el resultado
	# de la variable anterior y lo forza a cero.
	noknownnetcondition=`/sbin/ifconfig | egrep '('10\.128\.'|'10\.71\.')' | cut -d: -f 2 | cut -d' ' -f 1 | cut -d. -f2|wc -l`

	case $noknownnetcondition in
	"0")
		mynetworkis="0"
		;;
	esac

	case $mynetworkis in
	"128")
		
		MGMT_IP=`/sbin/ifconfig | grep '10\.128\.' | cut -d: -f 2 | cut -d' ' -f 1`
		;;
	"71")
		MGMT_IP=`/sbin/ifconfig | grep '10\.71\.' | cut -d: -f 2 | cut -d' ' -f 1`
		;;
	*)
		MGMT_IP=`ifconfig eth0 | grep "inet addr" | cut -d: -f2 | awk '{print $1}'`
		;;
	esac

	echo ""
	echo "Mi IP de administracion es: $MGMT_IP"
	echo ""

	mgmtreallydetected=`echo $MGMT_IP|wc -l`

	cp -v /mnt/src/OS/common-centos6/etc/sshd/sshd_config /etc/ssh/

	case $mgmtreallydetected in
	"1")	
		sed -r -i "s/Protocol 2/Protocol 2\nListenAddress $MGMT_IP/" /etc/ssh/sshd_config
		;;
	"0")
		echo "No se pudo detectar una IP mgmt valida - no se modifica el ListenAddress del SSHD"
		;;
	esac

	# Se procede a crear la clave publica y privada de ssh
        echo "Se procede a crear la clave publica y privada de ssh"
        ssh-keygen -t dsa -N ""  -f /root/.ssh/id_dsa
fi;

#################################################################################

# Copio archivos de configuracion en forma basica a /etc
mv /etc/ntp.conf /etc/ntp.conf.old
mv /etc/rsyslog.conf /etc/rsyslog.conf.old
mv /etc/sysctl.conf /etc/syscctl.conf.old

echo
echo Copio los archivos de configuracion de ntp,rsyslog a /etc
cp /mnt/src/OS/common-centos6/etc/{ntp.conf,rsyslog.conf} /etc
echo "Copio el sysctl especial de Centos 6"
cp -v /etc/sysctl.conf /etc/sysctl.conf.ORIGINAL
cp -v /mnt/src/OS/common-centos6/etc/sysctl.conf.centos6x /etc/sysctl.conf
cp -v /mnt/src/OS/common-centos6/etc/sysconfig/ntpdate /etc/sysconfig/
cp -v /mnt/src/OS/common-centos6/etc/sysconfig/rpcbind /etc/sysconfig/

#################################################################################
# Concateno el fstab.LBF al final del fstab
# Para agregar el montaje de los logs, backups y fuentes
echo
echo Configuro el archivo de fstab agregar el montaje de los logs, backups y fuentes
cp /etc/fstab /etc/fstab.old
cat /mnt/src/OS/common-centos6/etc/fstab.LBF >> /etc/fstab
#################################################################################
# Copiando scripts basicos a /usr/local/bin
echo 
echo Copiando scripts basicos a /usr/local/bin
cp -R /mnt/src/OS/common-centos6/usr/local/bin/* /usr/local/bin
#
#################################################################################
# Copiando scripts para CACTI
echo
echo Copiando scripts de cacti a /usr/local/share/varmonitor
mkdir -p /usr/local/share/varmonitor
cp -R /mnt/src/OS/common-centos6/usr/local/share/varmonitor/* /usr/local/share/varmonitor/
#
#################################################################################
# Copiando los cron basicos
echo 
echo Copiando los cron
cp /mnt/src/OS/common-centos6/etc/cron.d/* /etc/cron.d
#################################################################################
# Modificando el cron basico para adaptarlo al servicio
echo Se modifica lor achivos de cron basicos
sed -r -i "s/servicio/$SERVICIO/g" /etc/cron.d/crontab.ssh.backup
sed -r -i "s/servicio/$SERVICIO/g" /etc/cron.d/crontab.syslog
sed -r -i "s/capa/$CAPA/g" /etc/cron.d/crontab.ssh.backup
sed -r -i "s/capa/$CAPA/g" /etc/cron.d/crontab.syslog
sed -r -i "s/gateway/$GATEWAY/g" /etc/cron.d/crontab.keepalive.net
#################################################################################
# Configuracion del archivo de log y el syslog
echo
echo Se crear cel archivo de log y se configura el archivo configuracion syslog
> /var/log/$HOST_NAME.log
sed -r -i "s#/var/log/SERVERNAME.log#/var/log/$HOST_NAME.log#" /etc/rsyslog.conf
#################################################################################
# Copia del archivo de snmp basico
echo
echo Se copia el archivo de configuracion de snmp basico
mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.old
cp /mnt/src/OS/common-centos6/etc/snmp/snmpd.conf /etc/snmp/snmpd.conf
#################################################################################
# Configuracion del ntp
echo
echo Se Configura el ntp
echo '10.128.0.125' >> /etc/ntp/step-tickers
echo '10.128.0.61' >> /etc/ntp/step-tickers
#################################################################################
# Se copia el rc.local modificado con ethtool y linux_logo
cp -v /mnt/src/OS/common-centos6/etc/rc.d/rc.local /etc/rc.d/
#################################################################################
# Copia del archivo de rutas estaticas "static-routes"
echo 
echo "Se copian rutas estaticas"
#################################################################################
#
# NOTA: Las siguientes lineas fueron colocadas para contemplar otras posibles
# rutas estaticas, como por ejemplo las de chacao y barquisimeto
case $mynetworkis in
"128")
	echo "Copiando rutas estaticas para chacao"
	cp -v /mnt/src/OS/common-centos6/etc/sysconfig/static-routes.cha /etc/sysconfig/static-routes
	;;
"71")
	echo "Copiando rutas estaticas para barquisimeto"
	cp -v /mnt/src/OS/common-centos6/etc/sysconfig/static-routes.bto /etc/sysconfig/static-routes
	;;
esac
#################################################################################
# Configuracion de sysctl
echo
echo Configuro sysctl
sysctl -p
#################################################################################
# Configuracion de los terminales
echo
echo Se configuran los terminales
echo >> /etc/profile
echo 'TERM="linux"' >> /etc/profile
echo 'TMOUT=3600' >> /etc/profile
echo 'EDITOR=vim' >> /etc/profile
echo 'export TERM TMOUT EDITOR' >> /etc/profile
echo 'alias vi=vim' >> /root/.bashrc
#################################################################################
# Modificar el comportamiento por defecto del ls
echo
echo Se modifica el comportamiento por defecto del ls
sed -r -i "s#alias ls='ls --color=auto'#alias ls='ls --color=auto -F'#" /etc/profile.d/colorls.sh
sed -r -i 's/LANG="en_US.UTF-8"/LANG="en_US"/' /etc/sysconfig/i18n
#################################################################################

echo ""
echo "Copiamos el archivo para repositorios locales - Pasada 2"
cp -v /mnt/src/OS/common-centos6/etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/
echo ""
yum clean all

# A PARTIR DEL JUNIO 07 DEL 2012 LA AUTENTICACION SE HACE VIA LDAP
#
echo "Se agrega LDAP-AUTH al servidor"

yum -y erase sssd

mkdir -p /var/users
# Pass 1
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.conf /etc/
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.conf /etc/pam_ldap.conf
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.secret /etc/
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.secret /etc/pam_ldap.secret
cp -v /mnt/src/OS/centos-auth-ldap/etc/nslcd.conf /etc/
chmod 600 /etc/ldap.secret
chmod 600 /etc/pam_ldap.secret
authconfig --enableldap --enableldapauth --enablemkhomedir --update
echo "sudoers:    files ldap" >> /etc/nsswitch.conf
# echo "session     required      pam_mkhomedir.so skel=/etc/skel umask=077 silent" >> /etc/pam.d/system-auth-ac
# echo "UseLogin yes" >> /etc/ssh/sshd_config
# Pass 2
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.conf /etc/
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.conf /etc/pam_ldap.conf
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.secret /etc/
cp -v /mnt/src/OS/centos-auth-ldap/etc/ldap.secret /etc/pam_ldap.secret
cp -v /mnt/src/OS/centos-auth-ldap/etc/nslcd.conf /etc/
chmod 600 /etc/ldap.secret
chmod 600 /etc/pam_ldap.secret
# NOTA: Sudo LDAP esta TERRIBLY BROKEN en RHEL/SL/CENTOS hasta 6.2 (sudo 1.7.4p5-9)
# Eso nos obliga a usar un archivo de sudoers para los grupos principales del ISP
#
cp -v /mnt/src/OS/common-centos6/etc/sudoers.d/cantv-sudoers /etc/sudoers.d/
chmod 440 /etc/sudoers.d/cantv-sudoers

#################################################################################
# Manda a montar los filesystem via NFS
echo "mount /mnt/logs" >> /etc/rc.local
echo "mount /mnt/backups" >> /etc/rc.local
#################################################################################

#################################################################################
# Se deshabilita IP Version 6
echo "Deshabilitando IPV6"
sed -r -i "s/NETWORKING_IPV6=yes/NETWORKING_IPV6=no/" /etc/sysconfig/network
#################################################################################

#################################################################################
# Instalamos software extra

yum -y localinstall /mnt/src/OS/common-centos6/software/extras/noarch/*.rpm /mnt/src/OS/common-centos6/software/extras/`uname -p`/*.rpm
#################################################################################


#################################################################################
# Se instala el cliente Oracle
echo 
echo "Instalando Cliente Oracle"
cd /mnt/src/OS/common/software/cliente-oracle-rpm
./oracle-install-centos.sh
cd -
#################################################################################



#################################################################################
# Se instalan las librerias de PERL personalizadas para cantv.net
echo
echo "Instalando librerias de PERL"
cd /mnt/src/OS/common-centos6/software/perl
./install-perl-centos6x.sh
cd -
#################################################################################
#################################################################################

echo ""
echo "Copiamos el archivo para repositorios locales - Pasada 2 - incluido EPEL"
rpm -ivh /mnt/src/OS/common-centos6/software/epel/epel-release-6-7.noarch.rpm
cp -v /mnt/src/OS/common-centos6/etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/
cp -v /mnt/src/OS/common-centos6/etc/yum.repos.d/epel.repo /etc/yum.repos.d/
rm /etc/yum.repos.d/epel-testing.repo
echo ""

yum clean all
yum -y update yum*
yum -y update rpm*
yum -y update

echo ""
echo "Instalando SENDMAIL con configuracion para mail.mgmt.cantv.net como SmartHost"
echo ""

yum -y install sendmail sendmail-cf sendmail-devel
cp -v /etc/mail/sendmail.mc /etc/mail/sendmail.mc.ORIGINAL
cp -v /mnt/src/OS/common/software/sendmail/etc/mail/sendmail.mc /etc/mail/
chkconfig sendmail on

echo ""
echo "Haciendo cierre de PAM"
cat /mnt/src/OS/pam-security-common/access.extra >> /etc/security/access.conf
echo "account    required     pam_access.so" >> /etc/pam.d/sshd
echo "account    required     pam_access.so" >> /etc/pam.d/login
echo ""

echo "alias mc='mc -a'" >> /etc/bashrc

#################################################################################
# Se levantan los servicios basicos minimos necesarios para el servidor
#################################################################################

chkconfig ntpdate on
chkconfig ntpd on
chkconfig snmpd on
chkconfig sendmail on
chkconfig nslcd on
chkconfig nscd on
chkconfig gpm on

#################################################################################
# Se apagan los servicios innecesarios
#################################################################################

chkconfig cups off


echo ""
echo "POSTINSTALL BASE TERMINADO..."
echo ""

#################################################################################
#################################################################################
