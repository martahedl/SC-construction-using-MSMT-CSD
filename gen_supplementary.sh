# EXAMPLE CODE AS DEFINED IN SUPPLEMENTARY MATERIAL OF NP PROTOCOL
# "Structural connectome construction using constrained spherical deconvolution
# in multi-shell diffusion-weighted magnetic resonance imaging"
# BY TAHEDL, M., TOURNIER, J.-D., AND SMITH, R.E., 2024

if [ "$#" -ne 3 ]; then
    echo "Usage: gen_supplementary.sh <raw_dir> <derivatives_dir> <supplementary_dir>"
    exit 1
fi
set -e

RAWDIR=$1
DERIVDIR=$2
SUPPDIR=$3

if [ ! -f ${RAWDIR}/dwi.mif ]; then
    echo "Requisite raw input data not found in location \"${INDIR}\""
    exit 1
fi

if [ ! -f ${DERIVDIR}/bias.mif ]; then
    echo "Requisite derivative data not found in location \"${DERIVDIR}\""
    exit 1
fi

# It is assumed that within the specified directory,
#   all files produced by script "run_protocol.sh"
#   have already been generated.
# Note that this includes the full 10 million streamlines tractogram,
#   named "tracks_10m.tck",
#   which is not included in the OSF derivatives download.
# Therefore this script can only be run if the protocol
#   has been executed locally.
if [ ! -f ${DERIVDIR}/tracks_10m.tck ]; then
    echo "Full tractogram not present in output directory;"
    echo "this script cannot be run on the provided example data"
    echo "as these data are too large to share online."
    echo "it is necessary to run the complete protocol locally"
    echo "using the \"run_protocol.sh\" script"
    echo "before the supplementary material can be reproduced."
    exit 1
fi

###############################################################
# S1. Signal-to-noise ratio assessment
###############################################################

dwiextract -bzero ${RAWDIR}/dwi.mif ${SUPPDIR}/b0s.mif

mrmath ${SUPPDIR}/b0s.mif -axis 3 mean ${SUPPDIR}/mean_b0.mif

mrmath ${SUPPDIR}/b0s.mif -axis 3 std ${SUPPDIR}/std_b0.mif

mrcalc ${SUPPDIR}/mean_b0.mif ${SUPPDIR}/std_b0.mif -div - | \
mrfilter - median ${SUPPDIR}/SNR.mif

###############################################################
# S3. VISUAL INSPECTION OF BIAS FIELD CORRECTION
###############################################################

mrcalc ${DERIVDIR}/bias.mif -log ${SUPPDIR}/bias_log.mif

###############################################################
# S8. VISUAL INSPECTION OF MULTI-TISSUE DECOMPOSITION
#    AND FIBRE ORIENTATION DISTRIBUTION
###############################################################

mrconvert -coord 3 0 ${DERIVDIR}/wmfod.mif - | \
mrcat ${DERIVDIR}/csf.mif ${DERIVDIR}/gm.mif - ${SUPPDIR}/mtd.mif -axis 3

###############################################################
# S9. VISUAL INSPECTION OF THE 5TT IMAGE
###############################################################

5tt2vis ${DERIVDIR}/5tt.mif ${SUPPDIR}/5tt_vis.mif

###############################################################
# S10. VISUAL INSPECTION OF THE GENERATED TRACTOGRAM
###############################################################

tckedit ${DERIVDIR}/tracks_10m.tck -number 200k ${SUPPDIR}/tracks_200k.tck

tckresample -endpoints ${SUPPDIR}/tracks_200k.tck ${SUPPDIR}/endpoints_200k.tck

###############################################################
# S11. VISUAL INSPECTION OF STREAMLINE FILTERING
###############################################################

tckmap -precise ${DERIVDIR}/tracks_10m.tck \
-template ${DERIVDIR}/mean_b0_preproc.nii ${SUPPDIR}/tck_density_nofiltering.mif

tckmap -precise -tck_weights_in ${DERIVDIR}/sift2_weights.txt \
${DERIVDIR}/tracks_10m.tck -template ${DERIVDIR}/mean_b0_preproc.nii \
${SUPPDIR}/tck_density_filtering.mif

###############################################################
# S12. GENERATING SC MATRICES BASED ON THE AAL ATLAS
###############################################################

fsl_anat --noseg --nosubcortseg \
-i ${DERIVDIR}/T1w.nii \
-o ${SUPPDIR}/T1w


applywarp --ref=${SUPPDIR}/T1w.anat/T1_biascorr_brain.nii.gz \
--in=${AALPATH}/ROI_MNI_V5.nii \
--warp=${SUPPDIR}/T1w.anat/MNI_to_T1_nonlin_field.nii.gz \
--out=${SUPPDIR}/aal_parcels_coreg.nii.gz \
--interp=nn

labelconvert ${SUPPDIR}/aal_parcels_coreg.nii.gz \
${AALPATH}/ROI_MNI_V5.txt \
${MRTRIXDIR}/share/mrtrix3/labelconvert/aal2.txt \
${SUPPDIR}/aal_parcels_coreg_converted.mif

tck2connectome -tck_weights_in ${DERIVDIR}/sift2_weights.txt \
-symmetric -zero_diagonal \
${DERIVDIR}/tracks_10m.tck ${SUPPDIR}/aal_parcels_coreg_converted.mif ${SUPPDIR}/aal.csv

###############################################################
# S13. FIBRE BUNDLE SEGMENTATION
###############################################################

connectome2tck ${DERIVDIR}/tracks_10m.tck ${DERIVDIR}/dk_assignments.txt \
${SUPPDIR}/transcallosal_m1.tck -nodes 23,72 -exclusive -files single
