#!/bin/bash

set -eux

function load_modules() {
    module purge
    module load slurm
    module load dot
    module load turbovnc/2.0.1
    module load vgl/2.5.1/64
    module load singularity/current
    module load rhel7/global
    module load cmake/latest
    module load gcc/7
    module load openmpi-3.1.3-gcc-7.2.0-b5ihosk
    module load python/3.7
    export CC=mpicc
    export CXX=mpic++
    export LIB_PATH=""
}

function build_hdf5() {
  cd $WORKDIR
  if [ -d "$WORKDIR"/hdf5 ] ; then
      export HDF5_DIR=$WORKDIR/hdf5
      return
  fi
  mkdir hdf5
  cd hdf5
  wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.16/src/hdf5-1.8.16.tar.gz
  tar -zxf  hdf5-1.8.16.tar.gz
  cd hdf5-1.8.16
  mkdir bld
  cd bld
  ../configure --prefix=$WORKDIR/hdf5
  make -j4
  make install
  cd ..
#  export LIB_PATH=$PWD/
  cd ..
  cd ..
  cd ..
}

function build_moab() {
  if [ -d "$WORKDIR"/moab ] ; then
      export MOAB_DIR=$WORKDIR/moab
      export LIB_PATH=$MOAB_DIR/lib64
      return
  fi

  cd $WORKDIR 
  git clone https://bitbucket.org/fathomteam/moab
  cd moab
  autoreconf -fi
  mkdir bld
  cd bld
  ../configure --with-hdf5 --enable-optimize --disable-debug --with-eigen3=$WORKDIR/eigen3 --enable-shared --disable-fortran --prefix=$WORKDIR/moab
  make -j4
  make install
  make check
  cd ..
  export MOAB_DIR=$PWD
  export LIB_PATH=$MOAB_DIR/lib64
  cd ..
  cd ..
}

function build_eigen() {
  if [ -d "$WORKDIR/eigen" ] ; then
      export EIGEN3_DIR=$WORKDIR/eigen
      return
  fi
  cd $WORKDIR
  git clone https://gitlab.com/libeigen/eigen.git
  cd eigen
  mkdir bld
  cd bld
  CC=$CC CXX=$CXX FC=$FC cmake .. -DCMAKE_INSTALL_PREFIX=$WORKDIR/eigen
  make -j4
  make install
  cd ..
  export EIGEN3_DIR=$PWD
  cd ..
}

function build_dagmc() {
  if [ -d $WORKDIR/dagmc ] ; then
      export DAGMC_DIR=$WORKDIR/dagmc
      export LIB_PATH=$LIB_PATH:$DAGMC_DIR/lib
      return
  fi

  cd $WORKDIR
  git clone https://github.com/svalinn/dagmc
  cd dagmc
  mkdir bld
  cd bld
  export LD_LIBRARY_PATH=$TBB_DIR/lib64:$LD_LIBRARY_PATH
  CC=$CC CXX=$CXX cmake ../ -DBUILD_STATIC_LIBS=OFF -DMOAB_DIR=$MOAB_DIR -DDOUBLE_DOWN=ON -Ddd_ROOT=$DD_DIR/lib -DBUILD_TALLY=OFF -DCMAKE_INSTALL_PREFIX=$WORKDIR/dagmc 
  make -j4
  make install
  cd ..
  cd ..
  export LIB_PATH=$LIB_PATH:$DAGMC_DIR/lib
}

function build_tbb() {
  if [ -d "$WORKDIR/oneTBB" ] ; then
      export TBB_DIR=$WORKDIR/oneTBB
      export LIB_PATH=$LIB_PATH:$TBB_DIR/lib64
      return
  fi
  cd $WORKDIR
  git clone https://github.com/oneapi-src/oneTBB
  cd oneTBB
  mkdir bld
  cd bld
  CC=$CC CXX=$CXX cmake .. -DCMAKE_INSTALL_PREFIX=$WORKDIR/oneTBB -DTBB_TEST=OFF
  make -j4
  make install
  cd ..
  export TBB_DIR=$WORKDIR/oneTBB
  cd ..
  export LIB_PATH=$LIB_PATH:$TBB_DIR/lib64
}


function build_embree() {
  if [ -d "$WORKDIR/embree" ] ; then
      export EMBREE_DIR=$WORKDIR/embree
      export LIB_PATH=$LIB_PATH:$EMBREE_DIR/lib64
      return
  fi
  cd $WORKDIR
  git clone https://github.com/embree/embree
  cd embree
  mkdir bld
  cd bld
  CC=$CC CXX=$CXX cmake .. -DTBB_DIR=$WORKDIR/oneTBB/lib64/cmake/TBB/ -DEMBREE_ISPC_SUPPORT=OFF -DEMBREE_TUTORIALS_GLFW=OFF -DEMBREE_TUTORIALS=OFF -DCMAKE_INSTALL_PREFIX=$WORKDIR/embree 
  make -j4
  make install
  cd ..
  export EMBREE_DIR=$WORKDIR/embree
  cd ..
  export LIB_PATH=$LIB_PATH:$EMBREE_DIR/lib64
}

function build_doubledown() {
  if [ -d "$WORKDIR/double-down" ] ; then
      export DD_DIR=$WORKDIR/double-down
      export LIB_PATH=$LIB_PATH:$DD_DIR/lib
      return
  fi
  cd $WORKDIR
  mkdir $WORKDIR/double-down
  export LD_LIBRARY_PATH=$TBB_DIR/lib64
  git clone https://github.com/pshriwise/double-down
  cd double-down
  mkdir bld
  cd bld
  cmake .. -DMOAB_DIR=$MOAB_DIR/lib64 -DCMAKE_INSTALL_PREFIX=$WORKDIR/double-down -DEMBREE_DIR=$EMBREE_DIR 
  make -j4
  make install
  cd ..
  export DD_DIR=$WORKDIR/double-down
  cd ..
  export LIB_PATH=$LIB_PATH:$DD_DIR/lib
}

function build_openmc() {
  if [ -d "$WORKDIR"/openmc ] ; then
      export OPENMC_DIR=$WORKDIR/openmc
      export LIB_PATH=$LIB_PATH:$OPENMC_DIR/lib64
      return
  fi
  cd $WORKDIR
  git clone https://github.com/openmc-dev/openmc
  cd openmc
  mkdir bld
  cd bld
  CC=$CC CXX=$CXX cmake .. -DCMAKE_INSTALL_PREFIX=$WORKDIR/openmc
  make -j4
  make install
  cd ..
  python3 setup.py install --user
  cd ..
  cd ..
  export LIB_PATH=$LIB_PATH:$OPENMC_DIR/lib64
}

cd $WORKDIR

load_modules
#build_hdf5
build_eigen
build_moab
build_tbb
build_embree
build_doubledown
build_dagmc
build_openmc


echo "Dont forget to add the LD_LIBRARY_PATH to your script/environment"
echo 'export LD_LIBRARY_PATH="$LD_LIBRARY_PATH":'$LIB_PATH
