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
        python3.10 \
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
COPY acpcdetect_V2.2_Linux_x86_64_Ubuntu_22.04.01.tar.gz /opt/art/acpcdetect_V2.2_Linux_x86_64_Ubuntu_22.04.01.tar.gz
RUN tar -xf acpcdetect_V2.2_Linux_x86_64_Ubuntu_22.04.01.tar.gz \
    && rm acpcdetect_V2.2_Linux_x86_64_Ubuntu_22.04.01.tar.gz

# Install ANTs
FROM base-builder AS ants-installer
ARG MAKE_JOBS
WORKDIR /opt/ants
RUN wget https://github.com/ANTsX/ANTs/releases/download/v2.5.3/ants-2.5.3-ubuntu-22.04-X64-gcc.zip \
    && unzip ants-2.5.3-ubuntu-22.04-X64-gcc.zip \
    && mv ants-2.5.3/bin ants-2.5.3/lib . \
    && rmdir ants-2.5.3 \
    && rm ants-2.5.3-ubuntu-22.04-X64-gcc.zip

# Install FreeSurfer
FROM base-builder AS freesurfer-installer
WORKDIR /opt/freesurfer
RUN wget -qO- https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.4.1/freesurfer-linux-ubuntu22_amd64-7.4.1.tar.gz \
    | tar xz --strip-components 2 \
    && FREESURFER_HOME=/opt/freesurfer bash /opt/freesurfer/SetUpFreeSurfer.sh

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
        python3.10 \
        sudo \
        wget \
    && rm -rf /var/lib/apt/lists/*
RUN wget https://fsl.fmrib.ox.ac.uk/fsldownloads/fslinstaller.py \
    && python3 fslinstaller.py -V 6.0.7.7 -d /opt/fsl -m -o \
    && FSLDIR=/opt/fsl bash /opt/fsl/etc/fslconf/fsl.sh

# Builder that downloads the example data
FROM base-builder AS data-downloader
WORKDIR /data
#RUN curl https://files.osf.io/v1/resources/tm5x8/providers/osfstorage/66a8d1299a807f4eea9b4025/?zip= --output dicoms.zip \
#    && unzip dicoms.zip -d dicoms \
#    && rm dicoms.zip \
#    && curl https://files.osf.io/v1/resources/tm5x8/providers/osfstorage/66a8d136a93f4dc90451a344/?zip= --output derivatives.zip \
#    && unzip derivatives.zip -d derivatives \
#    && rm derivatives.zip
COPY dicoms.zip derivatives.zip ./
RUN unzip dicoms.zip -d dicoms \
    && rm dicoms.zip \
    && unzip derivatives.zip -d derivatives \
    && rm derivatives.zip



FROM base AS final

RUN apt-get -qq update \
    && apt-get install -yq --no-install-recommends \
        bc \
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
        python3.10 \
        python3.10-distutils \
        tcsh \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mrtrix3-builder /opt/mrtrix3 /opt/mrtrix3
COPY --from=acpcdetect-installer /opt/art /opt/art
COPY --from=ants-installer /opt/ants /opt/ants
COPY --from=fsl-installer /opt/fsl /opt/fsl
COPY --from=freesurfer-installer /opt/freesurfer /opt/freesurfer
COPY --from=data-downloader /data /data

COPY prep_example_data.sh /
COPY run_protocol.sh /

RUN ln -s /usr/bin/python3 /usr/bin/python

WORKDIR /

ENV ANTSPATH=/opt/ants/bin \
    ARTHOME=/opt/art \
    FIX_VERTEX_AREA= \
    FMRI_ANALYSIS_DIR=/opt/freesurfer/fsfast \
    FREESURFER=/opt/freesurfer \
    FREESURFER_HOME=/opt/freesurfer \
    FSFAST_HOME=/opt/freesurfer/fsfast \
    FSF_OUTPUT_FORMAT=.nii \
    FSLDIR=/opt/fsl \
    FSLGECUDAQ=cuda.q \
    FSLMULTIFILEQUIT=TRUE \
    FSLOUTPUTTYPE=NIFTI \
    FSLTCLSH=/opt/fsl/bin/fsltclsh \
    FSLWISH=/opt/fsl/bin/fslwish \
    FSL_BIN=/opt/fsl/bin \
    FSL_DIR=/opt/fsl \
    FSL_LOAD_NIFTI_EXTENSIONS=0 \
    FSL_SKIP_GLOBAL=0 \
    FS_OVERRIDE=0 \
    FUNCTIONALS_DIR=/opt/freesurfer/sessions \
    LOCAL_DIR=/opt/freesurfer/local \
    LD_LIBRARY_PATH="/opt/ants/lib" \
    MINC_BIN_DIR=/opt/freesurfer/mni/bin \
    MINC_LIB_DIR=/opt/freesurfer/mni/lib \
    MNI_DATAPATH=/opt/freesurfer/mni/data \
    MNI_DIR=/opt/freesurfer/mni \
    MNI_PERL5LIB=/opt/freesurfer/mni/share/perl5 \
    OS=Linux \
    PATH="/opt/mrtrix3/bin:/opt/ants/bin:/opt/art/bin:/opt/freesurfer/bin:/opt/freesurfer/fsfast/bin:/opt/freesurfer/mni/bin:/opt/freesurfer/tktools:/opt/fsl/share/fsl/bin:$PATH" \
    PERL5LIB=/opt/freesurfer/mni/share/perl5 \
    SUBJECTS_DIR=/opt/freesurfer/subjects

ENTRYPOINT ["/bin/bash"]

