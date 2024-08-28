# EXAMPLE CODE AS DEFINED IN NP PROTOCOL "Structural connectome construction
# using constrained spherical deconvolution in multi-shell diffusion-weighted
# magnetic resonance imaging" BY TAHEDL, M., TOURNIER, J.-D., AND SMITH, R.E., 2024

if [ "$#" -ne 2 ]; then
    echo "Usage: run_protocol.sh <raw_dir> <derivatives_dir>"
    exit 1
fi
set -e

RAWDIR=$1
DERIVDIR=$2

# It is assumed that within the input directory,
#   there will be three image files:
# raw/
# ├── dwi.mif
# ├── b0_pa.mif
# └── T1w.mif
# If an individual's data conform to this style of acquisition,
#   then they may be able to store their data according to this naming convention,
#   and execute the protocol on their data without modification.
# The output directory should be empty at commencement;
#   conflicts between existing files and new outputs are not handled.
if [ ! -f ${RAWDIR}/dwi.mif -o \
     ! -f ${RAWDIR}/b0_pa.mif -o \
     ! -f ${RAWDIR}/T1w.mif ]; then
    echo "Requisite raw input data not found at location \"${RAWDIR}\""
    exit 1
fi

###############################################################
# 2. DEFINE ENVIRONMENT VARIABLES
###############################################################
# ACCESS THE INPUT DATA CONVENTIENTLY
# ALSO CREATE A SUBJECT-ID FOR FREESURFER PROCESSING, E.G. "subject_00"

SUBJECTID="subject_00"
#source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
#source ${FSLDIR}/etc/fslconf/fsl.sh

###############################################################
# 3. CONVERT T1W IMAGE TO NIFTI FORMAT
###############################################################

mrconvert ${RAWDIR}/T1w.mif ${DERIVDIR}/T1w.nii

###############################################################
# 4. RUN FREESURFER
###############################################################

recon-all -s ${SUBJECTID} -i ${DERIVDIR}/T1w.nii -all -openmp 4
cp -r ${SUBJECTS_DIR}/${SUBJECTID} ${DERIVDIR}/freesurfer

###############################################################
# 5. PREPROCESSING I: DENOISE
###############################################################

dwidenoise ${RAWDIR}/dwi.mif ${DERIVDIR}/dwi_den.mif \
-noise ${DERIVDIR}/noise.mif

###############################################################
# 6. PREPROCESSING II: GIBB'S UNRINGING
###############################################################

mrdegibbs ${DERIVDIR}/dwi_den.mif ${DERIVDIR}/dwi_den_unr.mif


###############################################################
# 7. PREPROCESSING III: MOTION/DISTORTION CORRECTION
###############################################################

# Produce the image data to be used for susceptibility field estimation
dwiextract ${DERIVDIR}/dwi_den_unr.mif -bzero - | \
mrconvert - -coord 3 0 - | \
mrcat - ${DERIVDIR}/b0_pa.mif -axis 3 ${DERIVDIR}/b0s_paired.mif

# Perform image geometric distortion corrections making use of these data
dwifslpreproc ${DERIVDIR}/dwi_den_unr.mif ${DERIVDIR}/dwi_den_unr_preproc.mif \
-pe_dir AP -rpe_pair \
-se_epi ${DERIVDIR}/b0s_paired.mif \
-eddy_options " --repol"

###############################################################
# 8. PREPROCESSING IV: BIAS FIELD CORRECTION
###############################################################

dwibiascorrect ants ${DERIVDIR}/dwi_den_unr_preproc.mif ${DERIVDIR}/dwi_den_unr_preproc_unb.mif \
-bias ${DERIVDIR}/bias.mif

###############################################################
# 9. PREPROCESSING V: COREGISTRATION
###############################################################

# Extract b=0 volumes and calculate the mean.
# Export to NIFTI format for compatibility with FSL.
dwiextract ${DERIVDIR}/dwi_den_unr_preproc_unb.mif - -bzero | \
mrmath - mean ${DERIVDIR}/mean_b0_preproc.nii -axis 3

# Correct for bias field in T1w image:
N4BiasFieldCorrection -d 3 -i ${DERIVDIR}/T1w.nii -s 2 -o ${DERIVDIR}/T1w_bc.nii

# Perform linear registration with 6 degrees of freedom:
flirt -in ${DERIVDIR}/mean_b0_preproc.nii -ref ${DERIVDIR}/T1w_bc.nii \
-dof 6 -cost normmi \
-omat ${DERIVDIR}/diff2struct_fsl.mat

# Convert the resulting linear transformation matrix from FSL to MRtrix format:
transformconvert ${DERIVDIR}/diff2struct_fsl.mat ${DERIVDIR}/mean_b0_preproc.nii \
${DERIVDIR}/T1w_bc.nii flirt_import ${DERIVDIR}/diff2struct_mrtrix.txt

# Apply linear transformation to header of diffusion-weighted image:
mrtransform ${DERIVDIR}/dwi_den_unr_preproc_unb.mif ${DERIVDIR}/dwi_den_unr_preproc_unb_coreg.mif \
-linear ${DERIVDIR}/diff2struct_mrtrix.txt \

###############################################################
# 10. PREPROCESSING VI: BRAIN MASK ESTIMATION
###############################################################

dwi2mask ${DERIVDIR}/dwi_den_unr_preproc_unb_coreg.mif ${DERIVDIR}/dwi_mask.mif

###############################################################
# 11. LOCAL FOD ESTIMATION I: RESPONSE FUNCTION ESTIMATION
###############################################################

dwi2response dhollander ${DERIVDIR}/dwi_den_unr_preproc_unb_coreg.mif \
${DERIVDIR}/wm.txt ${DERIVDIR}/gm.txt ${DERIVDIR}/csf.txt \
-voxels ${DERIVDIR}/voxels.mif

###############################################################
# 12. LOCAL FOD ESTIMATION II: ODF ESTIMATION
###############################################################

dwi2fod msmt_csd ${DERIVDIR}/dwi_den_unr_preproc_unb_coreg.mif \
-mask ${DERIVDIR}/dwi_mask.mif \
${DERIVDIR}/wm.txt ${DERIVDIR}/wmfod.mif \
${DERIVDIR}/gm.txt ${DERIVDIR}/gm.mif \
${DERIVDIR}/csf.txt ${DERIVDIR}/csf.mif

###############################################################
# 13. LOCAL FOD ESTIMATION III: NORMALIZATION
###############################################################

mtnormalise -mask ${DERIVDIR}/dwi_mask.mif \
${DERIVDIR}/wmfod.mif ${DERIVDIR}/wmfod_norm.mif \
${DERIVDIR}/gm.mif ${DERIVDIR}/gm_norm.mif \
${DERIVDIR}/csf.mif ${DERIVDIR}/csf_norm.mif \
-check_factors ${DERIVDIR}/check_factors.txt \
-check_norm ${DERIVDIR}/check_norm.mif \
-check_mask ${DERIVDIR}/check_mask.mif

###############################################################
# 14. CREATE WHOLE-BRAIN TRACTOGRAM I: ACT SEGMENTATION
###############################################################

# Input to the command is the FreeSurfer subject directory.
# The version of the FreeSurfer subject directory
#   that has already been duplicated in the output directory
#   is used here as it simplifies resumption of partially
#   completed executions
5ttgen hsvs ${DERIVDIR}/freesurfer ${DERIVDIR}/5tt.mif

###############################################################
# 15. CREATE WHOLE-BRAIN TRACTOGRAM II: STREAMLINE GENERATION
###############################################################

tckgen ${DERIVDIR}/wmfod_norm.mif ${DERIVDIR}/tracks_10m.tck \
-algorithm ifod2 -select 10m \
-act ${DERIVDIR}/5tt.mif -backtrack \
-seed_dynamic ${DERIVDIR}/wmfod_norm.mif

###############################################################
# 16. TRACTOGRAM OPTIMIZATION: SIFT2 FILTERING
###############################################################

tcksift2 ${DERIVDIR}/tracks_10m.tck ${DERIVDIR}/wmfod_norm.mif ${DERIVDIR}/sift2_weights.txt \
-act ${DERIVDIR}/5tt.mif \
-out_mu ${DERIVDIR}/sift2_mu.txt

###############################################################
# 17. SC MATRIX GENERATION I: CONVERT PARCELLATION IMAGE
###############################################################

labelconvert ${DERIVDIR}/freesurfer/mri/aparc+aseg.mgz \
${FREESURFER_HOME}/FreeSurferColorLUT.txt \
/opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt \
${DERIVDIR}/DK_parcels.mif

###############################################################
# 18. SC MATRIX GENERATION II: CREATE MATRIX
###############################################################
tck2connectome ${DERIVDIR}/tracks_10m.tck ${DERIVDIR}/DK_parcels.mif ${DERIVDIR}/dk.csv \
-symmetric -zero_diagonal \
-tck_weights_in ${DERIVDIR}/sift2_weights.txt \
-out_assignments ${DERIVDIR}/dk_assignments.txt
