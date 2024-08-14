# EXAMPLE CODE AS DEFINED IN NP PROTOCOL "Structural connectome construction
# using constrained spherical deconvolution in multi-shell diffusion-weighted
# magnetic resonance imaging" BY TAHEDL, M., TOURNIER, J.-D., AND SMITH, R.E., 2024

if [ "$#" -ne 2 ]; then
    echo "Usage: run_protocol.sh <data_dir> <output_dir>"
    exit 1
fi
set -e

# It is assumed that within the input directory,
#   there will be three image files:
# data_dir/
#     ├── dwi.mif
#     ├── b0_pa.mif
#     └── T1w.mif
# If an individual's data conform to this style of acquisition,
#   then they may be able to store their data according to this naming convention,
#   and execute the protocol on their data without modification.
# The output directory should be empty at commencement;
#   conflicts between existing files and new outputs are not handled.

###############################################################
# 2. DEFINE ENVIRONMENT VARIABLES
###############################################################
# ACCESS THE INPUT DATA CONVENTIENTLY
# ALSO CREATE A SUBJECT-ID FOR FREESURFER PROCESSING, E.G. "subject_00"

DATADIR=$1
OUTDIR=$2
SUBJECTID="subject_00"
#source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
#source ${FSLDIR}/etc/fslconf/fsl.sh

###############################################################
# 3. CONVERT T1W IMAGE TO NIFTI FORMAT
###############################################################

mrconvert ${DATADIR}/T1w.mif ${OUTDIR}/T1w.nii.gz

###############################################################
# 4. RUN FREESURFER
###############################################################

recon-all -s ${SUBJECTID} -i ${OUTDIR}/T1w.nii.gz -all
cp -r ${SUBJECTS_DIR}/${SUBJECTID} ${OUTDIR}/freesurfer

###############################################################
# 5. PREPROCESSING I: DENOISE
###############################################################

dwidenoise ${DATADIR}/dwi.mif ${OUTDIR}/dwi_den.mif \
-noise ${OUTDIR}/noise.mif

###############################################################
# 6. PREPROCESSING II: GIBB'S UNRINGING
###############################################################

mrdegibbs ${OUTDIR}/dwi_den.mif ${OUTDIR}/dwi_den_unr.mif

###############################################################
# 7. PREPROCESSING III: MOTION/DISTORTION CORRECTION
###############################################################

# Produce the image data to be used for susceptibility field estimation
dwiextract ${OUTDIR}/dwi_den_unr.mif -bzero - | \
mrconvert - -coord 3 0 - | \
mrcat - ${DATADIR}/b0_pa.mif -axis 3 ${OUTDIR}/b0s_paired.mif

# Perform image geometric distortion corrections making use of these data
dwifslpreproc ${OUTDIR}/dwi_den_unr.mif ${OUTDIR}/dwi_den_unr_preproc.mif \
-pe_dir AP -rpe_pair \
-se_epi ${OUTDIR}/b0s_paired.mif \
-eddy_options " --repol"

###############################################################
# 8. PREPROCESSING IV: BIAS FIELD CORRECTION
###############################################################

dwibiascorrect ants ${OUTDIR}/dwi_den_unr_preproc.mif ${OUTDIR}/dwi_den_unr_preproc_unb.mif \
-bias ${OUTDIR}/bias.mif

###############################################################
# 9. PREPROCESSING V: COREGISTRATION
###############################################################

# Extract b=0 volumes and calculate the mean.
# Export to NIFTI format for compatibility with FSL.
dwiextract ${OUTDIR}/dwi_den_unr_preproc_unb.mif - -bzero | \
mrmath - mean ${OUTDIR}/mean_b0_preproc.nii.gz -axis 3

# Correct for bias field in T1w image:

N4BiasFieldCorrection -d 3 -i ${OUTDIR}T1w.nii.gz -s 2 -o ${OUTDIR}/T1w_bc.nii.gz

# Perform linear registration with 6 degrees of freedom:
flirt -in ${OUTDIR}/mean_b0_preproc.nii.gz -ref ${OUTDIR}/T1w_bc.nii.gz \
-dof 6 -cost normmi \
-omat ${OUTDIR}/diff2struct_fsl.mat

# Convert the resulting linear transformation matrix from FSL to MRtrix format:
transformconvert ${OUTDIR}/diff2struct_fsl.mat ${OUTDIR}/mean_b0_preproc.nii.gz \
${OUTDIR}/T1w_bc.nii.gz flirt_import ${OUTDIR}/diff2struct_mrtrix.txt

# Apply linear transformation to header of diffusion-weighted image:
mrtransform ${OUTDIR}/dwi_den_unr_preproc_unb.mif ${OUTDIR}/dwi_den_unr_preproc_unb_coreg.mif
-linear ${OUTDIR}/diff2struct_mrtrix.txt \

###############################################################
# 10. PREPROCESSING VI: BRAIN MASK ESTIMATION
###############################################################

dwi2mask ${OUTDIR}/dwi_den_unr_preproc_unb_coreg.mif ${OUTDIR}/dwi_mask.mif

###############################################################
# 11. LOCAL FOD ESTIMATION I: RESPONSE FUNCTION ESTIMATION
###############################################################

dwi2response dhollander ${OUTDIR}/dwi_den_unr_preproc_unb_coreg.mif \
${OUTDIR}/wm.txt ${OUTDIR}/gm.txt ${OUTDIR}/csf.txt \
-voxels ${OUTDIR}/voxels.mif

###############################################################
# 12. LOCAL FOD ESTIMATION II: ODF ESTIMATION
###############################################################

dwi2fod msmt_csd ${OUTDIR}/dwi_den_unr_preproc_unb_coreg.mif \
-mask ${OUTDIR}/dwi_mask.mif \
${OUTDIR}/wm.txt ${OUTDIR}/wmfod.mif \
${OUTDIR}/gm.txt ${OUTDIR}/gm.mif \
${OUTDIR}/csf.txt ${OUTDIR}/csf.mif

###############################################################
# 13. LOCAL FOD ESTIMATION III: NORMALIZATION
###############################################################

mtnormalise -mask ${OUTDIR}/dwi_mask.mif \
${OUTDIR}/wmfod.mif ${OUTDIR}/wmfod_norm.mif \
${OUTDIR}/gm.mif ${OUTDIR}/gm_norm.mif \
${OUTDIR}/csf.mif ${OUTDIR}/csf_norm.mif \
-check_factors ${OUTDIR}/check_factors.txt \
-check_norm ${OUTDIR}/check_norm.mif \
-check_mask ${OUTDIR}/check_mask.mif

###############################################################
# 14. CREATE WHOLE-BRAIN TRACTOGRAM I: ACT SEGMENTATION
###############################################################

# Input to the command is the FreeSurfer subject directory.
# If FreeSurfer has been set up correctly, environment variable
# SUBJECTS_DIR is set during FreeSurfer configuration.
# Environment variable SUBJECTID was set in step 2.
5ttgen hsvs ${SUBJECTS_DIR}/${SUBJECTID} ${OUTDIR}/5tt.mif

###############################################################
# 15. CREATE WHOLE-BRAIN TRACTOGRAM II: STREAMLINE GENERATION
###############################################################

tckgen ${OUTDIR}/wmfod_norm.mif ${OUTDIR}/tracks_10m.tck
-algorithm ifod2 -select 10m \
-act ${OUTDIR}/5tt.mif -backtrack \
-seed_dynamic ${OUTDIR}/wmfod_norm.mif

###############################################################
# 16. TRACTOGRAM OPTIMIZATION: SIFT2 FILTERING
###############################################################

tcksift2 ${OUTDIR}/tracks_10m.tck ${OUTDIR}/wmfod_norm.mif sift2_weights.txt \
-act ${OUTDIR}/5tt.mif \
-out_mu ${OUTDIR}/sift2_mu.txt

###############################################################
# 17. SC MATRIX GENERATION I: CONVERT PARCELLATION IMAGE
###############################################################

labelconvert ${SUBJECTS_DIR}/${SUBJECTID}/mri/aparc+aseg.mgz \
${FREESURFER_HOME}/FreeSurferColorLUT.txt \
/opt/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt ${OUTDIR}/DK_parcels.mif

###############################################################
# 18. SC MATRIX GENERATION II: CREATE MATRIX
###############################################################
tck2connectome ${OUTDIR}/tracks_10m.tck ${OUTDIR}/DK_parcels.mif ${OUTDIR}/dk.csv \
-symmetric -zero_diagonal \
-tck_weights_in ${OUTDIR}/sift2_weights.txt
