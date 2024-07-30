ARG MAKE_JOBS="1"
ARG DEBIAN_FRONTEND="noninteractive"

FROM ubuntu:jammy AS base
FROM buildpack-deps:jammy AS base-builder

FROM base-builder AS mrtrix3-builder
# Git commitish from which to build MRtrix3.
ARG MRTRIX3_GIT_COMMITISH="3.0.4"
# Command-line arguments for MRtrix3 `./configure`
ARG MRTRIX3_CONFIGURE_FLAGS=""
# Command-line arguments for MRtrix3 `./build`
ARG MRTRIX3_BUILD_FLAGS="-persistent -nopaginate"
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        libeigen3-dev \
        libfftw3-dev \
        libqt5opengl5-dev \
        libqt5svg5-dev \
        libpng-dev \
        libtiff5-dev \
        qtbase5-dev \
        qt5-qmake \
        python3 \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*
# Clone, build, and install MRtrix3.
ARG MAKE_JOBS
WORKDIR /opt/mrtrix3
RUN git clone -b ${MRTRIX3_GIT_COMMITISH} --depth 1 https://github.com/MRtrix3/mrtrix3.git . \
    && python3 ./configure $MRTRIX3_CONFIGURE_FLAGS \
    && NUMBER_OF_PROCESSORS=$MAKE_JOBS python3 ./build $MRTRIX3_BUILD_FLAGS \
    && rm -rf testing/ tmp/

# Install ART ACPCdetect.
FROM base-builder AS acpcdetect-installer
WORKDIR /opt/art
COPY acpcdetect_V2.1_LinuxCentOS6.7.tar.gz /opt/art/acpcdetect_V2.1_LinuxCentOS6.7.tar.gz
RUN tar -xf acpcdetect_V2.1_LinuxCentOS6.7.tar.gz

# Install ANTs
FROM base-builder AS ants-installer
ARG MAKE_JOBS
WORKDIR /opt/ants
RUN wget https://github.com/ANTsX/ANTs/releases/download/v2.5.3/ants-2.5.3-ubuntu-22.04-X64-gcc.zip
RUN unzip ants-2.5.3-ubuntu-22.04-X64-gcc.zip \
    && rm ants-2.5.3-ubuntu-22.04-X64-gcc.zip

# Install FreeSurfer
FROM base-builder AS freesurfer-installer
WORKDIR /opt/freesurfer
RUN wget -O- https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.4.1/freesurfer-linux-ubuntu22_amd64-7.4.1.tar.gz \
    | tar xz --strip-components 1

# Install FSL
FROM base-builder AS fsl-installer
WORKDIR /src/fsl
RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bc \
        dc \
        file \
        libfontconfig1 \
        libfreetype6 \
        libgl1-mesa-dev \
        libgl1-mesa-dri \
        libglu1-mesa-dev \
        libgomp1 \
        libice6 \
        libopenblas0 \
        libxcursor1 \
        libxft2 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        libxt6 \
        python3 \
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/*
RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py \
    && python3 fslinstaller.py -V 6.0.7.7 -d /opt/fsl -m -o

# Builder that downloads the BATMAN data
FROM base-builder AS data-downloader
WORKDIR /data
RUN curl https://files.osf.io/v1/resources/fkyht/providers/osfstorage/5bab77d6d40256001a28f7db/?zip= --output data.zip \
    && unzip data.zip \
    && rm data.zip
    



FROM base AS final

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bzip2 \
        ca-certificates \
        curl \
        dc \
        libfftw3-single3 \
        libfftw3-double3 \
        libgomp1 \
        liblapack3 \
        libpng16-16 \
        libquadmath0 \
        libtiff5-dev \
        qtbase5-dev \
        pigz \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3
COPY --from=acpcdetect-installer /opt/art /opt/art
COPY --from=ants-installer /opt/ants /opt/ants
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer
COPY --from=data-downloader /data /data

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /

ENV ANTSPATH=/opt/ants/bin \
    ARTHOME=/opt/art \
    FREESURFER_HOME=/opt/freesurfer \
    FSLDIR=/opt/fsl \
    FSLOUTPUTTYPE=NIFTI_GZ \
    FSLMULTIFILEQUIT=TRUE \
    FSLTCLSH=/opt/fsl/bin/fsltclsh \
    FSLWISH=/opt/fsl/bin/fslwish \
    LD_LIBRARY_PATH="/opt/ants/lib" \
    PATH="/opt/mrtrix3/bin:/opt/ants/bin:/opt/art/bin:/opt/fsl/share/fsl/bin:$PATH"

ENTRYPOINT ["/bin/bash"]

