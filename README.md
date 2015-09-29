[![Build Status](https://travis-ci.org/seung-lab/Julimaps.svg?branch=master)](https://travis-ci.org/seung-lab/Julimaps)

# Julimaps
JULia IMAge Processing Suite:
A set of tools for elastic image registration in Julia.

# Process
(time in seconds per section)

| Step | Read | Match | Solve | Render | Write | Total | Review Method | Intervene Method |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| premontage | 30 | 10 | 10 | 0 | 30 | 80 | (overlay tiles on overview) | NA |
| montage | 30 | 40 | 20 | 60 | 30 | 180 | (section overlay as checkerboard) | blockmatch image select |
| prealignment | 30 | 25 | 5 | 30 | 30 | 120 | overlay sections | blockmatch image select |
| alignment | 30 | 480 | 20 | 80 | 60 | 670 | movie of sections in FIJI | blockmatch image select |

# Milestones
* Montage two tiles (8/9)
* Montage one section (8/16)
* Prealign two sections (9/1)
* Align two sections (9/3)
* Align five sections (9/5)
* Align one wafer
* Align one stack
* Premontage one section
* Run on AWS

# Terminology
* Tile: the base image unit from the microscope at the highest resolution
* Section: the image formed by combining all the tiles together
* Overview: a downsampled image of the entire substrate from which the tiles were imaged (a downsampled superset of the section)
* Wafer: a collection of sections, denoted by the number of substrates that can fit into the microscope at one time
* Stack: a collection of sections, that include all the wafers

# Pipeline
## Premontage
Register tile images to the overview image by cross correlating the entire tile (downsampled to the overview image resolution) across the entire overview image. Allow tile translations only. Review by inspecting overlay image of tiles on the overview. There is no intervention method, yet.
## Montage
Register tile images to one another by blockmatching in their overlapping portions, as calculated by the premontage translations. Cover each tile image in a triangle mesh, and deform the mesh elastically to accommodate the correspondences. Render with a piecewise affine transform. Review by inspecting the combined overlay plot of all tiles combined. Intervene by removing bad correspondences by identifying bad blockmatch images, or by clicking on correspondences that have non-consistent displacements relative to their neighbors.
## Prealignment
Register montaged sections to the previous prealigned section by blockmatching. Render with a regularized affine transform (part affine, part rigid). Review by looking at overlays of the two sections. Intervene by removing bad correspondences by identifying bad blockmatch images, or by clicking on correspondences that have non-consistent displacements relative to their neighbors. 
## Alignment
Register prealigned sections to each other, and N+k neighboring sections, by blockmatching. Cover each section image in a triangle mesh, and globally deform all the meshes elastically to accommodate the correspondences. Render with a piecewise affine transform. Review by inspecting the combined overlay plot of all tiles combined. Intervene by removing bad correspondences by identifying bad blockmatch images, or by clicking on correspondences that have non-consistent displacements relative to their neighbors.
