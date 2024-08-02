Requirements:

1.	FreeSurfer license file: Download and install FreeSurfer on your local machine. The instructions can be found at: https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall. The license file will be located at $FREESURFER_HOME/license.txt. To use the current Docker image, you’ll have to indicate the location of that license file in the header.
2.	FSL software: Download and install FSL on your local machine. The instructions can be found at: https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/index
3.	ACPCdetect: Download and install ACPCdetect from NITRC and place it in the same directory as the Dockerfile when building the container. The instructions can be found at: https://www.nitrc.org/forum/forum.php?forum_id=8519

To facilitate usage of the Docker container, we provide an example container invocation (cf. file “Docker_example”) showing:
-	Mounting of the FreeSurfer license file location
-	Specifying that the full analysis workflow is to be executed
-	Specifying the in-built DICOM data as the input data
-	Specifying an output location

![image](https://github.com/user-attachments/assets/ec88be37-be63-4230-a060-40c06edd78b4)
