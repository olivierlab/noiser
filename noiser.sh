#!/bin/bash

# pour positionner le début en haut d'écran
clear

#  ____                                _
# |  _ \ __ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___
# | |_) / _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
# |  __/ (_| | | | (_| | | | | | |  __/ ||  __/ |  \__ \
# |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/
#

# memorize parameters on command line for save
cliParameters="$@"

# script directory
my_dir=`dirname "$0"`
# full directory
script_path=$(dirname $(readlink -f "$0"))
# script name
me=`basename "$0"`
# full name
fullScriptName="$script_path/$me"

#     _      __           _ _
#  __| |___ / _|__ _ _  _| | |_
# / _` / -_)  _/ _` | || | |  _|
# \__,_\___|_| \__,_|\_,_|_|\__|
#
yes="yes"
source "$my_dir/default.sh"

#   ___ _     _          _
#  / __| |___| |__  __ _| | __ ____ _ _ _ ___
# | (_ | / _ \ '_ \/ _` | | \ V / _` | '_(_-<
#  \___|_\___/_.__/\__,_|_|  \_/\__,_|_| /__/
#

bruit=$record/noise.$ext

# Statistiques du signal
maximumAmplitude=''
minimumAmplitude=''
midlineAmplitude=''
rmsLevDb=''
rmsPkDb=''
rmsTrDb=''
crestFactor=''
pkcount=''
# Statistiques du signal précédent
memoMaximumAmplitude=''
memoMinimumAmplitude=''
memoMidlineAmplitude=''
memoRmsLevDb=''
memoRmsPkDb=''
memoRmsTrDb=''
memoCrestFactor=''
memoPkcount=''
memoTimestamp=''
# séparateur de stat sox
IFS=$'\n'
nbFilesEnregistres=0
nbFilesSauvegardes=0
lastRecordSave=""
# on suppose que les applications utiles sont présentes
soxOk="yes"
amixerOk="yes"
gnuplotOk="yes"
ffmpegOk="yes"
flacOk="yes"
# pour les échantillons au dessous du seuil
declare -A myIndexedArrayThreshold
nbSampleSaved=0
# Load average
loadAverage1m=0
memoLoadAverage1m=0
# logo
logo="$script_path/logo.txt"

#  _         _         _
# (_)_ _  __| |_  _ __| |___
# | | ' \/ _| | || / _` / -_)
# |_|_||_\__|_|\_,_\__,_\___|

source "$my_dir/functions.sh"

#  ___      _ _
# |_ _|_ _ (_) |_
#  | || ' \| |  _|
# |___|_||_|_|\__|
#

# vérification de la présence des applications
checkApplicationsExists

showApplicationLogo

#  _                 _                        _
# | |   ___  __ _ __| |  _ __ _ _ ___ ___ ___| |_ ___
# | |__/ _ \/ _` / _` | | '_ \ '_/ -_|_-</ -_)  _(_-<
# |____\___/\__,_\__,_| | .__/_| \___/__/\___|\__/__/
#                       |_|
#

listOptions="a:b:cd:e:f:ghi:jk:l:m:n:op:qrst:uv:z"

while getopts "$listOptions" option
do
    case "${option}" in
        i)
            preset="${OPTARG}"
            ;;
        *)
            ;;
    esac
done

source "$my_dir/presets.sh"

#  ___  ____ _____ ___ ___  _   _ ____
# / _ \|  _ \_   _|_ _/ _ \| \ | / ___|
#| | | | |_) || |  | | | | |  \| \___ \
#| |_| |  __/ | |  | | |_| | |\  |___) |
# \___/|_|    |_| |___\___/|_| \_|____/
#

# bash getopts use an environment variable OPTIND to keep track the last option argument processed.
# The fact that OPTIND was not automatically reset each time you called getopts in the same shell session,
# only when the shell was invoked. So from second time you called getopts with the same arguments
# in the same session, OPTIND wasn't changed, getopts thought it had done the job and do nothing.
#
# You can reset OPTIND manually to make it work
# URL : https://unix.stackexchange.com/questions/233728/bash-function-with-getopts-only-works-the-first-time-its-run
OPTIND=1

# recup options
while getopts "$listOptions" option
do
    case "${option}" in
        a)
            attente="${OPTARG}"
            ;;
        b)
            bit="${OPTARG}"
            ;;
        c)
            globalSound="yes"
            ;;
        d)
            duree="${OPTARG}"
            ;;
        e)
            ext="${OPTARG}"
            ;;
        f)
            record="${OPTARG}"
            ;;
        g)
            listen="no"
            ;;
        h)
            showHelp
            exit 0
            ;;
        j)
            filteredSound="yes"
            ;;
        k)
            recordDateTimeLimit="${OPTARG}"
            ;;
        l)
            seuil="${OPTARG}"
            ;;
        m)
            microlevel="${OPTARG}"
            ;;
        n)
            seuilNoise="${OPTARG}"
            ;;
        o)
            compressToFlac="no"
            ;;
        p)
            case "${option}" in
                "hig")
                    rate=44100
                    ;;
                "med")
                    rate=22050
                    ;;
                *)
                    rate=11025
                    ;;
            esac
            ;;
        q)
            takePicture="yes"
            ;;
        r)
            listenNoiseReduction="yes"
            ;;
        s)
            showTrace="yes"
            ;;
        t)
            sauvegardeBase="${OPTARG}"
            ;;
        u)
            saveSample="yes"
            ;;
        v)
            nbSample="${OPTARG}"
            ;;
        z)
            calibrate="yes"
            ;;
        *)
            ;;
    esac
done

#  __  __       _         ____
# |  \/  | __ _(_)_ __   |  _ \ _ __ ___   __ _ _ __ __ _ _ __ ___
# | |\/| |/ _` | | '_ \  | |_) | '__/ _ \ / _` | '__/ _` | '_ ` _ \
# | |  | | (_| | | | | | |  __/| | | (_) | (_| | | | (_| | | | | | |
# |_|  |_|\__,_|_|_| |_| |_|   |_|  \___/ \__, |_|  \__,_|_| |_| |_|
#                                          |___/

if [ "$soxOk" == "no" ]; then
    printf "> L'application ${RED}sox${NC} est nécessaire !\n"
    printf "> apt-get install sox\n"
    exit
fi

if [ "$amixerOk" == "no" ]; then
    printf "> L'application ${RED}amixer${NC} est nécessaire pour régler le niveau du microphone !\n"
    printf "> apt-get install alsa-utils\n"
    exit
fi

# if we are on virtual terminal
if [[ "$isTTY" == "yes" ]]; then
    # Le terminal virtuel uniquement est éteint après une minute d'inativité
    # Appuyer sur touche pour afficher l'écran
    setterm --blank 1
fi

doYouWantToContinue=""
let minTimeDiffToStop=3*$duree # 3 fois car 2 fois est insuffisant quand on affiche la trace du signal et la FFT
dureeForFFT=`echo 4096/$rate | bc -l`

while [ "$doYouWantToContinue" == "" ]; do

    # Set a trap for SIGINT and SIGTERM signals
    setTrapCtrlC

    # Création d'un sous-dossier dans sauvegarde et vérification de son existence
    mkdir -p "$sauvegardeBase"
    if [ -d $sauvegardeBase ]; then
        ladate=`date +"%Y-%m-%d_%H-%M-%S"`
        mkdir "$sauvegardeBase/$ladate"
        if [ "$filteredSound" == "yes" ]; then
            mkdir "$sauvegardeBase/$ladate/filtered"
        fi
        sauvegardeNow="$sauvegardeBase/$ladate"
    fi

    if [ -d $sauvegardeNow ]; then
        printsep
        printf "> Creation de ${GREEN}$sauvegardeNow${NC} reussie !\n"

        saveParameters

        saveEnTeteStat

        if [ "$calibrate" == "yes" ]; then
            saveEnTeteStatCalibrate
        fi

        # Echantillons sous le seuil
        initArrayThreshold
    else
        printf "Le dossier ${RED}$sauvegardeNow${NC} n'existe pas !\n"
        exit 1
    fi

    showEnTete

    # suppression des fichiers
    removefileinto "$record"
    #removefileinto "$sauvegardeNow"    # suppression des fichiers

    # niveau du micro
    reglerNiveauMicro $microlevel

    waitSomeTime

    # si appui sur Ctrl-C pendant attente
    if [ "$stop" == "$yes" ]; then
        exit
    fi

    whiteRecord

    #  ___                   _
    # | _ \___ __ ___ _ _ __| |
    # |   / -_) _/ _ \ '_/ _` |
    # |_|_\___\__\___/_| \__,_|
    #

    printsep
    echo "> Enregistrement ..."
    if [ "$listenNoiseReduction" == "yes" ]; then
        printf ">>> ${RED}Pas de bruit SVP${NC} , enregistrement du profil de bruit (seuil < ${RED}%s${NC}) ...\n" "$seuilNoise"
    fi
    cd "$record"

    nbRecord=0

    while true; do
        timestampBeforeRecord=`date +"%s"`

        case "$stop" in
            "yes")
                break
                ;;

            *)
                # enregistrement du bruit
                recordMicrophone $ext "$bruit" $duree

                readLoadAverage1m

                # Fin d'enregistrement si l'écart entre 2 enregistrements est supérieur à 2 fois la durée d'un échantillon
                isSupended "$timestampBeforeRecord" "$minTimeDiffToStop"

                if [ "$stop" == "yes" ]; then
                    break
                fi

                getSoundStats "$bruit"

                isToSave=$(echo "$maximumAmplitude >= $seuil || $minimumAmplitude <= -$seuil" | bc -l)

                showWithGnuplot "$bruit"

                # vérification de l'espace disque disponible
                spaceused=$(getSpaceDir "$sauvegardeNow")
                hasEnoughSpace=$(echo "$spaceused < 99" | bc -l)

                # S'il reste assez d'espace disque
                if (( $hasEnoughSpace )); then
                    # Si le signal est supérieur au seuil
                    if (( $isToSave )); then
                        if [ "$precStatSaved" == "no" ]; then
                            saveMemoStat
                        fi
                        saveRecordedTrack
                        precStatSaved="yes"
                        printPoint="no"
                    else
                        # marqueur de fichier enregistré mais non sauvegardé
                        printf "."
                        printPoint="yes"

                        # sauvegarde des stats pour évaluer le bruit
                        saveOneStatCalibrate

                        # on sauvegarde les stats actuelles
                        if [ "$precStatSaved" == "yes" ]; then
                            saveOneStat
                        fi

                        # on sauvegarde un échantillon sous le seuil pour vérifier son contenu
                        saveOneSampleUnderThreshold

                        precStatSaved="no"
                        # Si le profil de bruit n'est pas enregistré et qu'on veut entendre la réduction de bruit
                        if [[ "$listenNoiseReduction" == "yes" && "$profilSave" == "no" ]]; then
                            isNoiseToSave=$(echo "$maximumAmplitude <= $seuilNoise && $minimumAmplitude >= -$seuilNoise" | bc -l)
                            if (( $isNoiseToSave )); then
                                saveNoiseProfile
                                profilSave="yes"
                            fi
                        fi
                    fi
                else
                    stop=$yes
                    listen="no"
                    printf "> ${RED}Plus assez d'espace de sauvegarde${NC} !\n"
                fi
                ;;
        esac

        # fin d'enregistrement si on dépasse la date limite définie
        if [ "$recordDateTimeLimit" != "infinity" ]; then
            if [ $(date +"%s" --date="$recordDateTimeLimit") -lt $(date +"%s") ]; then
                printf "\n"
                break
            fi
        fi

        isSupended "$timestampBeforeRecord" "$minTimeDiffToStop"
    done

    #  ___ _ _ _
    # | __(_) | |_ ___ _ _
    # | _|| | |  _/ -_) '_|
    # |_| |_|_|\__\___|_|
    #

    createFilteredSound

    #  _    _    _
    # | |  (_)__| |_ ___ _ _
    # | |__| (_-<  _/ -_) ' \
    # |____|_/__/\__\___|_||_|
    #

    printStatEnregistrement

    # on écoute si on a arrété manuellement l'application
    if [ "$listen" == "yes" ]; then
        # et si des fichiers à écouter existent
        if [ -n "$(ls -A $sauvegardeNow)" ]; then
            listenFinalResult

            listenWithNoiseReduce
        fi
    fi

    #   ___ _     _          _   ___                   _
    #  / __| |___| |__  __ _| | / __| ___ _  _ _ _  __| |
    # | (_ | / _ \ '_ \/ _` | | \__ \/ _ \ || | ' \/ _` |
    #  \___|_\___/_.__/\__,_|_| |___/\___/\_,_|_||_\__,_|
    #

    createGlobalSound

    #  ___ _        _   _    _   _
    # / __| |_ __ _| |_(_)__| |_(_)__ ___
    # \__ \  _/ _` |  _| (_-<  _| / _(_-<
    # |___/\__\__,_|\__|_/__/\__|_\__/__/
    #

    plotStatWithGnuplot "$sauvegardeNow" "0.99"
    plotRegisteredNoiseBoxplotWithGnuplot "$sauvegardeNow" "$seuil" "0.99"
    plotNoiseBoxplotWithGnuplot "$sauvegardeNow"

    #   ___             _         _
    #  / __|___ _ _  __| |_  _ __(_)___ _ _
    # | (__/ _ \ ' \/ _| | || (_-< / _ \ ' \
    #  \___\___/_||_\__|_|\_,_/__/_\___/_||_|
    #

    addConclusion

    #   ___                              _
    #  / __|___ _ __  _ __ _ _ ___ _____(_)___ _ _
    # | (__/ _ \ '  \| '_ \ '_/ -_|_-<_-< / _ \ ' \
    #  \___\___/_|_|_| .__/_| \___/__/__/_\___/_||_|
    #                |_|
    #

    compressAndRemoveSounds

    #   ___       _ _
    #  / _ \ _  _(_) |_
    # | (_) | || | |  _|
    #  \__\_\\_,_|_|\__|
    #

    # quit
    printsep
    printf "Appuyer sur la touche ${RED}Entrée${NC} pour relancer immédiatement"
    if [ "$showTrace" == "yes" ]; then
        printf " et effacer la trace Gnuplot"
    fi
    printf " ou '${GREEN}q${NC}' pour quitter : "
    read doYouWantToContinue
    attente=0

    killGnuplotWindow

    if [ "$doYouWantToContinue" == "" ]; then
        clear
        showApplicationLogo
    fi
done
