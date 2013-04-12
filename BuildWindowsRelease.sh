#!/bin/sh -xe
# script to build the OpenModelica nightly-build
# Adrian Pop [adrian.pop@liu.se]
# 2012-10-08

# expects to have these things installed:
#  python 2.7.x
#  nsis installer
#  TortoiseSVN command line tools
#  Qt 4.8.0
#  jdk

# get the ssh password via command line
export SSHUSER=$1
export MAKETHREADS=$2

# set the path to our tools
export PATH=/c/bin/python273:/c/Program\ Files/TortoiseSVN/bin/:/c/bin/jdk170/bin:/c/bin/nsis/:/c/bin/QtSDK/Desktop/Qt/4.8.0/mingw/bin:$PATH

# set the OPENMODELICAHOME and OPENMODELICALIBRARY
export OPENMODELICAHOME="c:\\dev\\OpenModelica\\build"
export OPENMODELICALIBRARY="c:\\dev\\OpenModelica\\build\\lib\\omlibrary"

# have OMDEV in Msys version
export OMDEV=/c/OMDev/

# update OMDev
cd /c/OMDev/
svn up . --accept theirs-full

# update OpenModelica
cd /c/dev/OpenModelica
svn up . --accept theirs-full
# get the revision
export REVISION=`svn info | grep "Revision:" | cut -d " " -f 2`
# Directory prefix
export OMC_INSTALL_PREFIX="/c/dev/OpenModelica_releases/${REVISION}/"

# test if exists and exit if it does
if [ -d "${OMC_INSTALL_PREFIX}" ]; then
	echo "Revision ${OMC_INSTALL_PREFIX} already exists! Exiting ..."
	exit 0
fi

# create the revision directory
mkdir -p ${OMC_INSTALL_PREFIX}
# make the file prefix
export OMC_INSTALL_FILE_PREFIX="${OMC_INSTALL_PREFIX}OpenModelica-revision-${REVISION}"

# update OpenModelicaSetup
cd /c/dev/OpenModelica/Compiler/OpenModelicaSetup
svn up . --accept theirs-full

# build OpenModelica
cd /c/dev/OpenModelica
echo "Cleaning OpenModelica"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} clean
cd /c/dev/OpenModelica
echo "Building OpenModelica"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} all
echo "Building OpenModelica second time to handle templates"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} all
cd /c/dev/OpenModelica
echo "Installing Python scripting"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} install-python
#build OMClients
echo "Cleaning OMClients"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} clean-qtclients
echo "Building OMClients"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} qtclients
cd /c/dev/OpenModelica
echo "Building MSVC compiled runtime"
make -f 'Makefile.omdev.mingw' simulationruntimecmsvc
echo "Building CPP runtime"
make -f 'Makefile.omdev.mingw' runtimeCPPinstall

# build the installer
cd /c/dev/OpenModelica/Compiler/OpenModelicaSetup
makensis OpenModelicaSetup.nsi
# move the installer
mv OpenModelica.exe ${OMC_INSTALL_FILE_PREFIX}.exe

# gather the svn log
cd /c/dev/OpenModelica
svn log -v -r ${REVISION}:1 > ${OMC_INSTALL_FILE_PREFIX}-ChangeLog.txt

# make the readme
export DATESTR=`date +"%Y-%m-%d_%H-%M"`
echo "Automatic build of OpenModelica by testwin.openmodelica.org at date: ${DATESTR} from revision: ${REVISION}" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Read OpenModelica-revision-${REVISION}-ChangeLog.txt for more info on changes." >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "See also (match revision ${REVISION} to build jobs):" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  https://test.openmodelica.org/hudson/" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  http://test.openmodelica.org/~marsj/MSL31/BuildModelRecursive.html" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "  http://test.openmodelica.org/~marsj/MSL32/BuildModelRecursive.html" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
cat >> ${OMC_INSTALL_FILE_PREFIX}-README.txt <<DELIMITER
*Instructions to prepare test information if you find a bug:*
 
generate a .mos script file loading all libraries and files your model need call simulate.
// start .mos script
loadModel(Modelica);
loadFile("yourfile.mo");
simulate(YourModel);
// end .mos script

Start this .mos script in a shell with omc and use the debug flags
+d=dumpdaelow,optdaedump,bltdump,dumpindxdae,backenddaeinfo.
Redirect the output stream in file ( > log.txt)

A series of commands to run via cmd.exe
is given below. Note that z: is the drive
where your .mos script is:
c:\> z:
z:\> cd \path\to\script(.mos)\file\
z:\path\to\script(.mos)\file\> \path\to\OpenModelica\bin\omc.exe
+d=dumpdaelow,optdaedump,bltdump,dumpindxdae,backenddaeinfo 
YourScriptFile.mos > log.txt 2>&1

Either send the log.txt file alongwith your bug 
description to OpenModelica@ida.liu.se or file a
bug in our bug tracker:
  https://trac.openmodelica.org/OpenModelica

Happy testing!
DELIMITER
echo " " >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Read more about OpenModelica at https://openmodelica.org" >> ${OMC_INSTALL_FILE_PREFIX}-README.txt
echo "Contact us at OpenModelica@ida.liu.se for further issues or questions." >> ${OMC_INSTALL_FILE_PREFIX}-README.txt

# make the testsuite-trace
cd /c/dev/OpenModelica
echo "Running testsuite trace"
make -f 'Makefile.omdev.mingw' ${MAKETHREADS} testlog > time.log 2>&1

echo "Check HUDSON testserver for the testsuite trace here (match revision ${REVISION} to build jobs): " >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
echo "  https://test.openmodelica.org/hudson/" >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
cat time.log >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
cat testsuite/testsuite-trace.txt >> ${OMC_INSTALL_FILE_PREFIX}-testsuite-trace.txt
rm -f time.log

ls -lah ${OMC_INSTALL_PREFIX}

cd ${OMC_INSTALL_PREFIX}
# move the last nightly build to the older location
ssh ${SSHUSER}@build.openmodelica.org <<ENDSSH
#commands to run on remote host
cd public_html/omc/builds/windows/nightly-builds/
mv -f OpenModelica* older/
ENDSSH
scp OpenModelica* ${SSHUSER}@build.openmodelica.org:public_html/omc/builds/windows/nightly-builds/

echo "All done!"
