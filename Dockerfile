# Use the Ubuntu 22 as the base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    MPICH_VERSION=4.1.2 \
    EIGEN_VERSION=3.4.0 \
    GMSH_VERSION=4_11_1 \
    MPI_PATH=/app/bin/mpi \
    PETSC_PATH=/app/bin/petsc

# Update system packages, install dependencies
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
    git gcc g++ gfortran make wget python3 python3-pip pkg-config cmake gdb \
    libblas-dev liblapack-dev liblapacke-dev libopenmpi-dev openmpi-bin openssh-client \
    flex bison libocct-foundation-dev libocct-data-exchange-dev libfltk1.3-dev \
    libjpeg-dev libgmp-dev libhdf5-dev xorg xauth python3-tk sudo && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

# Install Python libraries
RUN pip3 install --no-cache-dir \
    numpy==1.26.0 matplotlib==3.5.0 plotly cython setuptools pandas seaborn gmsh pyiges[full] isort black autoflake8 vtk \
    git+https://github.com/rosicley/NURBS-Python.git

# Install MPICH
WORKDIR /app
RUN wget --no-verbose https://github.com/pmodels/mpich/releases/download/v${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz && \
    tar xzf mpich-${MPICH_VERSION}.tar.gz && \
    cd mpich-${MPICH_VERSION} && \
    ./configure --prefix=${MPI_PATH} --with-device=ch4:ofi 2>&1 | tee c.txt && \
    make 2>&1 | tee m.txt && \
    make install 2>&1 | tee mi.txt && \
    which mpicc && \
    which mpicxx && \
    which mpiexec && \
    cd .. && \
    rm -rf mpich-${MPICH_VERSION}.tar.gz mpich-${MPICH_VERSION}
ENV PATH ${MPI_PATH}/bin:$PATH

# Install Petsc
RUN git clone -b release https://gitlab.com/petsc/petsc.git ${PETSC_PATH} && \
    cd ${PETSC_PATH} && \
    ./configure PETSC_ARCH=arch-linux2-c-opt --with-mpi-dir=${MPI_PATH} --with-cxx-dialect=C++11 --with-debugging=0 --with-X=1 COPTFLAGS='-O3 -march=native -mtune=native' CXXOPTFLAGS='-O3 -march=native -mtune=native' FOPTFLAGS='-O3 -march=native -mtune=native' --download-metis --download-parmetis --download-mumps --download-scalapack --download-ptscotch --download-fblaslapack --download-hdf5 && \
    make PETSC_DIR=${PETSC_PATH} PETSC_ARCH=arch-linux2-c-opt all && \
    make PETSC_DIR=${PETSC_PATH} PETSC_ARCH=arch-linux2-c-opt check && \
    ./configure PETSC_ARCH=arch-linux2-c-debug --with-mpi-dir=${MPI_PATH} --with-cxx-dialect=C++11 --with-debugging=1 --with-X=1 --download-metis --download-parmetis --download-mumps --download-scalapack --download-ptscotch --download-fblaslapack --download-hdf5 && \
    make PETSC_DIR=${PETSC_PATH} PETSC_ARCH=arch-linux2-c-debug all && \
    make PETSC_DIR=${PETSC_PATH} PETSC_ARCH=arch-linux2-c-debug check
ENV PETSC_DIR ${PETSC_PATH}

# Install gmsh from source
WORKDIR /app
RUN git clone -b fix/fix_crack_plugin https://github.com/rosicley/gmsh.git && \
    cd gmsh && \
    mkdir build && \
    cd build && \
    cmake -DENABLE_BUILD_DYNAMIC=1 .. && \
    make && \
    make install && \
    cd ../.. && \
    rm -rf gmsh

# Install fmt from source
WORKDIR /app
RUN git clone https://github.com/fmtlib/fmt.git && \
    cd fmt && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    make test && \
    cd ../.. && \
    rm -rf fmt

# Install libeigen from source
WORKDIR /app
RUN wget --no-verbose https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VERSION}/eigen-${EIGEN_VERSION}.tar.gz && \
    tar xzf eigen-${EIGEN_VERSION}.tar.gz && \
    cd eigen-${EIGEN_VERSION} && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    cd ../.. && \
    rm -rf eigen-${EIGEN_VERSION}.tar.gz eigen-${EIGEN_VERSION}

# Copy files
COPY . /app/3dSolid
WORKDIR /app/3dSolid

# Create a new user and switch to that user
RUN groupadd -g 1000 3dSolid && \
    useradd -u 1000 -g 1000 -ms /bin/bash 3dSolid && \
    echo "3dSolid ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/3dSolid

USER 3dSolid
