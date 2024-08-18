## Usage

Execution of the protocol using this Docker image is performed in two explicit stages:

1.  Conversion of source DICOM data into MRtrix format images with standard naming
    in preparation of execution of the protocol.

2.  Execution of the protocol against those data.

### Prerequisites

1.  FreeSurfer license file:
    A valid FreeSurfer license file is required to execute the protocol.
    This can be obtained from:
    https://surfer.nmr.mgh.harvard.edu/registration.html.
    For simplicity, subsequent examples assume that the filesystem location
    of the license file on the host system has been stored in environment variable $FS_LICENSE.

2.  FSL registration:
    While it is not strictly requisite to execute the protocol within the Docker container,
    it is nevertheless requested that users nevertheless register for the FSL software
    to facilitate faithful tracking of software usage:
    https://fsl.fmrib.ox.ac.uk/fsldownloads_registration/

3.  ACPCDetect:
    Download ACPCDetect tool version 2.1 manually from NITRC:
    https://www.nitrc.org/forum/forum.php?forum_id=8519
    For building the Docker image manually from the corresponding `Dockerfile` (see below),
    the downlaoded .zip file must be placed in the same directory as the `Dockerfile`.
    If obtaining the Docker image from some other source (eg. DockerHub),
    it is nevertheless requested to contribute to having the download statistics of that software
    more faithfull track its usage.

### Obtaining the image

The Docker image to execute the container can be obtained in one of two ways:

1.  Build the image locally from the `Dockerfile` recipe.

    Execute the following command from the root directory of the cloned repository
    (having previously downloaded the ACPCDetect dependency; see above):
    ```bash
    docker build . -t martahedl/sc-construction-using-msmt-csd
    ```

2.  Pull the image from DockerHub:

    ```bash
    docker pull martahedl/sc-construction-using-msmt-csd
    ```

    **NOTE**: Not yet available at time of writing.

### Preparing data for the protocol

Create two directores on your host system;
one will be populated with the contents of the converted DICOM data,
the other will be populated with the derivatives of the protocol; eg.:

```bash
mkdir input/ output/
```

1.  If reproducing the protocol derivatives using the example data,
    the Docker image contains both the original DICOM data
    and a script that converts those DICOM data into the expected format:

    ```bash
    docker run -it --rm \
    -v $(pwd)/input:/input \
    martahedl/sc-construction-using-msmt-csd \
    prep_example_data.sh /input
    ```

2.  If attempting to execute the protocol against your own data,
    you will need to yourself create the requisite files within that directory:

    -   `dwi.mif`
    -   `b0_pa.mif`
    -   `T1w.mif`

    (Note that the protocol script expects a diffusion acquisition
    possessing a particular strategy for multi-shell acquisition
    and variation in phase encoding for susceptibility field estimation;
    acquisitions following some other strategy
    will likely necessitate modification to the protocol command invovations)

    If you have *MRtrix3* installed on your host system,
    this can be done directly using the `mrconvert` command.
    Alternatively, the version of *MRtrix3* `mrconvert` that is installed within the DOcker container
    can instead be used to do this conversion.
    The latter however necessitates the explicit binding of all relevant host system directories.
    For instance, if one's DICOM data were to reside in directory "`/mnt/DICOM/`",
    and it contained a DICOM series in a directory called "`T1w_MPRAGE/"
    the conversion would look something like the following:

    ```bash
    docker run -it --rm \
    -v /mnt/DICOM:/DICOM \
    -v $(pwd)/input:/input \
    martahedl/sc-construction-using-msmt-csd \
    mrconvert /DICOM/T1w_MPRAGE/ /input/T1w.mif
    ```

### Executing the protocol

```bash
docker run -it --rm \
-v $(pwd)/input:/input \
-v $(pwd)/output:/output \
-v ${FS_LICENSE}:/opt/freesurfer/license.txt \
martahedl/sc-construction-using-msmt-csd \
run_protocol.sh /input /output
```

### Visualisation

While it is possible to execute GUI applications using the Docker image,
it is not guaranteed to work in all scenarios.
The following example is one usage that has had reasonable success
in execution of *MRtrix3*'s `mrview` tool.

```bash
xhost +local:root; \
docker run --rm -it \
--device /dev/dri/ \
-v /run:/run \
-v /tmp/.X11-unix:/tmp/.X11-unix \
-e DISPLAY=$DISPLAY \
-e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
-u $UID \
martahedl/sc-construction-using-msmt-csd mrview; \
xhost -local:root
```

For the example data provided with the protocol,
both the original DICOM data and all derivative data
are provided within the image at filesystem path `/data`.
If a user wishes to use the `mrview` through the Docker container
to visualise their own data or the results of processing thereof,
it will be necessary to mount the corresponding filesystem locations,
just as is done for the data preparation & execution examples above.
