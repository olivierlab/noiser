#!/bin/bash

#                       _
#  _ __ _ _ ___ ___ ___| |_ ___
# | '_ \ '_/ -_|_-</ -_)  _(_-<
# | .__/_| \___/__/\___|\__/__/
# |_|
#

case $preset in
    "high")
        # high detection level but high white noise
        seuil=0.4
        microlevel="70%"
        seuilNoise=0.075
        ;;
    "med")
        # med white noise and med detection level
        seuil=0.15
        microlevel="50%"
        seuilNoise=0.04
        ;;
    "day")
        seuil=0.07
        microlevel="30%"
        seuilNoise=0.025
        ;;
    "low" | "night" | *)
        # Low white noise and low detection level
        seuil=0.03
        microlevel="30%"
        seuilNoise=0.02
        preset="low"
        ;;
esac
