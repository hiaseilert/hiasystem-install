#!/bin/sh
# Installationshelfer Script hiasystem
# Version
#	2020-09-15.0 Erste Beta die getestet werden kann
#	2021-11-03.1 Überprüfung der Config erweitert.
#	2021-11-03.2 Abhängigkeitern werden jetzt aus der Konfigurationsdatei abgefragt.
#	2021-11-03.3 pacman wird abgefragt, so das eine Fehlermeldung angezeigt wird, wenn ein Packet fehlt.
#	2021-11-03.4 Benutzerabfrage anstelle des Timers eingebaut.
#	2021-11-03.5 Übersichtlichere Auflistung bei der installation.
#	2022-05-30.0 Ein Tippfehler bei der interaktiven Abfrage behomen, exit-code wurde falsch zurückgegeben.
#

# Deklarationen
#	Konfigurationsdatei
configFile=install.json # Nur bei installationsscript den relativen Pfad angeben, ansonnsten bitte absolute pfade.

#	Standart-Konfigurationsdatei, falls configFile nicht klappt.
defaultConfigFile=default.install.json

#	Wird für diverse Fehlerabfragen verwendet
status=0

# Prüfen ob jq installiert ist
jq --version
status=$?
if ! [ $status -eq 0 ]; then
	# jq ist wohl nicht installiert.
	echo "Installiere JSON processor mit pacman um die install.json lesen zukönnen."
	pacman -Sy jq
fi


# Überprüft die Konfiguration
checkConfig(){
jq . $configFile > /dev/null
status=$?
if ! [ $status -eq 0 ]; then
	echo "Fehler beim lesen der Konfigurationsdatei: $configFile"
	return $status
fi
}
# Konfiguration für die Installation prüfen
if  checkConfig; then
	echo "Konfigurationsdatei: '$configFile' gefunden... wird verwendet."
	else
	echo "Verwenden der Standart-Konfigurationsdatei: $defaultConfigFile"
	cp -v $defaultConfigFile $configFile
	status=$?
	if ! [ $status -eq 0 ]; then
		echo Fehler beim kopieren der Standartkonfigurationsdatei: $defaultConfigFile
		exit $status
	fi
	# Prüfen ob die Standard-Config ok ist.
	if ! checkConfig; then
		# Config immer noch nicht ok. Abbruche
		exit $staus
	fi
fi

##	Einlesen der Konfiguration
# Standartwerte. Werden verwendet, fals in dem Array unter .install.files[] nicht angegeben ("") oder lees (null) ist.
#	Installationsphard für den backupstaff. Mehrfache "/" mit einfachen "/" ersetzen. Dann ist es egal, ob in der Config ein "/" am ender steht oder nicht.
installDirectory=$(echo "$(jq -r .install.directory $configFile)/" | sed -r 's/\/{2,}/\//g')
installOwner=$(jq -r .install.owner $configFile)
installGroup=$(jq -r .install.group $configFile)
installMod=$(jq -r .install.mod $configFile)
installDependencies=$(jq -r .install.dependencies[] $configFile)

installPackagediskription=$(jq -r .install.packagediskription $configFile)

#	Wird alles zum kopieren und rechte setzen der Dateien benötigt. wird in der Schleife ausgeführt
#	Benutzung: readInstallFileConfig <index für das Array in .install.files
readInstallFileConfig(){
	#	Zum erkennen der zu instalierenden Dateien. Zum erkennen das die Liste .install.files[] leer oder zu ende ist.
	installFilesIgnore=$(jq -r .install.files[$1].ignore $configFile)
	#	Wird alles zum kopieren und rechte setzen der Dateien benötigt.
	installFilesSource=$(jq -r .install.files[$1].source $configFile)
	installFilesDestination=$(jq -r .install.files[$1].destination $configFile)

	installFilesOwner=$(jq -r .install.files[$1].owner $configFile)
	# Prüfen Besitzer angegeben ist. Dies könnte man in eine Funktion legen, um es für alle Parameter zu nurzen.
	if [ -z $installFilesOwner ]; then
		# Parameter ist leer
		# Standart verwenden
		installFilesOwner=$installOwner
	elif [ $installFilesOwner == "null" ]; then
		# jq liefert null zurück, wenn der Filter keine ergebnisse liefert.
		# Standart verwenden
		installFilesOwner=$installOwner
	fi
	
	installFilesGroup=$(jq -r .install.files[$1].group $configFile)
	# Prüfen Gruppe angegeben ist. Dies könnte man in eine Funktion legen, um es für alle Parameter zu nurzen.
	if [ -z $installFilesGroup ]; then
		# Parameter ist leer
		# Standart verwenden
		installFilesGroup=$installGroup
	elif [ $installFilesGroup == "null" ]; then
		# jq liefert null zurück, wenn der Filter keine ergebnisse liefert.
		# Standart verwenden
		installFilesGroup=$installGroup
	fi
	
	installFilesMod=$(jq -r .install.files[$1].mod $configFile)
	# Prüfen Dateirechte angegeben sind. Dies könnte man in eine Funktion legen, um es für alle Parameter zu nurzen.
	if [ -z $installFilesMod ]; then
		# Parameter ist leer
		# Standart verwenden
		installFilesMod=$installMod
	elif [ $installFilesMod == "null" ]; then
		# jq liefert null zurück, wenn der Filter keine ergebnisse liefert.
		# Standart verwenden
		installFilesMod=$installMod
	fi
	
	installFilesLinkName=$(jq -r .install.files[$1].link.name $configFile)

	# Ersetzt die Zieldatei mit den instalationsverzeichniss und ergänzt mit den Source-Namen
	useDefaultDir(){
		installFilesDestination=$installDirectory$installFilesSource
	}
		# Prüfen ob die Zeildatei angegeben ist
	if [ -z $installFilesDestination ]; then
		# Parameter ist leer
		# Standart verwenden
		useDefaultDir
	elif [ $installFilesDestination == "null" ]; then
		# jq liefert null zurück, wenn der Filter keine ergebnisse liefert.
		# Standart verwenden
		useDefaultDir
	fi
}

# Funktionen deklarieren
#	Siehe auch readInstallFileConfig unter: Einlesen der Konfiguration

# Zum debuggen und testen
debug(){
	echo -- debug --
	echo "$*"
	echo "status				$status"
	echo "configFile			$configFile"
	echo "installDirectory		$installDirectory"
	echo "installFilisCount		$installFilisCount"
	echo "installFilesDestination	$installFilesDestination"
	echo "installFilesLinkName			$installFilesLinkName"
	echo -----------
}


echo "Instaliere $installPackagediskription nach $installDirectory"
echo "Benötigte Abhängigkeiten sind:"
echo "$installDependencies"
pacman -Qi $installDependencies >> /dev/null # Fehlerausgeben, sollte ein Packet fehlen.
# Abfragen, ob installiert werden soll.
echo -n "Installation starten? "
read reply
case "$reply" in
	Y|y|J|j)
	;;
	N|n)
		exit $status
	;;
	*)
		exit $status
	;;
    esac


# Prüfen ob der nächst übergeortnete Verzeichniss existiert, und erstellt dieses wenn nötig.
# Benutzung: checkAndCreateDir <Zieldatei> 
checkAndCreateDir(){
	if ! [ -d ${1%/*} ]; then
		# Verzeichniss existiert nicht, erstellen.
		mkdir -pv ${1%/*}
	fi
}

#	Kopiert dateien und setzt die Rechte
#	benutzung: copy <quelldatei> <zieldatei> <besitzer> <gruppe> <rechte> <softlink>(optional)
copy(){
	echo Installiere: $2, $3:$4 $5
	
	# Prüfen ob der nächst übergeortnete Verzeichniss existiert, und erstellt dieses wenn nötig.
	checkAndCreateDir $2
	
	cp $1 $2
	status=$?
	if ! [ $status -eq 0 ]; then
		echo "Fehler beim Kopieren von $1 nach $2"
		exit $status
	fi
	
	# Prüfen ob das Ziel auch eine Datei ist.
	if [ -d $2 ]; then
		# Ziel ist ein Verzeichniss!
		echo "$2 ist ein Verzeichniss. Rechte werden nicht gesetzt!"
	else
		# Ziel ist KEIN Verzeicniss
		chown $3:$4 $2
		status=$?
		if ! [ $status -eq 0 ]; then
			echo "Fehler beim zuweisen des Besitzers ($3:$4) bei $2"
			exit $status
		fi

		chmod $5 $2
		status=$?
		if ! [ $status -eq 0 ]; then
			echo "Fehler beim setzen der rechte ($5) bei $2"
			exit $status
		fi
		
		# Symlink setzen, wenn angegeben
		if ! [ -z $6 ]; then
			# symlink-Parameter ist nicht leer
			if ! [ $6 == "null" ]; then
				# symlink-parameter ist nicht null (jq liefert null zurück, wenn der Filter keine ergebnisse liefert.)
				# ggf. Verzeichniss erstellen.
				checkAndCreateDir $6
				# Symlink erstellen
				ln --verbose --force --symbolic $2 $6
				status=$?
				if ! [ $status -eq 0 ]; then
					echo "Fehler beim erstellen des Softlinks $6 für $2"
					exit $status
				fi
			fi
		fi
	fi
}


# Dateien instalieren (kopieren)
i=0
while [ true ]; do
	# Das nächste Element in der Liste einlesen.
	readInstallFileConfig $i
	# Schleife Abbrechen, wenn das Ende der Liste erreicht ist. 
	if [ -z $installFilesIgnore ]; then # String ist leer
	break
	elif [ $installFilesIgnore == "null" ]; then # jq liefert null zurück, wenn der Filter keine ergebnisse liefert.
	break
	fi
	# Installieren wenn nicht ignoriert
	if [ $installFilesIgnore == "0" ]; then
		# Installiere die Datei
		copy $installFilesSource $installFilesDestination $installFilesOwner $installFilesGroup $installFilesMod $installFilesLinkName
		#echo "copy $installFilesSource $installFilesDestination $installFilesOwner $installFilesGroup $installFilesMod" # face
	else
		# Ist irgendwie als zu ignorieren markiert.
		echo "Überspringe: $installFilesDestination wegen .install.files[$i].ignore=$installFilesIgnore in $configFile"
	fi
	
	i=$(( $i + 1)) # Zählen für die Schleiffe
done 


exit $status
