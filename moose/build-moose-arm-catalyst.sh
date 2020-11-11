#!/bin/bash
set -ue

export STACK_SRC=`mktemp -d /tmp/moose_stack_src.XXXXXX`
export WORKDIR=/home/$USER/moose_dev

function _build_mpich33() {
    module purge
    module load Generic-AArch64/SUSE/12/gcc/8.2.0 

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
    module purge
    module load Generic-AArch64/SUSE/12/gcc/8.2.0
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
    --with-mpi-dir=$WORKDIR/mpich-3.3 \
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
    module purge
    module load Generic-AArch64/SUSE/12/gcc/8.2.0 python/gcc-8.2/3.7.4
    cd $WORKDIR
    if [ -d "$WORKDIR/moose" ] ; then
       return
    fi
    _build_mpich33
    _build_petsc
    git clone https://github.com/idaholab/moose
    cd moose
    git checkout master
    export PETSC_DIR=$WORKDIR/petsc
    export CC=mpicc
    export CXX=mpicxx
    export F90=mpif90
    export F77=mpif77
    export FC=mpif90
    ./scripts/update_and_rebuild_libmesh.sh --with-mpi
    cd test
    make -j 4
    ./run_tests -j 4
    cd ..
    cd framework
    ./configure --with-derivative-size=200 --with-ad-indexing-type=global
    make -j4
    cd ..
    cd modules
    make -j 4
    cd ..
    cd ..
}

build_moose
