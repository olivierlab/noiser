# NoiseR
Noise Recorder for Linux using SoX

# USAGE
Record ambient noise above defined threshold

# OPTIONS

## Without parameter

-c: Create the global sound file
-g: Do not read the records at the end
-h: Display help
-j: Generate filtered sounds
-o: Do not compress in FLAC and keep the sound source files
-q: Take a screenshot with ffmpeg
-r: Listen to noise reduction
-s: Show gnuplot trace while recording
-u: Take noise samples below the threshold
-z: Calibrate noise

## With parameter

-a WAIT       : Waiting time in minutes before recording
-b BIT        : Scanning precision (default : 16 bit, other : 8, 24, 32)
-d DUREE      : sample duration (default 5 s)
-e EXT        : Sound file type  (default wav)
-f ECHDIR     : Sample recording folder (default /dev/shm)
-i PRESET     : Predefined settings (default low, other 'high')
-k DATETIME   : Registration deadline date format 'YYYY-MM-DD HH:MM:SS' (default infinity)
-l THRES      : Threshold for recording signal (default 0.03, min 0, max 1)
-m MICRO      : set the microphone record level (default 30%, min 0%, max 100%)
-n THRESNOISE : Threshold for noise recording (default 0.02)
-p RATE       : Sampling rate (default : low (11025 Hz), other : hig (44100 Hz), med (22050 Hz))
-t DESTDIR    : Record saving folder (default ~/Public/noise)
-v NBSAMPLE   : Number of noise samples below the threshold (defaut 20)

# EXAMPLES

 - Show this help : noiser.sh -h
 - Theshold at 0.4, microphone level at 55%, record length 3s and show trace with gnuplot : noiser.sh -s -l 0.4 -m 55% -d 3
 - Environmental calibration : noiser.sh -z -u -v 100 -l 1.0
