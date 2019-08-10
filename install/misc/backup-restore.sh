#!/bin/bash

source $CONFIGS/Docker/.env
which rclone > $CONFIGS/.config/checkapp.txt
clear

if [ ! -s $CONFIGS/.config/checkapp.txt ]; then

	echo "${YELLOW}"
	echo "--------------------------------------------------"
	echo " You will need to install and configure"
	echo " Rclone before you can restore the backup!"
	echo "--------------------------------------------------"
	echo "${STD}"

else

	EXPLAINTASK

	CONFIRMATION

	if [[ ${REPLY} =~ ^[Yy]$ ]]; then

		GOAHEAD

		mkdir -p /tmp/goobyrestore
		RESTOREFOLDER=/tmp/goobyrestore
		OLDFILES=/tmp/Gooby

		echo " Restoring the backup can take several hours"
		echo " please don't exit the terminal until it's done!"
		echo
		read -e -p " Server to restore: " -i "${SERVER}" SERVER
		echo
		echo " App name to restore: (for example, ${LYELLOW}Docker${STD} or ${LYELLOW}Plex${STD})"
		echo " You can find your app names in ${RCLONESERVICE}:/Backup/${SERVER}/Gooby"
		echo " You can type ${LYELLOW}All${STD} for all apps,"
		echo " Or ${LYELLOW}Home${STD} for restoring your /home/${USER} directory"
		echo
		read -e -p " App to restore (case matters): " -i "All" APPNAME

		echo
		echo " ${LMAGENTA}Copying ${APPNAME} backup from ${RCLONESERVICE}...${STD}"
		echo

		if [ "${APPNAME}" == "Home" ]; then

			/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/${SERVER}-backup.tar.gz ${RESTOREFOLDER} --checksum --drive-chunk-size=64M

			[ -f ${RESTOREFOLDER}/${SERVER}-backup.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD}, please try again"; PAUSE; exit ;}

			echo
			echo " ${GREEN}Restoring your home folder...${STD}"
			echo

			tar -xpvf ${RESTOREFOLDER}/${SERVER}-backup.tar.gz -C /
			sudo chown $USER:$USER ${HOME}

		else

			if [ "${APPNAME}" == "All" ]; then
			
				/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/Gooby ${RESTOREFOLDER} --checksum --drive-chunk-size=64M
				[ -f ${RESTOREFOLDER}/Docker-full.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD}, please try again"; PAUSE; exit ;}
				sudo mv ${CONFIGS}/[^.]* ${OLDFILES}

			else

				echo "+ ${APPNAME}*" > ${CONFIGS}/.config/checkapp.txt
				echo "- *" >> ${CONFIGS}/.config/checkapp.txt
				/usr/bin/rclone --stats-one-line -P copy ${RCLONESERVICE}:/Backup/${SERVER}/Gooby --filter-from ${CONFIGS}/.config/checkapp.txt ${RESTOREFOLDER} --checksum --drive-chunk-size=64M
				rm ${CONFIGS}/.config/checkapp.txt
				[ -f ${RESTOREFOLDER}/${APPNAME}-full.tar.gz ] || { echo; echo " ${LRED}Sorry, backup not found on ${RCLONESERVICE}!${STD}, please try again"; PAUSE; exit ;}
				sudo mv ${CONFIGS}/${APPNAME} ${OLDFILES}
				
			fi

			echo
			echo " ${LBLUE}${APPNAME} backup downloaded, proceeding...${STD}"
			echo

			echo
			echo " ${YELLOW}Taking containers down...${STD}"

			cd ${CONFIGS}/Docker
			/usr/local/bin/docker-compose down
			cd ${CURDIR}

			echo
			echo " ${GREEN}Restoring files...${STD}"
			echo

			cd ${CONFIGS}

			for f in ${RESTOREFOLDER}/*-full.tar.gz

			do

				echo " ${GREEN} Extracting full archive... ${f}${STD}"
				echo
				tar -xpvf "$f"
				echo
				rm ${f}

			done

				for f in ${RESTOREFOLDER}/*-diff.tar.gz

			do

				echo " ${GREEN} Extracting differential archive... ${f}${STD}"
				echo
				tar --incremental -xpvf "$f"
				echo
				rm ${f}

			done

			cd ${CURDIR}
			sudo mv ${RESTOREFOLDER}/snapshots ${CONFIGS}/.config/snapshots

			cd ${CONFIGS}/Docker
			source /opt/Gooby/install/misc/environment-build.sh rebuild
			/usr/local/bin/docker-compose up -d --remove-orphans ${@:2}
			cd ${CURDIR}

			echo " ${GREEN} Restoring permissions, please wait...${STD}"
			echo
			sudo chown $USER:$USER ${CONFIGS}

			echo
			echo " ${CYAN}Finished restoring ${APPNAME}${STD}"
			echo

			echo
			echo " ${WHITE}Make sure${STD} you check if your services are"
			echo " running properly before you remove the old installation!"
			echo
			read -n 1 -s -r -p " Remove old installation files (Y/n)? " -i "" choice
			echo

			case "$choice" in
				y|Y ) sudo rm -r ${OLDFILES};;
				* ) echo " Your old installation files are available"; echo " at ${OLDFILES} until you reboot"; echo;;
			esac

		fi

			sudo rm -r ${RESTOREFOLDER}

		TASKCOMPLETE

	else

		CANCELTHIS

	fi

fi

rm $CONFIGS/.config/checkapp.txt

PAUSE
