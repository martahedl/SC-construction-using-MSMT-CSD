# EXAMPLE CODE AS DEFINED IN NP PROTOCOL "Structural connectome construction
# using constrained spherical deconvolution in multi-shell diffusion-weighted
# magnetic resonance imaging" BY TAHEDL, M., TOURNIER, J.-D., AND SMITH, R.E., 2024
# EXAMPLE CALL
# ./example_code_protocol.sh

###############################################################
# 1.PRE-PROTOCOL: PREPARE THE INPUT DATA
###############################################################

# DOWNLOAD THE DATA FROM THE OSF REPOSITORY: https://osf.io/fkyht/files/osfstorage
# >> DOWNLOAD THE ENTIRE "dicoms" DIRECOTRY, INCLUDING 3 SUBDIRECTORIES:
# >> DWI_b0_PA, DWI_MSMT_102_AP, T1w
# >> SAVE THE DOWNLOADED "dicoms" DIRECTORY IN A SUBJECT DIRECTORY, SUCH THAT THE
# FINAL DATA STRUCTURE LOOKS LIKE THIS:
# subject/
#└── dicoms/
#    ├── DWI_MSMT_102_AP/
#    ├── DWI_b0_PA/
#    └── T1w/

# DEFINE AN ENVIRONMENT VARIABLE

###############################################################
# 2. DEFINE AN ENVIRONMENT VARIABLES
###############################################################
# ACCESS THE RAW DATA CONVENTIENTLY
# ALSO CREATE A SUBJECT-ID FOR FREESURFER PROCESSING, E.G. "subject_00"

DICOMDIR=${HOME}/subject/dicoms
SUBJECTID="subject_00"

###############################################################
# 3. CONVERT T1W IMAGE TO NIFTI FORMAT
###############################################################

mrconvert ${DICOMDIR}/T1w/ T1w.nii.gz

###############################################################
# 4. RUN FREESURFER
###############################################################

recon-all -s ${SUBJECTID} -i T1w.nii.gz -all

###############################################################
# 5. PREPROCESSING I: DENOISE
###############################################################

dwidenoise ${DICOMDIR}/DWI_MSMT_102_AP/ dwi_den.mif -noise noise.mif

###############################################################
# 6. PREPROCESSING II: GIBB'S UNRINGING
###############################################################

mrdegibbs dwi_den.mif dwi_den_unr.mif

###############################################################
# 7. PREPROCESSING III: MOTION/DISTORTION CORRECTION
###############################################################

# Produce the image data to be used for susceptibility field estimation
dwiextract dwi_den_unr.mif -bzero - | \
mrconvert - -coord 3 0 - | \
mrcat - ${DICOMDIR}/DWI_b0_PA/ -axis 3 b0s_paired.mif

# Perform image geometric distortion corrections making use of these data
dwifslpreproc dwi_den_unr.mif dwi_den_unr_preproc.mif \
-pe_dir AP -rpe_pair -se_epi b0s_paired.mif -eddy_options " --repol"

###############################################################
# 8. PREPROCESSING IV: BIAS FIELD CORRECTION
###############################################################

dwibiascorrect ants dwi_den_unr_preproc.mif dwi_den_unr_preproc_unb.mif -bias bias.mif

###############################################################
# 9. PREPROCESSING V: COREGISTRATION
###############################################################

# Extract b=0 volumes and calculate the mean. Export to NIFTI format for compatibility with FSL.
dwiextract dwi_den_unr_preproc_unb.mif - -bzero | \
mrmath - mean mean_b0_preproc.nii.gz -axis 3

# Perform linear registration with 6 degrees of freedom:
flirt -in mean_b0_preproc.nii.gz -ref T1w.nii.gz \
-dof 6 -omat diff2struct_fsl.mat

# Convert the resulting linear transformation matrix from FSL to MRtrix format:
transformconvert diff2struct_fsl.mat mean_b0_preproc.nii.gz \
T1w.nii.gz flirt_import diff2struct_mrtrix.txt

# Apply linear transformation to header of diffusion-weighted image:
mrtransform dwi_den_unr_preproc_unb.mif -linear \
diff2struct_mrtrix.txt dwi_den_unr_preproc_unb_coreg.mif

###############################################################
# 10. PREPROCESSING VI: BRAIN MASK ESTIMATION
###############################################################

dwi2mask dwi_den_unr_preproc_unb_coreg.mif dwi_mask.mif

###############################################################
# 11. LOCAL FOD ESTIMATION I: RESPONSE FUNCTION ESTIMATION
###############################################################

dwi2response dhollander dwi_den_unr_preproc_unb_coreg.mif \
wm.txt gm.txt csf.txt -voxels voxels.mif

###############################################################
# 12. LOCAL FOD ESTIMATION II: ODF ESTIMATION
###############################################################

dwi2fod msmt_csd dwi_den_unr_preproc_unb_coreg.mif \
-mask dwi_mask.mif wm.txt wmfod.mif gm.txt gm.mif csf.txt csf.mif

###############################################################
# 13. LOCAL FOD ESTIMATION III: NORMALIZATION
###############################################################

mtnormalise wmfod.mif wmfod_norm.mif gm.mif gm_norm.mif \
csf.mif csf_norm.mif -mask dwi_mask.mif \
-check_factors check_factors.txt -check_norm check_norm.mif -check_mask check_mask.mif

###############################################################
# 14. CREATE WHOLE-BRAIN TRACTOGRAM I: ACT SEGMENTATION
###############################################################

# Input to the command is the FreeSurfer subject directory.
# If FreeSurfer has been set up correctly, environment variable
# SUBJECTS_DIR is set during FreeSurfer configuration.
# Environment variable SUBJECTID was set in step 2.
5ttgen hsvs ${SUBJECTS_DIR}/${SUBJECTID} 5tt.mif

###############################################################
# 15. CREATE WHOLE-BRAIN TRACTOGRAM II: STREAMLINE GENERATION
###############################################################

tckgen -algorithm ifod2 -act 5tt.mif -backtrack -seed_dynamic \
wmfod_norm.mif -select 10m wmfod_norm.mif tracks_10m.tck

###############################################################
# 16. TRACTOGRAM OPTIMIZATION: SIFT2 FILTERING
###############################################################

tcksift2 -act 5tt.mif tracks_10m.tck wmfod_norm.mif \
sift2_weights.txt -out_mu sift2_mu.txt

###############################################################
# 17. SC MATRIX GENERATION I: CONVERT PARCELLATION IMAGE
###############################################################

 labelconvert ${SUBJECTS_DIR}/${SUBJECTID}/mri/aparc+aseg.mgz \
 ${FREESURFER_HOME}/FreeSurferColorLUT.txt \
 $(which labelconvert)/../share/mrtrix3/labelconvert/fs_default.txt DK_parcels.mif

 ###############################################################
 # 18. SC MATRIX GENERATION II: CREATE MATRIX
 ###############################################################
tck2connectome -tck_weights_in sift2_weights.txt \
-symmetric -zero_diagonal tracks_10m.tck DK_parcels.mif dk.csv
