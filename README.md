## Usage

Execution of the protocol is performed in multiple explicit stages:

1.  Conversion of source DICOM data into MRtrix format images with standard naming
    in preparation of execution of the protocol.

2.  Execution of the protocol against those data to produce the protocol derivatives.

3.  (*optional*) Execution of commands to generate supplementary material.

This Docker container contains three scripts corresponding to these stages.
These can be executed against either the exmple data provided with the protocol
(which are embedded within the Docker image),
or run for one's own data with no or minimal modification.

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
    Download ACPCDetect tool version 2.2 for Linux manually from NITRC:
    https://www.nitrc.org/frs/?group_id=90
    For building the Docker image manually from the corresponding `Dockerfile` (see below),
    the downlaoded .zip file must be placed in the same directory as the `Dockerfile`.
    Note that even if your host system is running MacOSX,
    it is the Linux version of the tool that must be obtained,
    as that is the operating system within the container environment.
    If obtaining the Docker image from some other source (eg. DockerHub),
    it is nevertheless requested to contribute to having the download statistics of that software
    more faithfully track its usage.

### Obtaining the image

The Docker image to execute the container can be obtained in one of two ways:

1.  Build the image locally from the `Dockerfile` recipe.

    Execute the following command from the root directory of the cloned repository
    (having previously downloaded the ACPCDetect dependency; see above):
    ```bash
    DOCKER_BUILDKIT=1 docker build . -t martah/sc-construction-using-msmt-csd
    ```

2.  Pull the image from DockerHub:

    ```bash
    docker pull martah/sc-construction-using-msmt-csd
    ```

### Executing the protocol

#### Part 1: Conversion of DICOM data

For the example data provided with the protocol,
the DICOM data have already been converted to the MRtrix `.mif` format
and stored within the DOcker image,
such that the protocol can be executed directly against those data.
We nevertheless provide the requisite code
to reproduce that conversion for those example data:

```bash
mkdir raw
docker run -it --rm \
-v $(pwd)/raw:/raw \
martah/sc-construction-using-msmt-csd \
convert_example_dicoms.sh /raw
```

If one wishes to run the protocol against their own data,
you will need to yourself create the requisite files within a directory:

```
raw/
    dwi.mif
    b0_pa.mif
    T1w.mif
```

(Note that the protocol script expects a diffusion acquisition
possessing a particular strategy for multi-shell acquisition
and variation in phase encoding for susceptibility field estimation;
acquisitions following some other strategy
will likely necessitate modification to the protocol command invovations)

If you have *MRtrix3* installed on your host system,
this can be done directly using the `mrconvert` command.
Alternatively, the version of *MRtrix3* `mrconvert`
that is installed within the Docker container
can instead be used to do this conversion.
The latter however necessitates the explicit binding of all relevant host system directories.
For instance, if one's DICOM data were to reside in directory "`/mnt/DICOM/`",
and it contained a DICOM series in a directory called "`T1w_MPRAGE/`"
the conversion would look something like the following:

```bash
docker run -it --rm \
-v /mnt/DICOM:/DICOM \
-v $(pwd)/raw:/raw \
martah/sc-construction-using-msmt-csd \
mrconvert /DICOM/T1w_MPRAGE/ /raw/T1w.mif
```

#### Stage 2: Execution of the protocol

If reproducing execution of the protocol
utilising the converted DICOM data stored within the Docker image:

```bash
mkdir derivatives
docker run -it --rm \
-v $(pwd)/derivatives:/derivatives \
-v ${FS_LICENSE}:/opt/freesurfer/license.txt \
martah/sc-construction-using-msmt-csd \
run_protocol.sh /data/raw /derivatives
```

Note that path "`/data/raw`" refers to the location within the Docker image
where the converted DICOM data have been preloaded.

If instead executing the protocol
either against the reproduced DICOM conversion as per stage 1 above
or against one's own data:

```bash
mkdir derivatives
docker run -it --rm \
-v $(pwd)/raw:/raw \
-v $(pwd)/derivatives:/derivatives \
-v ${FS_LICENSE}:/opt/freesurfer/license.txt \
martah/sc-construction-using-msmt-csd \
run_protocol.sh /raw /derivatives
```

Note that directory "`raw/`",
residing in the current working directory on the host system
and populated with the results of conversion of DICOM data,
is mounted to location "`/raw`" within the container,
and it is this path that is passed as input to the "`run_protocol.sh`" script.

If you see the warning:
```
docker: invalid spec: :/opt/freesurfer/license.txt: empty section between colons.
```

, this indicates that environment variable `FS_LICENSE` has not been set;
this must be configured according to the prerequsites listed above.

#### Stage 3: Generation of supplementary material

If you wish to also generate the content that is presented in the Supplementary Material:

```bash
mkdir supplementary/
docker run -it --rm \
-v $(pwd)/raw:/raw \
-v $(pwd)/derivatives:/derivatives \
-v $(pwd)/supplementary:/supplementary \
martah/sc-construction-using-msmt-csd \
gen_supplementary.sh /raw /derivatives /supplementary
```

Note that in order to run the "`gen_supplementary.sh`" script,
it is necessary to have executed the protocol locally (stage 2 above),
on either the exemplar data or on one's own data.
Attempting to run this script utilising the downlaoded exemplar derivative data
will result in failure due to absence of the dense whole-brain tractogram data.

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
martah/sc-construction-using-msmt-csd mrview; \
xhost -local:root
```

For the example data provided with the protocol,
the original DICOM data, converted DICOMs, derivatives,
and images generated in supplementary material
are provided within the image at filesystem path `/data`.
If a user wishes to use the `mrview` through the Docker container
to visualise their own data or the results of processing thereof,
it will be necessary to mount the corresponding filesystem locations,
just as is done for the various examples above.
