# EXAMPLE CODE AS DEFINED IN NP PROTOCOL "Structural connectome construction
# using constrained spherical deconvolution in multi-shell diffusion-weighted
# magnetic resonance imaging" BY TAHEDL, M., TOURNIER, J.-D., AND SMITH, R.E., 2024
#
# This script only involves conversion of the example DICOM data
#   into a standardised naming convention & format
#   ready to be processed by the main section of the protocol;
#   this simplifies the process of executing the main protocol
#   on one's own data

if [ "$#" -ne 1 ]; then
    echo "Usage: prep_example_data.sh <directory>"
    exit 1
fi

###############################################################
# 1.PRE-PROTOCOL: PREPARE THE INPUT DATA
###############################################################

# Within the container,
#   the example DICOM data resides in fixed location /data/dicoms/,
#   and has known naming:
# data/
# └── dicoms/
#     ├── DWI_MSMT_102_AP/
#     ├── DWI_b0_PA/
#     └── T1w/

###############################################################
# 2. DEFINE ENVIRONMENT VARIABLES
###############################################################
# ACCESS THE RAW DATA AND OUTPUT PATH CONVENTIENTLY

DICOMDIR=/data/dicoms
OUTDIR=$1

###############################################################
# 3. Convert all images to an intermediate format
###############################################################

mrconvert ${DICOMDIR}/DWI_MSMT_102_AP/ ${OUTDIR}/dwi.mif
mrconvert ${DICOMDIR}/DWI_b0_PA/ ${OUTDIR}/b0_pa.mif
mrconvert ${DICOMDIR}/T1w/ ${OUTDIR}/T1w.mif
