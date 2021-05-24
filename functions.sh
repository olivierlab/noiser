#!/bin/bash

# color definition
RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# if we are on virtual terminal
if [[ "$(tty)" =~ "tty" ]]; then
    isTTY="yes"
else
    isTTY="no"
fi

# Show help
function showHelp() {
    echo "USAGE : Enregistrer le bruit ambiant au dessus d'un certain seuil"
    echo 'OPTIONS :'
    echo " * Sans paramètre :"
    echo "   -c            : Créer le fichier son global"
    echo "   -g            : Ne pas lire les enregistrements à la fin"
    printf "   -h            : Afficher l'aide (${RED}Ce parametre doit se situer en premiere position${NC})\n"
    echo "   -j            : Générer les sons filtrés"
    echo "   -o            : Ne pas compresser en FLAC et conserver les fichiers sources $ext"
    echo "   -q            : Prendre une capture d'écran avec ffmpeg"
    echo "   -r            : Ecouter la réduction de bruit"
    if [[ "$gnuplotOk" == "yes" && "$isTTY" == "no" ]]; then
        echo "   -s            : Afficher la trace gnuplot pendant l'enregistrement"
    fi
    printf "   -u            : Prendre ${GREEN}$nbSample${NC} échantillons de bruit en dessous du seuil de ${GREEN}$seuil${NC}\n"
    echo "   -z            : Calibrer le bruit"
    echo " * Avec paramètre :"
    printf "   -a WAIT       : Durée d'attente en minute avant enregistrement (defaut ${GREEN}$attente${NC} minutes)\n"
    printf "   -b BIT        : Précision de numérisation (defaut : ${GREEN}$bit bit${NC}, other : 8, 24, 32)\n"
    printf "   -d DUREE      : durée d'un échantillon (defaut ${GREEN}$duree s${NC})\n"
    printf "   -e EXT        : Type de fichier son (defaut ${GREEN}$ext${NC})\n"
    printf "   -f ECHDIR     : Dossier d'enregistrement des échantillons (defaut ${GREEN}$record${NC})\n"
    printf "   -i PRESET     : Predefined settings (default ${GREEN}$preset${NC}, other 'high')\n"
    printf "   -k DATETIME   : Date heure limite d'enregistrement au format 'YYYY-MM-DD HH:MM:SS' (default ${GREEN}$recordDateTimeLimit${NC})\n"
    printf "   -l SEUIL      : défini le seuil (defaut ${GREEN}$seuil${NC}, min 0, max 1)\n"
    printf "   -m MICRO      : défini le niveau du micro (defaut ${GREEN}%s${NC}, min %s, max %s)\n" "$microlevel" "0%" "100%"
    printf "   -n SEUILNOISE : Seuil pour la détection de bruit (default ${GREEN}$seuilNoise${NC})\n"
    printf "   -p PRECIS     : Précision d'échantillonage (defaut : ${GREEN}low (11025 Hz)${NC}, other : hig (44100 Hz), med (22050 Hz))\n"
    printf "   -t DESTDIR    : Dossier de sauvegarde des enregistrements (defaut ${GREEN}$sauvegardeBase${NC})\n"
    printf "   -v NBSAMPLE   : Modifier le nombre d'échantillons de bruit en dessous du seuil (defaut ${GREEN}$nbSample${NC})\n"
    echo 'EXEMPLES :'
    echo "   - Afficher cette aide : $me -h"
    echo "   - Seuil à 0.4, micro à 55%, durée de 3s et vu trace : $me -s -l 0.4 -m 55% -d 3"
    echo "   - Calibration de l'environnement : $me -z -u -v 100 -l 1.0"
}

# vérifie que les applications utiles sont installées sur la machine
function checkApplicationsExists() {
    isApplicationExist "sox"
    if [ "$?" == "0" ]; then
        soxOk="yes"
    else
        soxOk="no"
    fi

    isApplicationExist "amixer"
    if [ "$?" == "0" ]; then
        amixerOk="yes"
    else
        amixerOk="no"
    fi

    isApplicationExist "gnuplot"
    if [ "$?" == "0" ]; then
        gnuplotOk="yes"
    else
        gnuplotOk="no"
        printf "> Installer ${RED}gnuplot${NC} pour visualiser les courbes des signaux et les statistiques.\n"
        printf "> apt-get install gnuplot\n"
    fi

    isApplicationExist "flac"
    if [ "$?" == "0" ]; then
        flacOk="yes"
    else
        flacOk="no"
        printf "> Installer ${RED}flac${NC} pour compresser les sons.\n"
        printf "> apt-get install flac\n"
    fi

    if [ "$takePicture" == "yes" ]; then
        isApplicationExist "ffmpeg"
        if [ "$?" == "0" ]; then
            ffmpegOk="yes"
        else
            ffmpegOk="no"
            printf "> Installer ${RED}ffmpeg${NC} pour faire des photos.\n"
            printf "> apt-get install ffmpeg\n"
        fi

        isVideo0=`ls /dev/video0 2>/dev/null | wc -l`
        if [ "$isVideo0" == "1" ]; then
            isExistsVideo0="yes"
        else
            isExistsVideo0="no"
            printf "> Le dossier ${RED}/dev/video0${NC} n'existe pas.\n"
            printf "> Activer la webcam si vous voulez des captures d'écran.\n"
        fi
    fi
}

# vérifie si l'application existe
function isApplicationExist() {
    application="$1"
    result=`whereis "$application" | sed 's/^.*: *//'`
    if [ "$result" == "" ]; then
        # l'application n'existe pas
        return 1
    else
        # l'application existe
        return 0
    fi
}

# Afficher le logo de l'application
function showApplicationLogo() {
    cat "$logo"
}

# Pour arrêter une boucle
function setTrapCtrlC() {
    # Set a trap for SIGINT and SIGTERM signals
    stop="no"
    trap "stop=$yes;echo ''" SIGTERM SIGINT
}

# Sauvegarde des paramètres
function saveParameters() {
    local parametrage=$sauvegardeNow/parametrage.txt
    echo "Parametrage :" > $parametrage
    echo "- CLI = $cliParameters" >> $parametrage
    echo "- Duree = $duree s" >> $parametrage
    echo "- Seuil = $seuil" >> $parametrage
    echo "- Micro = $microlevel" >> $parametrage
    echo "- Rate = $rate Hz" >> $parametrage
    echo "- Bit = $bit" >> $parametrage
}

# reglage micro
function reglerNiveauMicro() {
    niveau="$1"
    printsep
    echo "> Reglage du niveau du micro a $niveau"
    amixer -q set 'Capture' $niveau
}

# suppression de tous les fichiers d'un dossier
function removefileinto() {
    dossier="$1"
    cd $dossier
    lieu=`pwd`
    if [ "$lieu" == "$dossier" ]; then
        printsep
        printf "> Suppression des fichiers dans ${GREEN}$dossier${NC}\n"
        rm -f *
    fi
}

# affichage d'une séparation
function printsep() {
    #nbChar=100
    #serie=`seq 1 $nbChar`
    #echo "~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~-~"
    #printf '~%.0s-%.0s' $serie && echo ""
    #echo "==========================================================================="
    #printf '=%.0s' $serie && echo ""
    #echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    #printf '+%.0s' $serie && echo ""
    #echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    #printf '~%.0s' $serie && echo ""
    #echo "***************************************************************************"
    #printf '*%.0s' $serie && echo ""
    #echo "###########################################################################"
    #printf '#%.0s' $serie && echo ""

    echo "---------------------------------------------------------------------------"
}

# visualise le signal avec gnuplot
function killGnuplotWindow() {
    # suppression de la fenêtre gnuplot persistante
    pkill -x gnuplot
}

# Recup des statistiques du signal
function getSoundStats() {
    #whatStat="$1"
    #myStat=`sox -t $ext $bruit -n stat stats 2>&1 | grep "$whatStat" | cut -d ':' -f 2 | sed 's/ //g' | sed 's/,/./g'`
    #echo $myStat

    filename="$1"

    # mémorisation des données précédentes
    memoDataStatPast

    # nouvelle méthode
    statistiques=`sox -t $ext "$filename" -n stat stats 2>&1`

    for statistique in $statistiques; do
        if [[ "$statistique" =~ ^"Maximum amplitude" ]] ; then maximumAmplitude=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"Minimum amplitude" ]] ; then minimumAmplitude=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"Midline amplitude" ]] ; then midlineAmplitude=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"RMS lev dB" ]] ; then rmsLevDb=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"RMS Pk dB" ]] ; then rmsPkDb=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"RMS Tr dB" ]] ; then rmsTrDb=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"Crest factor" ]] ; then crestFactor=$(getStatValue "$statistique"); fi
        if [[ "$statistique" =~ ^"Pk count" ]] ; then pkcount=$(getStatValue "$statistique"); fi
    done
}

# recup d'une valeur statistique
function getStatValue() {
    statistique="$1"
    value=`echo "$statistique" | sed -e 's/^.* //' | sed 's/,/./g'`
    echo "$value"
}

# enregistrement du son
function recordMicrophone() {
    extension="$1"
    soundFile="$2"
    length="$3"

    sox -V0 -q -c 1 -t alsa default -b $bit -r $rate -e signed -t $extension "$soundFile" trim 0 $length

    let nbFilesEnregistres++
}

# espace disque disponible
function getSpaceDir() {
    directory="$1"
    echo `df -h "$directory" | tail -n 1 | sed 's/  */ /g' | cut -d ' ' -f 5 | sed 's/%//'`
}

# Afiche l'en-tête en début de programme
function showEnTete() {
    printsep
    #echo "Press Ctrl+C stop the process"
    printf "Press ${GREEN}Ctrl+C${NC} stop the process\n"
    #echo "Press Ctrl+Z pause the process :"
    printf "Press ${GREEN}Ctrl+Z${NC} pause the process :\n"
    echo "> 'fg' restore it."
    echo "> 'jobs' show backgrounded commands"
    printf "> A pause superior at ${RED}$minTimeDiffToStop seconds${NC} stop the process.\n"
    printf "Chaque echantillon dure ${GREEN}$duree secondes${NC}.\n"
    printf "Echantillonnage à ${GREEN}$rate Hz${NC}.\n"
    printf "Le seuil est a ${GREEN}$seuil${NC}.\n"
    if [ "$listen" == "yes" ]; then
        if [ "$filteredSound" == "yes" ]; then
            echo "Ecoute finale des enregistrements filtrés"
        else
            echo "Ecoute finale des enregistrements"
        fi
    fi
    if [ "$listenNoiseReduction" == "yes" ]; then
        echo "Ecoute finale avec reduction de bruit"
    fi
    if [ "$showTrace" == "yes" ]; then
        echo "Affichage du signal avec Gnuplot"
    fi
    if [ "$calibrate" == "yes" ]; then
        printf "Les stats des ${RED}sons non enregistrés${NC} serviront à mesurer le seuil de détection\n"
    fi

    addButCircumstances
}

# attente avant de continuer
function waitSomeTime() {
    if [ $attente -gt 0 ]; then
        printsep
        printf "Attente de ${RED}$attente${NC} minutes avant enregistrement ...\n"
        sleep ${attente}m
    fi
}

# on lance un enregistrement à blanc pour éviter un mauvais signal
function whiteRecord() {
    printsep
    printf "> Enregistrement à blanc de 1s ...\n"
    recordMicrophone $ext "$bruit" 1
}

# Add But and Circumstances
function addButCircumstances() {
    local informations=$sauvegardeNow/informations.txt
    printsep
    echo "Informations :" >> $informations
    echo "Saisissez le but de l'enregistrement et les circonstances"
    echo " puis appuyer sur la touche Entrée pour terminer :"
    printf "> ${GREEN}But${NC} : "
    read but
    if [ "$but" != "" ]; then
        echo "- But = $but" >> $informations
    fi
    printf "> ${GREEN}Circonstances${NC} : "
    read circonstances
    if [ "$circonstances" != "" ]; then
        echo "- Circonstances = $circonstances" >> $informations
    fi
}

# Add a conclusion
function addConclusion() {
    local informations=$sauvegardeNow/informations.txt
    printsep
    echo "Saisissez une conclusion et appuyer sur la touche Entrée pour terminer :"
    printf "> ${GREEN}Conclusion${NC} : "
    read conclusion
    if [ "$conclusion" != "" ]; then
        echo "- Conclusion = $conclusion" >> $informations
    fi
}

# ecoute du résultat final normalisé fichier par fichier
function listenFinalResult() {
    printsep

    typeResult=""

    if [ "$filteredSound" == "yes" ]; then
        typeResult="filtered"
    fi

    if [ "$typeResult" == "filtered" ]; then
        result="$sauvegardeNow/filtered/noise-record-*.$ext"
        printf "> Ecoute ${GREEN}des fichiers filtrés${NC}\n"
    else
        printf "> Ecoute ${GREEN}des fichiers${NC}\n"
        result="$sauvegardeNow/noise-record-*.$ext"
    fi


    # Set a trap for SIGINT and SIGTERM signals
    setTrapCtrlC

    counter=0
    skip=0

    printf "Press ${GREEN}Ctrl+C${NC} during audio stop listening\n"
    printf "Appuyez sur :\n"
    printf " - '${GREEN}Entrée${NC}' pour écouter avec pause\n"
    printf " - '${RED}e${NC}' pour écouter sans pause\n"
    printf " - '${RED}q${NC}' pour passer\n"
    printf "Votre choix : "
    read answer

    withPause="yes"
    case "${answer}" in
        "q")
            # quitter l'écoute
            return 0
            ;;
        "e")
            withPause="no"
            ;;
        *)
            ;;
    esac

    printsep

    printf "Appuyez sur :\n"
    printf " - '${GREEN}Entrée${NC}' pour écouter normalement\n"
    printf " - '${GREEN}n${NC}' pour normaliser le son\n"
    printf "Votre choix : "
    read answer

    normalized="no"

    case "${answer}" in
        "n")
            normalized="yes"
            ;;
        *)
            ;;
    esac

    # écouter
    for onefile in `ls -1 $result`; do
        let counter++
        let skip--
        if [ $skip -lt 0 ]; then
            skip=0
            # recup des stats
            if [ "$filteredSound" == "yes" ]; then
                getSoundStats "${onefile/filtered\//}"
            fi
            getSoundStats "$onefile"
            # nom du fichier seul
            namebase=`basename "$onefile" .$ext`
            # recup timestanp
            timestamp=${namebase:13:19}
            # séparation date heure
            arrayDateTime=($(echo "$timestamp" | tr "_" "\n"))
            # la date
            theDate=${arrayDateTime[0]}
            # l'heure
            theTime=${arrayDateTime[1]}
            theTime=${theTime//-/:} # remplacement global de "-" par ":"
            # le texte à afficher
            text=`date --date "$theDate $theTime" +"- %A %e %B à %H:%M:%S"`

            if [ "$filteredSound" == "yes" ]; then
                printf "%s (num = ${GREEN}%s${NC} - max filter = ${GREEN}%s${NC} - max = ${GREEN}%s${NC})\n" "$text" "$counter/$nbFilesSauvegardes" "$maximumAmplitude" "$memoMaximumAmplitude"
            else
                printf "%s (num = ${GREEN}%s${NC} - max = ${GREEN}%s${NC})\n" "$text" "$counter/$nbFilesSauvegardes" "$maximumAmplitude"
            fi

            loop="yes"
            oneTimeNormalized="no"

            while [ "$loop" == "yes" ]; do
                # Hear sound
                if [[ "$normalized" == "yes" || "$oneTimeNormalized" == "yes" ]]; then
                    # Normalized sound
                    #play -V0 -q $filename gain -n -3
                    play -V0 -q $onefile norm
                else
                    # Natural sound
                    play -V0 -q $onefile
                fi
                oneTimeNormalized="no"

                # If continius play
                loop=`[ "$withPause" == "yes" ] && echo "yes" || echo "no"`

                # Quit the loop
                if [ "$stop" == "yes" ]; then
                    break
                fi

                # if pause between files, show choice
                if [ "$withPause" == "yes" ]; then
                    # add comment or choose options
                    printf " > Comment (${RED}1${NC} = remove, ${GREEN}2${NC} = listen, ${GREEN}3${NC} = skip 10 records"
                    if [[ "$isTTY" == "no" ]]; then
                        printf ", ${GREEN}4${NC} = plot"
                    fi
                    if [[ "$normalized" == "no" ]]; then
                        printf ", ${GREEN}5${NC} = normalize"
                    fi
                    printf ") : "
                    read comment

                    # Choice management
                    case "$comment" in
                        "1")
                            printf " > Sure (${RED}Y${NC} to confirm) ? "
                            read confirm
                            if [ "$confirm" == "Y" ]; then
                                if [ "$filteredSound" == "yes" ]; then
                                    # suppression du fichier filtré
                                    rm "$onefile"

                                    # suppression du fichier non filtré
                                    rm "${onefile/filtered\//}"
                                else
                                    # suppression du fichier
                                    rm "$onefile"
                                fi

                                # suppression de la ligne de stat
                                sed -i "/^$timestamp;/d" "$sauvegardeNow/stat.csv"
                            fi
                            loop="no"
                            ;;
                        "2")
                            ;;
                        "3")
                            skip=9
                            loop="no"
                            ;;
                        "4")
                            if [[ "$isTTY" == "no" ]]; then
                                showTrace="yes"
                                showWithGnuplot "$onefile"
                                showTrace="no"
                            fi
                            ;;
                        "5")
                            oneTimeNormalized="yes"
                            ;;
                        *)
                            sed -i "s/^$timestamp;.*$/&$comment/" "$sauvegardeNow/stat.csv"
                            loop="no"
                            ;;
                    esac
                fi
            done

            # quit the loop
            if [ "$stop" == "yes" ]; then
                break
            fi
        fi
    done
}

# ecoute avec réduction de bruit : résultat peu probant !
function listenWithNoiseReduce() {
    if [ "$profilSave" == "yes" ]; then
        printsep
        echo "> Calcul du profil de bruit"
        sox $sauvegardeNow/noise-profil.$ext -n noiseprof $sauvegardeNow/noise-profil.prof

        if [ -f $sauvegardeNow/noise-profil.prof ]; then
            printf "> Ecoute ${GREEN}avec reduction de bruit${NC} ...\n"
            # Conversion
            sox -q $sauvegardeNow/noise-record-*.$ext $sauvegardeNow/without-noise.$ext noisered $sauvegardeNow/noise-profil.prof 0.21
        fi
        if [ -f $sauvegardeNow/without-noise.wav ]; then
            # Ecoute
            play -q -V0 $sauvegardeNow/without-noise.wav
            # Suppression
            rm -f $sauvegardeNow/without-noise.wav
        fi
    fi
}

# Création d'un fichier son global
function createGlobalSound() {
    if [ "$globalSound" == "yes" ]; then
        printsep
        printf "> Concatenation des fichiers dans ${GREEN}$sauvegardeNow/noise-record-all.$ext${NC} ...\n"
        if [ "$profilSave" == "yes" ]; then
            sox -V0 -q $sauvegardeNow/noise-profil.$ext $sauvegardeNow/noise-record-*.$ext $sauvegardeNow/noise-record-all.$ext
        else
            sox -V0 -q $sauvegardeNow/noise-record-*.$ext $sauvegardeNow/noise-record-all.$ext
        fi
    fi
}

# Sauvegarde l'élément enregistré
function saveRecordedTrack() {
    let nbRecord++
    lastRecordDateSave=`date +"%Y-%m-%d_%H-%M-%S"`
    filename="$sauvegardeNow/noise-record-$lastRecordDateSave-$maximumAmplitude.$ext"
    mv $bruit "$filename"
    # on passe à la ligne si on a des fichiers non enregistrés pour lesquels on a affiché un point
    if [ "$printPoint" == "yes" ]; then
        printf "\n"
    fi
    printf "> ${RED}$nbRecord${NC} : save ${GREEN}$lastRecordDateSave${NC} ($minimumAmplitude ~ $maximumAmplitude - $loadAverage1m)\n"
    saveOneStat

    if [ "$takePicture" == "yes" ]; then
        takeScreenshot "$lastRecordDateSave"
    fi
}

# on sauvegarde un échantillon sous le seuil pour vérifier son contenu
function initArrayThreshold() {
    if [ "$saveSample" == "yes" ]; then
        pasEchantillon=`echo "$seuil/$nbSample" | bc -l`
        for i in `seq 0 $nbSample`; do
            myIndexedArrayThreshold[$i]="no"
        done

        mkdir "$sauvegardeNow/threshold"

        printsep
        printf "> sauvegarde de ${GREEN}$nbSample${NC} échantillons sous le seuil de ${GREEN}$seuil${NC}\n"
        printf "  dans le dossier ${GREEN}$sauvegardeNow/threshold${NC}\n"
    fi
}

# on sauvegarde un échantillon sous le seuil pour vérifier son contenu
function saveOneSampleUnderThreshold() {
    if [ "$saveSample" == "yes" ]; then
        index=`echo "$maximumAmplitude/$pasEchantillon" | bc`

        if [ "${myIndexedArrayThreshold[$index]}" == "no" ]; then
            thresholdDateSave=`date +"%Y-%m-%d_%H-%M-%S"`
            filename="$sauvegardeNow/threshold/noise-sample-$index-$maximumAmplitude-$thresholdDateSave.$ext"
            mv $bruit "$filename"
            myIndexedArrayThreshold[$index]="yes"
            let nbSampleSaved++
            printf "\n> Noise sample ${GREEN}$index${NC} : ${thresholdDateSave/_/ at }\n"
        fi
    fi
}

# Création des fichiers filtrés
function createFilteredSound() {
    if [ "$filteredSound" == "yes" ]; then
        printsep

        printf "> Création des sons ${GREEN}filtrés${NC} ...\n"
        for filename in `ls -1 $sauvegardeNow/noise-record-*.$ext 2>/dev/null`; do
            namebase=`basename "$filename" .$ext`

            # filtrage du signal
            filenameFilter="$sauvegardeNow/filtered/$namebase.$ext"
            filterSoundFile "$filename" "$filenameFilter"
        done
    fi
}

# filtrage d'un fichier
function filterSoundFile() {
    input="$1"
    output="$2"

    # The moving average filter is a simple Low Pass FIR (Finite Impulse Response) filter
    # URL : https://medium.com/blueeast/how-to-use-moving-average-filter-to-counter-noisy-data-signal-5b530294a12e
    sox "$input" "$output" fir 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05
}

# Sauvegarde le profil de bruit
function saveNoiseProfile() {
    mv $bruit $sauvegardeNow/noise-profil.$ext
    printf ">>> Profil de bruit ${GREEN}enregistre${NC} !\n"
}

# Sauvegarde en-tête des stats de bruit au format csv
function saveEnTeteStatCalibrate() {
    echo "timestamp;maximumAmplitude;minimumAmplitude;midlineAmplitude;rmsLevDb;rmsPkDb;rmsTrDb;crestFactor;pkcount;loadAverage" > "$sauvegardeNow/stat_noise.csv"
}

# Sauvegarde de la stat du bruit au format csv
function saveOneStatCalibrate() {
    if [ "$calibrate" == "yes" ]; then
        timestamp=`date +"%Y-%m-%d_%H-%M-%S"`
        echo "$timestamp;$maximumAmplitude;$minimumAmplitude;$midlineAmplitude;$rmsLevDb;$rmsPkDb;$rmsTrDb;$crestFactor;$pkcount;$loadAverage1m" >> "$sauvegardeNow/stat_noise.csv"
    fi
}

# Sauvegarde en-tête des stats globales au format csv
function saveEnTeteStat() {
    echo "timestamp;maximumAmplitude;minimumAmplitude;midlineAmplitude;rmsLevDb;rmsPkDb;rmsTrDb;crestFactor;pkcount;loadAverage;comment" > "$sauvegardeNow/stat.csv"
}

# Sauvegarde de la stat du fichier au format csv
function saveOneStat() {
    #filename="$1"
    #namebase=`basename "$filename" .$ext`
    #timestamp="${namebase/noise-record-/}"
    timestamp=`date +"%Y-%m-%d_%H-%M-%S"`
    echo "$timestamp;$maximumAmplitude;$minimumAmplitude;$midlineAmplitude;$rmsLevDb;$rmsPkDb;$rmsTrDb;$crestFactor;$pkcount;$loadAverage1m;" >> "$sauvegardeNow/stat.csv"
}

# Sauvegarde de la stat ptrécédente mémorisée au format csv
function saveMemoStat() {
    if [ "$memoMaximumAmplitude" != "" ]; then
        echo "$memoTimestamp;$memoMaximumAmplitude;$memoMinimumAmplitude;$memoMidlineAmplitude;$memoRmsLevDb;$memoRmsPkDb;$memoRmsTrDb;$memoCrestFactor;$memoPkcount;$memoLoadAverage1m;" >> "$sauvegardeNow/stat.csv"
    fi
}

# mémorisation des stats
function memoDataStat() {
    memoMaximumAmplitude="$maximumAmplitude"
    memoMinimumAmplitude="$minimumAmplitude"
    memoMidlineAmplitude="$midlineAmplitude"
    memoRmsLevDb="$rmsLevDb"
    memoRmsPkDb="$rmsPkDb"
    memoRmsTrDb="$rmsTrDb"
    memoCrestFactor="$crestFactor"
    memoPkcount="$pkcount"
    memoLoadAverage1m="$loadAverage1m"
}

# mémorisation des données statistiques
function memoDataStatPast() {
    memoTimestamp=`date +"%Y-%m-%d_%H-%M-%S" --date="$duree seconds ago"`
    memoDataStat
}

# statistique du nombre d'enregistrements
function printStatEnregistrement() {
    printsep
    nbFilesSauvegardes=`ls -1 "$sauvegardeNow" | grep -e ".*.$ext" | wc -l`
    let totalsecondes=$nbFilesSauvegardes*$duree
    let minutes=$totalsecondes/60
    let secondes=$totalsecondes-$minutes*60
    let tauxEnregistrement=100*$nbFilesSauvegardes/$nbFilesEnregistres
    printf "> ${GREEN}%s${NC} fichiers enregistrés (%s m %s s)\n" "$nbFilesSauvegardes" "$minutes" "$secondes"
    printf "> Taux d'enregistrement de ${GREEN}%s${NC}\n" "$tauxEnregistrement %"
    if [ "$nbFilesSauvegardes" == "0" ]; then
        listen="no"
    fi
    if [ "$saveSample" == "yes" ]; then
        printf "> ${GREEN}%s${NC} échantillons de bruit enregistrés\n" "$nbSampleSaved"
    fi
    printf ">>> Appuyer sur ${GREEN}Entrée${NC} pour continuer "
    read
}

# visualise le signal et la FFT avec gnuplot
function showWithGnuplot() {
    if [[ "$showTrace" == "yes" && "$gnuplotOk" == "yes" ]]; then
        local filename="$1"

        if (( $isToSave )); then
            title="SAVE"
            color=2
        else
            title="not save"
            color=1
        fi

        noiseDat="/dev/shm/noise.dat"
        fftDat="/dev/shm/fft.dat"

        # préparation des données pour gnuplot
        sox "$filename" "$noiseDat" && sed -i '/;/d' "$noiseDat"
        # calcule la FFT
        sox "$filename" -n trim 0 $dureeForFFT stat -freq 2>"$fftDat" && sed -n -i '1,2048p' "$fftDat"

        killGnuplotWindow

        # affichage de la trace et masquage des messages d'erreur
        gnuplot -p -e "set multiplot layout 2,1; \
                       set title '$title' tc lt $color; \
                       set label 1 'max=$maximumAmplitude' at 0,$maximumAmplitude; \
                       set label 2 'min=$minimumAmplitude' at 0,$minimumAmplitude; \
                       set label 3 'pkcount=$pkcount' at $duree,$minimumAmplitude right; \
                       set label 4 'crest=$crestFactor' at $duree/2,$minimumAmplitude center; \
                       set label 5 'RMS lev=$rmsLevDb dB' at $duree/2,$maximumAmplitude center; \
                       set label 6 'mid=$midlineAmplitude' at 0,$midlineAmplitude;
                       set xlabel 'Time (s)'; \
                       plot '$noiseDat' with lines title 'Full Sound';\
                       unset title; \
                       unset label 1; \
                       unset label 2; \
                       unset label 3; \
                       unset label 4; \
                       unset label 5; \
                       unset label 6; \
                       set xlabel 'Freq (Hz)'; \
                       plot '$fftDat' with lines title 'FFT 4096 first points'; \
                       unset multiplot;" 2>/dev/null
    fi
}

# visualise les résultats avec gnuplot
function plotStatWithGnuplot() {
    local sauvegarde="$1"

    csvFile="$sauvegarde/stat.csv"

    if [[ -f "$csvFile" && "$gnuplotOk" == "yes" ]]; then
        local seuilMax="$2"

        # Pour mémo : label en bas à gauche du point
        # '$sauvegarde/stat.csv' using 1:2:10 with labels right offset char -0.5,-0.5 rotate by 45 notitle, \
        # pour le png
        # set terminal png size 900,900; \
        gnuplot -p -e "set datafile separator ';'; \
                    set terminal svg size 900,1200 enhanced background rgb 'white'; \
                    set xdata time; \
                    set timefmt '%Y-%m-%d_%H-%M-%S'; \
                    set format x '%H:%M'; \
                    set tics font 'Helvetica,8'; \
                    set output '$sauvegarde/stat_all.svg'; \
                    set multiplot layout 4,1; \
                    set ylabel 'Level'; \
                    set key opaque right bottom; \
                    plot '$csvFile' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('maximumAmplitude') : 1/0) with linespoint title 'max', \
                         '' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('minimumAmplitude') : 1/0) with linespoint title 'min', \
                         '' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('midlineAmplitude') : 1/0) with linespoint title 'mid',
                         '' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('maximumAmplitude') : 1/0):11 with labels left offset char 0.5,0.5 rotate by 45 notitle; \
                    set ylabel 'dB'; \
                    plot '$csvFile' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('rmsLevDb') : 1/0) with linespoint title 'RMS Lev dB', \
                         '' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('rmsPkDb') : 1/0) with linespoint title 'RMS Pk dB', \
                         '' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('rmsTrDb') : 1/0) with linespoint title 'RMS Tr dB'; \
                    set ylabel 'Factor'; \
                    plot '$csvFile' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('crestFactor') : 1/0) with linespoint title 'Crest factor';\
                    set xlabel 'Time'; \
                    set ylabel 'Load'; \
                    plot '$csvFile' using 'timestamp':(column('maximumAmplitude') <= $seuilMax ? column('loadAverage') : 1/0) with linespoint title 'Load average';" 2>/dev/null
    fi
}

# visualise les statistiques des bruits enregistrés avec gnuplot
function plotRegisteredNoiseBoxplotWithGnuplot() {
    local sauvegarde="$1"

    csvFile="$sauvegarde/stat.csv"

    if [[ -f "$csvFile" && "$gnuplotOk" == "yes" ]]; then
        local seuilMin="$2"
        local seuilMax="$3"

        gnuplot -p -e "set datafile separator ';'; \
                    set terminal svg size 500,900 enhanced background rgb 'white'; \
                    set output '$sauvegarde/stat_registered.svg'; \
                    set style fill solid 0.25 border -1; \
                    set style boxplot outliers pointtype 7 fraction 0.0; \
                    set style data boxplot; \
                    set boxwidth  0.5 absolute; \
                    set pointsize 0.5; \
                    set border 2; \
                    set xtics ('maximumAmplitude' 1) scale 0.0 nomirror; \
                    set ytics nomirror; \
                    unset key; \
                    stats '$csvFile' using ($seuilMin <= column('maximumAmplitude') && column('maximumAmplitude') <= $seuilMax ? column('maximumAmplitude') : 1/0) name 'A' nooutput; \
                    set title \"NOISES RECORDED\nbetween $seuilMin and $seuilMax\"; \
                    set label 1 sprintf('- Mean : %.3f ± %.2f', A_mean, A_stddev) at (1),A_mean front offset 9,0 textcolor lt 1; \
                    set label 2 sprintf('Median : %.3f -', A_median) at (1),A_median front right offset -9,0 textcolor lt 1; \
                    set label 3 sprintf('Q3 : %.3f -', A_up_quartile) at (1),A_up_quartile front right offset -9,0 textcolor lt 1; \
                    set label 4 sprintf('Q1 : %.3f -', A_lo_quartile) at (1),A_lo_quartile front right offset -9,0 textcolor lt 1; \
                    set label 5 sprintf('Max : %.3f -', A_max) at (1),A_max front right offset -9,0 textcolor lt 1; \
                    set label 6 sprintf('Min : %.3f -', A_min) at (1),A_min front right offset -9,0 textcolor lt 1; \
                    set label 7 sprintf('(%d records)', A_records) at (1),A_max front offset 9,0 textcolor lt 1; \
                    plot '$csvFile' using (1):($seuilMin <= column('maximumAmplitude') && column('maximumAmplitude') <= $seuilMax ? column('maximumAmplitude') : 1/0);" 2>/dev/null
    fi
}

# visualise les statistiques de bruit avec gnuplot
function plotNoiseBoxplotWithGnuplot() {
    local sauvegarde="$1"

    csvFile="$sauvegarde/stat_noise.csv"

    if [[ -f "$csvFile" && "$gnuplotOk" == "yes" ]]; then

        gnuplot -p -e "set datafile separator ';'; \
                    set terminal svg size 500,900 enhanced background rgb 'white'; \
                    set output '$sauvegarde/stat_noise.svg'; \
                    set style fill solid 0.25 border -1; \
                    set style boxplot outliers pointtype 7 fraction 0.0; \
                    set style data boxplot; \
                    set boxwidth  0.5 absolute; \
                    set pointsize 0.5; \
                    set border 2; \
                    set xtics ('maximumAmplitude' 1) scale 0.0 nomirror; \
                    set ytics nomirror; \
                    unset key; \
                    stats '$csvFile' using 'maximumAmplitude' name 'A' nooutput; \
                    set title 'NOISE NOT RECORDED'; \
                    set label 1 sprintf('- Mean : %.3f ± %.3f', A_mean, A_stddev) at (1),A_mean front offset 9,0 textcolor lt 1; \
                    set label 2 sprintf('Median : %.3f -', A_median) at (1),A_median front right offset -9,0 textcolor lt 1; \
                    set label 3 sprintf('Q3 : %.3f -', A_up_quartile) at (1),A_up_quartile front right offset -9,0 textcolor lt 1; \
                    set label 4 sprintf('Q1 : %.3f -', A_lo_quartile) at (1),A_lo_quartile front right offset -9,0 textcolor lt 1; \
                    set label 5 sprintf('Max : %.3f -', A_max) at (1),A_max front right offset -9,0 textcolor lt 1; \
                    set label 6 sprintf('Min : %.3f -', A_min) at (1),A_min front right offset -9,0 textcolor lt 1; \
                    set label 7 sprintf('(%d records)', A_records) at (1),A_max front offset 9,0 textcolor lt 1; \
                    plot '$csvFile' using (1):'maximumAmplitude';" 2>/dev/null
    fi
}

# prendre une photo
function takeScreenshot() {
    if [[ "$ffmpegOk" == "yes" && "$isExistsVideo0" == "yes" ]]; then
        local lastRecordDateSave="$1"
        local filename="$sauvegardeNow/noise-record-$lastRecordDateSave.png"
        ffmpeg -f video4linux2 -i /dev/video0 -vframes 1 "$filename" 2>/dev/null
        printf "> Screenshot ${GREEN}noise-record-$lastRecordDateSave.png${NC}\n"
    fi
}


# Vérifie si l'enregistrement a été suspendu (Ctrl-Z, mise en veille, ...)
function isSupended() {
    local timestampBeforeRecord="$1"
    local minTimeDiffToStop="$2"

    timestampNow=`date +"%s"`

    let ecartBetweenRecord=$timestampNow-$timestampBeforeRecord

    if [ $ecartBetweenRecord -gt $minTimeDiffToStop ]; then
        stop="$yes"
        echo ''
    fi
}

# Affiche le temps après le début de l'enregistrement
function showTimeSinceRecording() {
    local timestampStartRecord="$1"

    timestampNow=`date +"%s"`

    let timeDelta=$timestampNow-$timestampStartRecord

    echo "$timeDelta"
}

# Compression des sons en flac pour gagner de l'espace disque
function askCompressionSounds() {
    if [[ "$flacOk" == "yes" && "$compressToFlac" == "yes" ]]; then
        printsep
        printf "> Voulez-vous compresser les sons ${GREEN}$ext${NC} au format ${GREEN}flac${NC} et supprimer les sons ${RED}$ext${NC} ?\n"
        printf "> ${RED}Y${NC} to confirm : "
        read compress

        if [ "$compress" == "Y" ]; then
            compressAndRemoveSounds
        fi
    fi
}

function compressAndRemoveSounds() {
    if [[ "$flacOk" == "yes" && "$compressToFlac" == "yes" ]]; then
        printsep
        printf "> Compression des sons ${GREEN}$ext${NC} au format ${GREEN}flac${NC} et suppression des sons ${RED}$ext${NC}.\n"

        for file in `find $sauvegardeNow -name "*.$ext"`; do
            # compression
            flac "$file" 2>/dev/null

            if [ "$?" == "0" ]; then
                # suppression du fichier source si encodage bien passé
                rm -f $file 2>/dev/null
            fi
        done
    fi
}

# Read the last minute load average
function readLoadAverage1m() {
    loadAverage1m=`cat /proc/loadavg | cut -d " " -f 1`
}
