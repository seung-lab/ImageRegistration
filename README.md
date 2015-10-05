[![Build Status](https://travis-ci.org/seung-lab/Julimaps.svg?branch=registration)](https://travis-ci.org/seung-lab/Julimaps)

# Image Registration
An image registration package for Julia. 

* create point set correspondences (currently, via blockmatching)
* calculate affine transforms
* render images with affine transforms or use meshes to render images with piecewise linear affine transforms.

## Installation
Use the package manager:

```
Pkg.add("ImageRegistration")
```

## Who is this package for?
This package was designed for people migrating pipelines from other languages 
who are in need of similar image registration functionality. It was produced in 
a neuroscience lab, initially for aligning electron microscopy images, then 
abstracted for more general applications.

## Dependencies
* FixedPointNumbers (to allow for Ufixed series of image types)
* Images 
* ImageView (for the visualization functions)

## Methods
```
matches = blockmatch(imgA, imgB, offsetA, offsetB, params)
img, offset = imwarp(img, tform, offset)
img, offset = meshwarp(img, mesh, offset)
tform = calculate_translation(matches)
tform = calculate_rigid(matches)
tform = calculate_affine(matches)
tform = calculate_translation(mesh)
tform = calculate_rigid(mesh)
tform = calculate_affine(mesh)
new_mesh = matches2mesh(matches, old_mesh)
```

### Objects
#### Mesh
* src_nodes
* dst_nodes
* edges

#### Matches
* mesh_indices
* src_points
* dst_points

### Registration
#### convolution
#### blockmatch

### Transformations
##### affine
Solve a system of moving and fixed points to preserve parallelism.
##### rigid (isometry)
Solve a system of moving and fixed points to preserve distances and angles.
##### translation (displacement)
Solve a system of moving and fixed points to preserve distances and oriented 
angles.
##### piecewise affine (diffeomorphism)
Use a triangle mesh to apply a local affine transform to each triangle.

### Visualizations

### Rendering Methods
#### imwarp
Apply an affine transform to an entire image.
#### meshwarp
Apply a piecewise affine transform to an image, as defined by a mesh.

### Offsets
To translate between intrinsic and global coordinate systems, a 2-element array
notes where the upper left pixel in the image is located in global space. When
a transform is applied to an image, the render method will return the
transformed image along with an offset, denoting the transformed image's
location in global space.

Transform methods will work on images with offsets. Offsets also allow an image
to be rendered in the global coordinate system to align with other images.

### Not currently included in this package
* Alpha masks
* Feature-based image registration (SURF or SIFT)
* Multi-mesh solvers (i.e. affine solvers for more than one mesh, elastic solvers)
* imfuse visualization function (see Overlay type in Images for a start)

http://gbayer.com/development/moving-files-from-one-git-repository-to-another-preserving-history/

### Examples
```
"""
Create a mesh with src_nodes and deformed dst_nodes, then use
meshwarp to deform the image via piecewise affine transforms.
"""
    img = load_test_image() # load test/test_images/turtle.jpg
    src_nodes = [20.0 20.0;
                    620.0 20.0;
                    620.0 560.0;
                    20.0 560.0;
                    320.0 290.0]
    dst_nodes = [20.0 20.0;
                    620.0 20.0;
                    620.0 560.0;
                    20.0 560.0;
                    400.0 460.0]
    edges = spzeros(Int64, 8, 5)
    edges[1,1:2] = [1, -1]
    edges[2,1] = 1
    edges[2,4] = -1
    edges[3,1] = 1
    edges[3,5] = -1
    edges[4,2:3] = [1, -1]
    edges[5,2] = 1
    edges[5,5] = -1
    edges[6,3] = 1
    edges[6,5] = -1
    edges[7,3:4] = [1, -1]
    edges[8,4:5] = [1, -1]
    # 1  -1   0   0   0
    # 1   0   0  -1   0
    # 1   0   0   0  -1
    # 0   1  -1   0   0
    # 0   1   0   0  -1
    # 0   0   1   0  -1
    # 0   0   1  -1   0
    # 0   0   0   1  -1

    mesh = Mesh(src_nodes, dst_nodes, edges)
    imgc, img2 = view(img, pixelspacing=[1,1])
    draw_mesh(imgc, img2, mesh)

    warped_img, offset = meshwarp(img, mesh)
    wimgc, wimg2 = view(warped_img, pixelspacing=[1,1])
    draw_mesh(wimgc, wimg2, mesh)
```
