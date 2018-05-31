#!/bin/bash

###########
# script to run the tof calibration
# The steps are
#  make sure MAUS environment is set
#  make sure the ROOT file from the reducer exists
#    OR make sure the user supplies their own( hidden - EXPERTS ONLY)
#  run a clean cmake
#  make on the Makefile generated by cmake
#  run the calibration
#  log
#
#  the default location of the ROOT file is
#     $MAUS_WEB_MEDIA_RAW/tofcalibdata.root
#  if the file does not exist in this location,
#     check that the reducer (ReduceCppTofCalib) ran
#     -- if the reducer ran, it should have produced a file tofcalibdata.root
#     check that tofcalibdata.root got moved to MAUS_WEB_MEDIA_RAW
#
#  to use your own input instead of the default
#  run with ./run_tof_calib.sh myFile.root
#    and answer y when it prompts you to confirm
#
###########


exec="tofCalib"

inputRoot="tofcalibdata.root"

logFile="tofcalib_log.txt"

# exit if MAUS_ROOT_DIR is not set
if [ -z "${MAUS_ROOT_DIR+x}" ]; then
  echo "MAUS_ROOT_DIR is not set"
  echo "Please go to the MAUS instllation directory and run 'source env.sh' and try again"
  echo "Exiting."
  exit 1
fi

# if the script was run with an argument, get a confirmation
if [ $# -ne 0 ] && [ -f $1 ]; then
  echo -e "Hmm....you seem to want to use $1 as the input ROOT file?\n"
  echo -e "I expect to get my input from ${MAUS_WEB_MEDIA_RAW}/$inputRoot\n"
  read -r -p "Are you sure you want to use $1 as the input instead? [y/n] " ANSWER
  case "$ANSWER" in
      Y*|y*)
             echo -e "You answered $ANSWER"
             if [ ! -s $1 ]; then
                echo -e "..but $1 does not exist OR is empty"
                echo -e "Exiting\n"
                #exit 1
             fi
             echo -e "Setting inputRoot file to $1\n"
             inputRoot=$1
             myInput=true ;;
      N*|n*)
             echo -e "You answered $ANSWER. I will not continue.\n"
             exit 1 ;;
      * )
             echo -e "Sorry! $ANSWER is not a valid answer. Answer y or n\n" ;;
   esac
fi

# validate the default location for the root file
if [ ! $myInput ] && [ -z "${MAUS_WEB_MEDIA_RAW+x}" ]; then
  echo -e "MAUS_WEB_MEDIA_RAW is not set"
  echo -e "This is where I expect to find the ROOT file output from the TofCalib reducer"
  echo -e "Please set the environment variable and try again."
  echo -e "Exiting.\n"
  exit 1
fi

if [ ! $myInput ] && [ ! -f "${MAUS_WEB_MEDIA_RAW}/$inputRoot" ]; then
  echo -e "\nOops!\ntofcalibdata.root does not exist in $MAUS_WEB_MEDIA_RAW"
  echo -e "Check that the ReduceCppTofCalib ran successfully."
  echo -e "Exiting.\n"
  exit 1
fi

if [ ! $myInput ] && [ ! -s "${MAUS_WEB_MEDIA_RAW}/$inputRoot" ]; then
  echo -e "\nUh oh!"
  echo -e "${MAUS_WEB_MEDIA_RAW}/$inputRoot is Empty"
  echo -e "Check that ReduceCppTofCalib ran successfully."
  echo -e "Exiting.\n"
  exit 1
fi

# set the input file name and path
if [ ! $myInput ]; then
  inputFile=${MAUS_WEB_MEDIA_RAW}/$inputRoot
else
  inputFile=$inputRoot
fi

# remove stale cmake cache
if [ -f "CMakeCache.txt" ]; then
  echo "Found an existing CMakeCache.txt file. Removing it.."
  rm -f CMakeCache.txt
fi

# remove stale cmake builds
if [ -d "CMakeFiles" ]; then
  echo "Found an existing CMakeFiles directory. Removing it.."
  rm -fr CMakeFiles
fi

# run cmake
echo -e "\nRunning cmake..."
cmake -DCMAKE_C_COMPILER=$MAUS_THIRD_PARTY/third_party/install/bin/gcc -DCMAKE_CXX_COMPILER=$MAUS_THIRD_PARTY/third_party/install/bin/g++ .

# if cmake exited abnormally, quit
if [ $? -ne 0 ]; then
  echo -e "\nThere was an error running cmake."
  echo -e "Look at the error message above from the running of cmake"
  echo -e "If you are not sure you can fix it, contact an expert"
  echo -e "Exiting.\n"
  exit 1
fi

# now we should have a Makefile to build the executable
echo -e "\nBuilding tofCalib executable...\n"
make

# quit if make terminated abnormally
if [ $? -ne 0 ]; then
  echo -e "\nError building the tofCalib executable."
  echo -e "Fix the error or contact an expert"
  echo -e "Exiting.\n"
  exit 1
fi

echo -e "Successfully built $exec\n"
ls -l $exec

echo -e "\nNow running the calibration. Logging in $logFile"
echo -e "This may take a few minutes..."

# run the calibration
./$exec $inputFile >& $logFile

# if exit code is !0 report and quit
if [ $? -ne 0 ]; then
  echo -e "\nWe seem to have terminated abnormally. Check the log -- $logFile\n"
  exit 1
fi

# remove newline characters at end of the outputs
# cannot upload to or read from CDB otherwise
if [ -f tmpFile ]; then
  rm -f tmpFile
fi
perl -pe 'chomp if eof' tofTWcalib.txt > tmpFile
mv -f tmpFile tofTWcalib.txt
perl -pe 'chomp if eof' tofTriggercalib.txt > tmpFile
mv -f tmpFile tofTriggercalib.txt
perl -pe 'chomp if eof' tofT0calib.txt > tmpFile
mv -f tmpFile tofT0calib.txt

echo -e "\nCompleted calibration"
echo -e "Output histograms are in:\n"
ls -l tofcalib_histos.root
echo -e "\nCheck the files to make sure they look OK"
echo -e "If you are not sure, consult an expert"
echo -e "Thank you for calibrating the TOF.\n"

# done
exit 0