#!/bin/bash

#  ___                 _        _                         _
# |   \ ___   _ _  ___| |_   __| |_  __ _ _ _  __ _ ___  | |
# | |) / _ \ | ' \/ _ \  _| / _| ' \/ _` | ' \/ _` / -_) |_|
# |___/\___/ |_||_\___/\__| \__|_||_\__,_|_||_\__, \___| (_)
#                                             |___/
#

filteredSound="no"
listen="yes"
profilSave="no"
showTrace="no"
listenNoiseReduction="no"
globalSound="no"
precStatSaved="no"
calibrate="no"
takePicture="no"
isExistsVideo0="no"
compressToFlac="yes"
saveSample="no"

#     _      __           _ _              _
#  __| |___ / _|__ _ _  _| | |_  __ ____ _| |_  _ ___ ___
# / _` / -_)  _/ _` | || | |  _| \ V / _` | | || / -_|_-<
# \__,_\___|_| \__,_|\_,_|_|\__|  \_/\__,_|_|\_,_\___/__/
#

duree=5
preset='low'
attente=5
ext=wav
rate=11025
bit=16
record=/dev/shm
sauvegardeBase=~/Public/noise
recordDateTimeLimit="infinity"
nbSample=20

#                         _      __           _ _              _
#  _  _ ___ _  _ _ _   __| |___ / _|__ _ _  _| | |_  __ ____ _| |_  _ ___ ___
# | || / _ \ || | '_| / _` / -_)  _/ _` | || | |  _| \ V / _` | | || / -_|_-<
#  \_, \___/\_,_|_|   \__,_\___|_| \__,_|\_,_|_|\__|  \_/\__,_|_|\_,_\___/__/
#  |__/
#

