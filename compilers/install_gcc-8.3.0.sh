#!/bin/bash

INSTALL_PATH=$HOME/gcc-graph
if [ "$1" != "" ]; then INSTALL_PATH=$1; fi
if [ "$2" = "compile-only" ]; then export COMPILE_ONLY=yes; fi
echo Installing gcc to $INSTALL_PATH

JOBS=`which nproc`
EXIT=$?
if [ "$EXIT" != "0" ]; then
  JOBS=1
else
  JOBS=`nproc`
fi

if [ ! -e gcc-8.3.0.tar.xz ]; then
  echo gcc-8.3.0.tar.xz not found, downloading
  wget ftp://ftp.gnu.org/pub/gnu/gcc/gcc-8.3.0/gcc-8.3.0.tar.xz
  if [ ! -e gcc-8.3.0.tar.xz ]; then
    echo Failed to download gcc, download gcc-8.3.0.tar.xz from www.gnu.org
    exit
  fi
fi

# Untar gcc
rm -rf gcc-graph/objdir 2> /dev/null
mkdir -p gcc-graph/objdir
echo Untarring gcc...
tar -Jxf gcc-8.3.0.tar.xz -C gcc-graph || exit

# Apply patch
cd gcc-graph/gcc-8.3.0
patch -p1 < ../../gcc-patches/gcc-8.3.0-cdepn.diff
cd ../objdir

# Configure and compile
../gcc-8.3.0/configure --prefix=$INSTALL_PATH --enable-shared --enable-languages=c,c++ || exit
make bootstrap -j$JOBS

RETVAL=$?
PLATFORM=x86_64-pc-linux-gnu
if [ $RETVAL != 0 ]; then
  if [ ! -e $PLATFORM/libiberty/config.h ]; then
    echo Checking if this is AArch64
    echo Note: This is untested, if building with AArch64 works, please email mel@csn.ul.ie with
    echo a report
    PLATFORM=aarch64-linux-gnu
    if [ ! -e $PLATFORM/libiberty/config.h ]; then
      echo Checking if this is CygWin
      echo Note: This is untested, if building with Cygwin works, please email mel@csn.ul.ie with
      echo a report
      export PLATFORM=x86_64-unknown-cygwin
      if [ ! -e $PLATFORM/libiberty/config.h ]; then
        echo Do not know how to fix this compile error up, exiting...
        exit -1
      fi
    fi
  fi
  cd $PLATFORM/libiberty/
  cat config.h | sed -e 's/.*undef HAVE_LIMITS_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_STDLIB_H.*/\#define HAVE_STDLIB_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_UNISTD_H.*/\#define HAVE_UNISTD_H 1/' > config.h.tmp && mv config.h.tmp config.h
  cat config.h | sed -e 's/.*undef HAVE_SYS_STAT_H.*/\#define HAVE_LIMITS_H 1/' > config.h.tmp && mv config.h.tmp config.h
  if [ "$PLATFORM" = "x86_64-unknown-cygwin" ]; then
    echo "#undef HAVE_GETTIMEOFDAY" >> config.h
  fi

  TEST=`grep HAVE_SYS_STAT_H config.h` 
  if [ "$TEST" = "" ]; then
    echo "#undef HAVE_SYS_STAT_H" >> config.h
    echo "#define HAVE_SYS_STAT_H 1" >> config.h
  fi
  cd ../../
  make -j$JOBS

  RETVAL=$?
  if [ $RETVAL != 0 ]; then
    echo
    echo Compile saved after trying to fix up config.h, do not know what to do
    echo This is likely a CodeViz rather than a gcc problem
    exit -1
  fi
fi

if [ "$COMPILE_ONLY" != "yes" ]; then
  make install
fi
