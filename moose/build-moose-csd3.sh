#!/bin/bash
#set -ue

export STACK_SRC=`mktemp -d /tmp/moose_stack_src.XXXXXX`
export WORKDIR=/home/dc-davi4/rds/rds-ukaea-ap001/moose_dev

function load_modules() {
    module purge
    # module load openmpi-3.1.3-gcc-7.2.0-b5ihosk gcc/7 cmake/latest
    module load rhel7/default-ccl
    module load openmpi/gcc/9.2/4.0.1
    #module load openmpi
    #module load libiconv-1.15-gcc-5.4.0-ymwv5vs
}

function _build_mpich33() {

    cd $WORKDIR
    if [ -d "$WORKDIR/mpich-3.3" ] ; then
       return
    fi

    cd $STACK_SRC
    curl -L -O http://www.mpich.org/static/downloads/3.3/mpich-3.3.tar.gz
    tar -xf mpich-3.3.tar.gz -C .
    mkdir $STACK_SRC/mpich-3.3/gcc-build
    cd $STACK_SRC/mpich-3.3/gcc-build
    ../configure --prefix=$WORKDIR/mpich-3.3 \
       --enable-shared \
       --enable-sharedlibs=gcc \
       --enable-fast=O2 \
       --enable-debuginfo \
       --enable-totalview \
       --enable-two-level-namespace \
       CC=gcc \
       CXX=g++ \
       FC=gfortran \
       F77=gfortran \
       F90='' \
       CFLAGS='' \
       CXXFLAGS='' \
       FFLAGS='' \
       FCFLAGS='' \
       F90FLAGS='' \
       F77FLAGS=''
    make -j4 # (where # is the number of cores available)
    make install
    export PATH=$WORKDIR/mpich-3.3/bin:$PATH
    export CC=mpicc
    export CXX=mpicxx
    export FC=mpif90
    export F90=mpif90
    export C_INCLUDE_PATH=$WORKDIR/mpich-3.3/include:$C_INCLUDE_PATH
    export CPLUS_INCLUDE_PATH=$WORKDIR/mpich-3.3/include:$CPLUS_INCLUDE_PATH
    export FPATH=$WORKDIR/mpich-3.3/include:$FPATH
    export MANPATH=$WORKDIR/mpich-3.3/share/man:$MANPATH
    export LD_LIBRARY_PATH=$WORKDIR/mpich-3.3/lib:$LD_LIBRARY_PATH
}

function _build_petsc() {
    cd $WORKDIR
    if [ -d "$WORKDIR/petsc" ] ; then
       return
    fi
    mkdir petsc
    cd petsc
    curl -L -O http://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-3.13.3.tar.gz
    tar -xf petsc-3.13.3.tar.gz -C .
    cd petsc-3.13.3
    ./configure \
	--prefix=$WORKDIR/petsc \
	--with-debugging=0 \
	--with-ssl=0 \
	--with-pic=1 \
	--with-openmp=1 \
	--with-mpi=1 \
	--with-shared-libraries=1 \
    --with-cxx-dialect=C++11 \
    --with-fortran-bindings=0 \
    --with-sowing=0 \
    --download-hypre=1 \
    --download-fblaslapack=1 \
    --download-metis=1 \
    --download-ptscotch=1 \
    --download-parmetis=1 \
    --download-superlu_dist=1 \
    --download-scalapack=1 \
    --download-mumps=0 \
    --download-slepc=1 \
    --with-64-bit-indices=1 \
#    --with-cc=/usr/local/Cluster-Apps/openmpi/gcc/9.3/4.0.4/bin/mpicc \
#    --with-cxx=/usr/local/Cluster-Apps/openmpi/gcc/9.3/4.0.4/bin/mpicxx \
#    --with-fc=/usr/local/Cluster-Apps/openmpi/gcc/9.3/4.0.4/bin/mpif90 \
    --with-mpi-dir=/usr/local/software/spack/current/opt/spack/linux-rhel7-x86_64/gcc-7.2.0/openmpi-3.1.3-b5ihoskgy7ny3nty67rdeckedakesoqa \
    PETSC_DIR=`pwd` PETSC_ARCH=linux-opt    
    make PETSC_DIR=$WORKDIR/petsc/petsc-3.13.3 PETSC_ARCH=linux-opt all
    make PETSC_DIR=$WORKDIR/petsc/petsc-3.13.3 PETSC_ARCH=linux-opt install
    make PETSC_DIR=$WORKDIR/petsc PETSC_ARCH="" check
    cd ..
    cd ..
    export PETSC_DIR=$WORKDIR/petsc
} 

function build_moose() {
    export MOOSE_JOBS=32
    cd $WORKDIR
    if [ -d "$WORKDIR/moose" ] ; then
       return
    fi
#    _build_mpich33
    load_modules    
    build_vtk_git
    cd $WORKDIR
    git clone https://github.com/idaholab/moose
    cd moose 
    git checkout master
    unset PETSC_DIR PETSC_ARCH
    ./scripts/update_and_rebuild_petsc.sh --prefix=$WORKDIR/petsc --with-debugging=no CXXOPTFLAGS='-O3 -march=cascadelake -funroll-loops' COPTFLAGS='-O3 -march=cascadelake -funroll-loops' FOPTFLAGS='-O3 -march=cascadelake' --download-cmake=1  --with-64-bit-indices=1 --download-make=1 --with-ptscotch=0
    if [ ! -f "$WORKDIR/petsc/lib/libpetsc.so" ] ; then
      echo "PETSc Install Unsuccessful"
      return
    fi 

    export PETSC_DIR=$WORKDIR/petsc
    export CC=mpicc
    export CXX=mpicxx
    export F90=mpif90
    export F77=mpif77
    export FC=mpif90
    if [ -d "$WORKDIR/vtk" ] ; then
      echo "building libmesh with VTK" 
      METHODS='opt' ./scripts/update_and_rebuild_libmesh.sh --with-mpi --with-cxx-std=2017 --with-vtk-include=$WORKDIR/vtk/include/vtk-9.1 --with-vtk-lib=$WORKDIR/vtk/lib64 --enable-vtk-required
    else
      echo "Building libmesh withOUT VTK"
      METHODS='opt' ./scripts/update_and_rebuild_libmesh.sh --with-mpi --with-cxx-std=2017 
    fi 
    ./configure --with-derivative-size=600 --with-ad-indexing-type=global
    cd framework
    METHOD=opt make -j32
    cd ..
    cd modules
    METHOD=opt make -j32
    cd ..
    cd ..
}

function build_boost() {
    cd $WORKDIR
    if [ -d "$WORKDIR/boost-1.79.0" ] ; then
       return
    fi

    git clone --recursive https://github.com/boostorg/boost
    cd boost
    git checkout boost-1.79.0
    ./bootstrap.sh --prefix=$WORKDIR/boost-1.79.0
    ./b2 --prefix=$WORKDIR/boost-1.79.0 install
    cd ..
    rm -rf boost
}

function build_eigen() {
  if [ -d "$WORKDIR/eigen" ] ; then
      export EIGEN3_DIR=$WORKDIR/eigen3
      return
  fi
  cd $WORKDIR
  git clone https://gitlab.com/libeigen/eigen.git
  cd eigen
  git checkout 3.3.0
  mkdir bld
  cd bld
  CC=$CC CXX=$CXX FC=$FC cmake .. -DCMAKE_INSTALL_PREFIX=$WORKDIR/eigen3
  make -j4
  make install
  cd ..
  export EIGEN3_DIR=$PWD
  cd ..
  rm -rf eigen
}


function build_precise() {
    cd $WORKDIR
    if [ -d "$WORKDIR/precise" ] ; then
       return
    fi

    ./build_boost 
    ./build_eigen3

    export PETSC_DIR=$WORKDIR/petsc
    export PETSC_ARCH="arch-moose"
	
    git clone https://github.com/precice/precice
    cd precise
    mkdir bld
    cd bld
    cmake .. -DBoost_INCLUDE_DIR=$WORKDIR/boost-1.79.0/include -DEIGEN3_INCLUDE_DIR=$WORKDIR/eigen3/include/eigen3

    make -j4
    make install
    cd ..
    cd ..
}

function build_vtk_git() {
    cd $WORKDIR
    if [ -d "$WORKDIR/vtk" ] ; then
       return
    fi
    git clone https://gitlab.kitware.com/vtk/vtk
    cd vtk
    git checkout v9.1.0
    mkdir bld
    cd bld
    CC=mpicc CXX=mpicxx cmake .. -DVTK_GROUP_ENABLE_MPI=YES -DVTK_USE_MPI=ON -DCMAKE_INSTALL_PREFIX=$WORKDIR/vtk
    make -j8 
    make install
    cd ..
    cd lib64
    # this is needed since moose expects to find libraries of the form libVTK.so
    # but this version of vtk provies libVTK-9.2.so and thus libmesh can't find vtk
    list=`ls | grep '\-9.1.so$'`
    for i in $list ; do
        renamed=`echo $i | sed -e s'/\-9.1//'g`
        ln -s $i $renamed
    done
   
    cd ..
    
}

function build_vtk_92() {
    cd $WORKDIR
    if [ -d "$WORKDIR/vtk" ] ; then
       return
    fi
    mkdir vtk
    cd vtk
    wget https://www.vtk.org/files/release/9.2/VTK-9.2.0.rc2.tar.gz
    tar -zxf VTK-9.2.0.rc2.tar.gz
    cd VTK-9.2.0.rc2
    mkdir bld
    cd bld
    CC=mpicc CXX=mpicxx cmake .. -DVTK_GROUP_ENABLE_MPI=YES -DVTK_USE_MPI=ON -DCMAKE_INSTALL_PREFIX=$WORKDIR/vtk
    make -j8 
    make install
    cd ..
    cd ..
    cd $WORKDIR/vtk/lib64
    # this is needed since moose expects to find libraries of the form libVTK.so
    # but this version of vtk provies libVTK-9.2.so and thus libmesh can't find vtk
    list=`ls | grep '\-9.2.so$'`
    for i in $list ; do
        renamed=`echo $i | sed -e s'/\-9.2//'g`
        ln -s $i $renamed
    done
}

function build_astrea() {
    cd $WORKDIR
    if [ -d "$WORKDIR/astrea" ] ; then
       return
    fi

    git clone https://github.com/aurora-multiphysics/astraea
    cd astrea
    cd ..
}

load_modules
build_moose
