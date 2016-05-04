#!/bin/bash
#
# DEBIAN POSTINSTALL
# Reynaldo Martinez P
# rmarti05@cantv.com.ve
# Junio 2011
#
#

controlfile="/etc/run-debian-postinstall"

if [ -f $controlfile ]
then

	PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

	capa=`cat /etc/cantv-debian-capa`
	servicio=`cat /etc/cantv-debian-servicio`

	myhostname=`hostname -s`
	myarch=`uname -m`
	mylocation=`cat /etc/debian-postinstall-location`
	rebootcmd=`cat /etc/debian-postinstall-reboot`
	sshrestorecmd=`cat /etc/debian-postinstall-sshrestore`

	echo ""
	echo "Instalando Syslog Mejorado"
	apt-get -y install sysklogd

	cp -v /etc/syslog.conf /etc/syslog.conf.BACKUP
	echo "*.* -/var/log/$myhostname.log" > /etc/syslog.conf
	echo "authpriv.* -/var/log/$myhostname-security.log" >> /etc/syslog.conf
	echo "authpriv.* @logstock02.cantv.com.ve" >> /etc/syslog.conf
	echo "*.* /dev/tty6" >> /etc/syslog.conf
	service sysklogd restart
	nohup tail -f /var/log/postinstall-results.log|logger &

	echo ""
	echo "Ejecutando postinstall"
	echo "Capa: $capa"
	echo "Servicio: $servicio"
	echo "Host: $myhostname"
	echo "Arquitectura: $myarch"
	echo "Locacion: $mylocation"
	echo "Reiniciar luego de postinstall: $rebootcmd"
	echo ""


	echo "Creando directorios para src, backups y logs"
	mkdir /mnt/src
	mkdir /mnt/backups
	mkdir /mnt/logs

	echo ""
	echo "Montando recursos del filer"

	mount -o vers=3,proto=tcp fscantv03.cantv.com.ve:/vol/middleware/src /mnt/src
	mount -o vers=3,proto=tcp fscantv03.cantv.com.ve:/vol/middleware/logs /mnt/logs
	mount -o vers=3,proto=tcp fscantv03.cantv.com.ve:/vol/middleware/backups /mnt/backups

	cat /mnt/src/OS/common-debian/etc/syslog.conf > /etc/syslog.conf
        echo "" > /var/log/$myhostname.log
        sed -r -i "s#/var/log/SERVERNAME.log#/var/log/$myhostname.log#" /etc/syslog.conf
        sed -r -i "s#/var/log/SERVERNAME-security.log#/var/log/$myhostname-security.log#" /etc/syslog.conf
        service sysklogd restart

	echo ""
	echo "Copiando configuraciones y scripts"
	
	cp -v /etc/fstab /etc/fstab.BACKUP
	cat /mnt/src/OS/common-debian/etc/fstab.LBF >> /etc/fstab
	cat /mnt/src/OS/common-debian/etc/vim/vimrc > /etc/vim/vimrc
	cat /mnt/src/OS/common-debian/etc/skel/.bashrc > /etc/skel/.bashrc
	cat /mnt/src/OS/common-debian/etc/ntp.conf > /etc/ntp.conf
	cat /mnt/src/OS/common-debian/etc/sysctl.conf > /etc/sysctl.conf
	cat /mnt/src/OS/common-debian/etc/hosts > /etc/hosts
	cat /mnt/src/OS/common-debian/etc/default/ntpdate > /etc/default/ntpdate
	cp -v /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.BACKUP
	cp -v /mnt/src/OS/common-debian/etc/rc.local /etc/rc.local.final
	chmod 755 /etc/rc.local.final
	cp -v /mnt/src/OS/common-debian/usr/local/bin/* /usr/local/bin/
	cp -v /mnt/src/OS/common-debian/etc/cron.d/* /etc/cron.d/
	cat /mnt/src/OS/common-debian/etc/snmp/snmpd.conf > /etc/snmp/snmpd.conf
	cp -v /mnt/src/OS/common-debian/etc/sudoers.d/cantv-sudoers /etc/sudoers.d/
	sync
	echo ""
	echo "Copiando scripts de cacti a /usr/local/share/varmonitor"
	mkdir -p /usr/local/share/varmonitor
	cp -R /mnt/src/OS/common-debian/usr/local/share/varmonitor/* /usr/local/share/varmonitor/
	sync
	sleep 5
	sync
	
	chmod 0440 /etc/sudoers.d/cantv-sudoers

	extrasoftware='
		unzip
		unrar
		arj
		hping3
		apt-show-versions
		sensible-mda
		debconf-utils
		screen
		netcat
		pydf
		libpam-cracklib
	'

	echo ""
	echo "Instalando software extra via apt-get"

	for i in $extrasoftware
	do
		echo "Instalando $i"
		apt-get -y install $i
		echo "$i instalado"
	done


	echo "Personalizando perfiles de bash"
	echo ""

	echo "export EDITOR=vim" >> /etc/bash.bashrc
	echo "alias cp=\"cp -i\"" >> /etc/bash.bashrc
	echo "alias mv=\"mv -i\"" >> /etc/bash.bashrc
	echo "alias rm=\"rm -i\"" >> /etc/bash.bashrc
	echo "alias ls=\"ls --color=auto -F\"" >> /etc/bash.bashrc
	echo "alias mc=\"mc -a\"" >> /etc/bash.bashrc

	echo "Instalando Cliente Oracle"
	echo ""

	echo "" >> /var/log/postinstall-oracle-client.log
	cd /mnt/src/OS/common-debian/software/client-oracle
	nohup tail -f /var/log/postinstall-oracle-client.log|logger &
	./oracle-install-debian.sh 2>&1 | cat >> /var/log/postinstall-oracle-client.log

	echo ""
	echo "Instalando librerias de PERL"
	echo ""
	echo "" >> /var/log/postinstall-perl-libs.log
	nohup tail -f /var/log/postinstall-perl-libs.log|logger &
	cd /mnt/src/OS/common-debian/software/perl-debian
	./perl-debian-install.sh 2>&1 | cat >> /var/log/postinstall-perl-libs.log

	echo ""
	echo "Instalando version de cpustat para debian con IOWait"
	cd /mnt/src/OS/common-debian/software/cpustat-debian6
	tar -xzvf cpustat.tar.gz -C /usr/local/src/
	cd /usr/local/src/cpustat
	make clean
	make
	make install
	cd /
	rm -fR /usr/local/src/cpustat

	echo ""
	echo "Arreglando el SSHD (solo CHA y BTO)"
	cp -v /etc/ssh/sshd_config /etc/ssh/sshd_config_BACKUP_ORIGINAL
	echo ""
	case $mylocation in
	cha)
		echo "Modificado SSHD para chacao"
		MGMT_IP=`/sbin/ifconfig | grep '10\.128\.' | cut -d: -f 2 | cut -d' ' -f 1`

		if [ -z "$MGMT_IP" ]
		then
			MGMT_IP=`ifconfig eth0|grep "inet addr"|cut -d: -f2|awk '{print $1}'`
		fi

		sed -r -i "s/Protocol 2/Protocol 2,1\nListenAddress $MGMT_IP/" /etc/ssh/sshd_config
		echo "$MGMT_IP $myhostname" >> /etc/hosts
		;;
	bto)
		echo "Modificando SSHD para Barquisimeto"
		MGMT_IP=`/sbin/ifconfig | grep '10\.71\.' | cut -d: -f 2 | cut -d' ' -f 1`

                if [ -z "$MGMT_IP" ]
                then
                        MGMT_IP=`ifconfig eth0|grep "inet addr"|cut -d: -f2|awk '{print $1}'`
                fi
		
		sed -r -i "s/Protocol 2/Protocol 2,1\nListenAddress $MGMT_IP/" /etc/ssh/sshd_config
		echo "$MGMT_IP $myhostname" >> /etc/hosts
		;;
	eq2|eqii)
                echo "Modificando SSHD para Equipos 2"
                echo "usando eth0 como fuente de IP de administracion"
                # No es ni CHA ni BTO .. asumimos eth0 como ADMIN y obtenemos la IP
                #
                MGMT_IP=`ifconfig eth0|grep "inet addr"|cut -d: -f2|awk '{print $1}'`
                sed -r -i "s/Protocol 2/Protocol 2,1\nListenAddress $MGMT_IP/" /etc/ssh/sshd_config
                echo "$MGMT_IP $myhostname" >> /etc/hosts
		;;
	*)
		echo "Modificando SSHD para locacion no identificada..."
		echo "usando eth0 como fuente de IP de administracion"
		# No es ni CHA ni BTO .. asumimos eth0 como ADMIN y obtenemos la IP
		#
		MGMT_IP=`ifconfig eth0|grep "inet addr"|cut -d: -f2|awk '{print $1}'`
		sed -r -i "s/Protocol 2/Protocol 2,1\nListenAddress $MGMT_IP/" /etc/ssh/sshd_config
		echo "$MGMT_IP $myhostname" >> /etc/hosts
		;;
	esac

	echo ""
	echo "Regenerando clave para protocolo V 1"
	ssh-keygen -t rsa1 -f /etc/ssh/ssh_host_rsa1_key -N ""
	echo "HostKey /etc/ssh/ssh_host_rsa1_key" >> /etc/ssh/sshd_config

        echo ""
        echo "Creando Usuarios del servidor"
        echo ""

        /mnt/src/OS/basic_scripts_debian/create.users.sh

        echo ""
        echo "Instalando xinetd y sendmail-bin"

        apt-get -y install xinetd
        apt-get -y install sendmail-bin


	echo ""
	echo "Bajando servicios innecesarios"

	svclistoff='
		samba
		exim4
		openbsd-inetd
		winbind
		rsyslog
		xinetd
		sendmail
	'

	for i in $svclistoff
	do
		chkconfig $i off
	done


	echo ""
	echo "Colocando servicios primarios en autostart"
	
	svcliston='
		sysklogd
		klogd
		ssh
		cron
		sysstat
		portmap
		fam
		nfs-common
		quotarpc
		nfs-kernel-server
		rc.local
		sudo
		arpwatch
		gpm
		snmpd
		ntp
	'

	
	for i in $svcliston
	do
		chkconfig $i on
	done

        echo ""
        echo "Eliminando arpwatch"
        apt-get -y remove arpwatch


	echo ""
	echo "Aplicando variables de entorno para NET-SNMP"
	# apt-get -y install snmp-mibs-downloader

	echo "export MIBS=ALL" >> /etc/bash.bashrc

	echo ""
	echo "Eliminando rotacion de logs de DEBIAN (se usara la de sopmid)"
	rm /etc/cron.daily/sysklogd

	echo ""
	case $sshrestorecmd in
	yes|YES)
		echo "Restaurando config de SSH"

		ARCHIVOS=`ls -l /mnt/backups/ssh/$servicio/$capa/$myhostname*-ssh.tgz`

		BACKUPS=$?

		if [ "$BACKUPS" == "0" ]; then
			echo "Respaldos ubicados: Restaurando config y claves SSH para el servidor"
                        ULTIMA_SSH=`find /mnt/backups/ssh/$servicio/$capa/ -name "$myhostname*" | sort | tail -1`
                        for file in $ULTIMA_SSH
                        do
                                echo "Restaurando archivo $file"
                                tar -zxvf $file -C /
                        done
		fi
		
		;;
	*)
		echo "No se restaura la config de SSH"
		;;
	esac

	echo ""
	

	echo ""
	echo "Postinstall finalizado (fase 1)"
	echo ""

	echo "Restituyendo RC.LOCAL de produccion previo al"
	echo "postinstall de la aplicacion"
	mv /etc/rc.local /etc/rc.local.postinstall
	mv /etc/rc.local.final /etc/rc.local
	chmod 755 /etc/rc.local

	if [ -f /mnt/src/OS/postinstall/DEBIAN6/apps/$servicio/$capa.sh ]
	then
		echo "Ejecutando postinstall fase 2 (aplicacion: $servicio / $capa)"
		echo ""
		echo "" >> /var/log/postinstall-$servicio-$capa.log
		nohup tail -f /var/log/postinstall-$servicio-$capa.log|logger &
		exec /mnt/src/OS/postinstall/DEBIAN6/apps/$servicio/$capa.sh 2>&1 | cat >> /var/log/postinstall-$servicio-$capa.log
		echo ""
		echo "Postinstall para $servicio/$capa Finalizado"
		echo ""
	fi
	
	rm $controlfile

	case $rebootcmd in
	"yes"|"YES")
		echo "no" > /etc/debian-postinstall-reboot
		echo ""
		echo "Reiniciando servidor"
		echo ""
		sync
		sleep 5
		sync
		sleep 5
		reboot
		exit 0
		;;
	esac

fi
