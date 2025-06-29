# Building Android in Docker, on a Mac or Linux machine

The goal of this repository is to provide an Dockerfile that completely describes a build configuration that will build Android on an arm Mac or an x86_64 (amd64) machine.  The Mac build may not be quick, but it's not prohibitively slow.

This Dockerfile can be modified to build your particular android target by changing the Dockerfile setup (i.e. `apt install` packages) and `repo init` manifest URL or branch.

The goal here is to structure the Dockerfile so many expensive operations need only be performed once, and subsequent incremental operations will be fast.  
	1. `repo init` results will be stored in an image stripe, and subsequent work can be quicker with an incremental `repo sync` instead of doing a full sync from an empty directory
	2. Build (`m`) results will be stored in an image stripes, and subsequent incremental builds will be quicker.

The image stripes can be fully rebuilt using `--no-cache` periodically using a slow overnight job.  Then ongoing work/checks will be quicker.

