
"""
Remove matches from meshset corresponding to the indices provided.

Args:

* indices_to_remove: array of indices of match points to remove
* match_index: the index of the matches object in the meshset
* meshset: the meshset containing all the matches

Returns:

* (updated meshset)

  remove_matches_from_meshset!(indices_to_remove, match_index, meshset)
"""
function remove_matches_from_meshset!(indices_to_remove, match_index, meshset)
  println("Removing ", length(indices_to_remove), " points")
  if length(indices_to_remove) > 0
    matches = meshset.matches[match_index]
    flag = trues(matches.n)
    flag[indices_to_remove] = false
    matches.src_pointIndices = matches.src_pointIndices[flag]
    matches.dst_points = matches.dst_points[flag]
    matches.dst_triangles = matches.dst_triangles[flag]
    matches.dst_weights = matches.dst_weights[flag]
    matches.dispVectors = matches.dispVectors[flag]
    no_pts_removed = length(indices_to_remove)
    matches.n -= no_pts_removed
    meshset.m -= no_pts_removed
    meshset.m_e -= no_pts_removed
  end
end

"""
Find index of location in array with point closest to the given point (if there
exists such a unique point within a certain pixel limit).

Args:

* pts: 2xN array of coordinates
* pt: 2-element coordinate array of point in interest
* limit: number of pixels that nearest must be within

Returns:

* index of the nearest point in the pts array

  idx = find_idx_of_nearest_pt(pts, pt, limit)
"""
function find_idx_of_nearest_pt(pts, pt, limit)
    d = sum((pts.-pt).^2, 1).^(1/2)
    idx = eachindex(d)'[d .< limit]
    if length(idx) == 1
        return idx[1]
    else
        return 0
    end
end

"""
Provide bindings for GUI to right-click and remove matches from a mesh. End 
manual removal by exiting the image window, or by pressing enter while focused
on the image window.

Args:

* imgc: ImageCanvas object (from image with annotations)
* img2: ImageZoom object (from image with annotations)
* annotation: the annotation object from the image

Returns:

* pts_to_remove: array of indices for points to remove from mesh

  pts_to_remove = edit_matches(imgc, img2, annotation)
"""
function edit_matches(imgc, img2, annotation)
    e = Condition()

    pts_to_remove = Array{Integer,1}()
    pts = copy(annotation.ann.data.pts)

    c = canvas(imgc)
    win = Tk.toplevel(c)
    bind(c, "<Button-3>", (c, x, y)->right_click(parse(Int, x), parse(Int, y)))
    bind(win, "<Return>", path->end_edit())
    bind(win, "<KP_Enter>", path->end_edit())
    bind(win, "<Destroy>", path->end_edit())

    function right_click(x, y)
        xu,yu = Graphics.device_to_user(Graphics.getgc(imgc.c), x, y)
        xi, yi = floor(Integer, 1+xu), floor(Integer, 1+yu)
        # println(xi, ", ", yi)
        limit = (img2.zoombb.xmax - img2.zoombb.xmin) * 0.0125 # 100/8000
        annpts = annotation.ann.data.pts
        annidx = find_idx_of_nearest_pt(annpts, [xi, yi], limit)
        if annidx > 0
            idx = find_idx_of_nearest_pt(pts, [xi, yi], limit)
            println(idx, ": ", [xi, yi])
            annotation.ann.data.pts = hcat(annpts[:,1:annidx-1], 
                                                        annpts[:,annidx+1:end])
            ImageView.redraw(imgc)
            push!(pts_to_remove, idx)
        end
    end

    function end_edit()
        println("End edit")
        notify(e)
        bind(c, "<Button-3>", path->path)
        bind(win, "<Return>", path->path)
        bind(win, "<KP_Enter>", path->path)
        bind(win, "<Destroy>", path->path)
    end

    println("Right click to remove correspondences, then press enter.")
    wait(e)

    return pts_to_remove
end

"""
Display index k match pair meshes are two frames in movie to scroll between
"""
function review_matches_movie(meshset, k, step="post", downsample=2)
  matches = meshset.matches[k]
  src_index = matches.src_index
  dst_index = matches.dst_index
  println("display_matches_movie: ", (src_index, dst_index))
  src_mesh = meshset.meshes[findIndex(meshset, src_index)]
  dst_mesh = meshset.meshes[findIndex(meshset, dst_index)]

  if step == "post"
    src_nodes, dst_nodes = get_matched_points_t(meshset, k)
    src_index = (src_mesh.index[1], src_mesh.index[2], src_mesh.index[3]-1, src_mesh.index[4]-1)
    dst_index = (dst_mesh.index[1], dst_mesh.index[2], dst_mesh.index[3]-1, dst_mesh.index[4]-1)
    global_bb = get_global_bb(meshset)
    src_offset = [global_bb.i, global_bb.j]
    dst_offset = [global_bb.i, global_bb.j]
  else
    src_nodes, dst_nodes = get_matched_points(meshset, k)
    src_offset = src_mesh.disp
    dst_offset = dst_mesh.disp
  end

  src_nodes = hcat(src_nodes...)[1:2, :] .- src_offset
  dst_nodes = hcat(dst_nodes...)[1:2, :] .- dst_offset

  src_img = getFloatImage(src_index)
  println(size(src_img))
  for i = 1:downsample
    src_img = restrict(src_img)
    src_nodes /= 2
  end
  dst_img = getFloatImage(dst_index)
  println(size(dst_img))
  for i = 1:downsample
    dst_img = restrict(dst_img)
    dst_nodes /= 2
  end

  i_max = min(size(src_img,1), size(dst_img,1))
  j_max = min(size(src_img,2), size(dst_img,2))
  img = Image(cat(3, src_img[1:i_max, 1:j_max], dst_img[1:i_max, 1:j_max]), timedim=3)
  # imgc, img2 = view(make_isotropic(img))
  imgc, img2 = view(img)
  vectors = [src_nodes; dst_nodes]
  # an_pts, an_vectors = draw_vectors(imgc, img2, vectors)
  an_src_pts = draw_points(imgc, img2, src_nodes, RGB(1,0,0))
  an_dst_pts = draw_points(imgc, img2, dst_nodes, RGB(0,1,0))
  pts_to_remove = edit_matches(imgc, img2, an_dst_pts)
  src_img = 0; dst_img = 0; imgc = 0; img2 = 0;
  gc()
  return pts_to_remove
end

"""
Determine appropriate meshset solution method for meshset
"""
function resolve!(meshset::MeshSet)
  index = meshset.meshes[1].index
  if is_montaged(index)
    solveMeshSet!(meshset)
  elseif is_prealigned(index)
    continue
  elseif is_aligned(index)
    solveMeshSet!(meshset)
  end
end

"""
Append 'EDITED' with a timestamp to update JLD filename
"""
function update_filename(fn)
  return string(fn[1:end-4], "_EDITED_", Dates.format(now(), "yyyymmddHHMMSS"), ".jld")
end

"""
Review all matches in the meshsets in given directory via method specified
"""
function review_matches(dir, method="movie")
  jld_filenames = filter(x -> x[end-2:end] == "jld", readdir(dir))
  for fn in jld_filenames[1:1]
    println(joinpath(dir, fn))
    meshset = load(joinpath(dir, fn))["MeshSet"]
    new_path = update_filename(fn)
    log_file = open(joinpath(dir, string(new_path[1:end-4], ".txt")), "w")
    write(log_file, "Meshset from ", joinpath(dir, fn), "\n")
    for (k, matches) in enumerate(meshset.matches)
      println("Inspecting matches at index ", k,)
      if method=="images"
        src_bm_imgs = get_blockmatch_images(meshset, k, "src", meshset.params.block_size)
        dst_bm_imgs = get_blockmatch_images(meshset, k, "dst", meshset.params.block_size)
        filtered_imgs = create_filtered_images(src_bm_imgs, dst_bm_imgs)
        pts_to_remove = edit_blockmatches(filtered_imgs)
      else
        pts_to_remove = review_matches_movie(meshset, k, "pre", 3)
      end
      save_blockmatch_imgs(pts_to_remove, meshset, k, joinpath(dir, "blockmatches"))
      remove_matches_from_meshset!(pts_to_remove, k, meshset)
      log_line = string("Removed following matches from index ", k, ":\n")
      log_line = string(log_line, join(pts_to_remove, "\n"))
      write(log_file, log_line, "\n")
    end
    resolve!(meshset)
    println("Saving JLD here: ", path)
    close(log_file)
    @time save(joinpath(dir, path), meshset)
  end
end

"""
Convert matches object for section into filename string
"""
function matches2filename(meshset, k)
  src_index = meshset.matches[k].src_index
  dst_index = meshset.matches[k].dst_index
  return string(join(src_index[1:2], ","), "-", join(dst_index[1:2], ","))
end

"""
Convert cross correlogram to Image for saving
"""
function xcorr2Image(xc)
  return grayim((xc .+ 1)./2)
end

"""
Save match pair images w/ search & block radii at k index in meshset
"""
function save_blockmatch_imgs(blockmatch_ids, meshset, k, path)
  dir_path = joinpath(path, matches2filename(meshset, k))
  if !isdir(dir_path)
    mkdir(dir_path)
  end
  block_radius = meshset.params.block_size
  search_radius = meshset.params.search_r
  src_imgs = get_blockmatch_images(meshset, k, "src", block_radius)
  combined_radius = search_radius+block_radius
  dst_imgs = get_blockmatch_images(meshset, k, "dst", combined_radius)
  println("save_blockmatch_imgs")
  for (idx, (src_img, dst_img)) in enumerate(zip(src_imgs, dst_imgs))
    println(idx, "/", length(src_imgs))
    xc = normxcorr2(src_img, dst_img)
    n = @sprintf("%03d", idx)
    img_mark = "good"
    if idx in blockmatch_ids
      img_mark = "bad"
    end
    imwrite(src_img, joinpath(dir_path, string(img_mark, "_", n , "_src_", k, ".jpg")))
    imwrite(dst_img, joinpath(dir_path, string(img_mark, "_", n , "_dst_", k, ".jpg")))
    if !isnan(sum(xc))
      imwrite(xcorr2Image(xc), joinpath(dir_path, string(img_mark, "_", n , "_xc_", k, ".jpg")))
    end
  end
end

"""
Return first JLD file in provided directory
"""
function load_sample_meshset(dir)
  jld_filenames = filter(x -> x[end-2:end] == "jld", readdir(dir))
  fn = jld_filenames[4]
  println(joinpath(dir, fn))
  return load(joinpath(dir, fn))["MeshSet"]
end

"""
Excerpt image in radius around given point
"""
function sliceimg(img, point, radius::Int64)
  point = ceil(Int64, point)
  imin = min(point[1]-radius, 1)
  jmin = min(point[2]-radius, 1)
  imax = min(point[1]+radius, size(img,1))
  jmax = min(point[2]+radius, size(img,2))
  i_range = imin:imax
  j_range = jmin:jmax
  return img[i_range, j_range]
end

# """
# Excerpt image for given range
# """
# function sliceimg(img, point::Array{1}, radius::Int64)
#   point = ceil(Int64, point)
#   imin = min(point[1]-radius, 1)
#   jmin = min(point[2]-radius, 1)
#   imax = min(point[1]+radius, size(img,1))
#   jmax = min(point[2]+radius, size(img,2))
#   i_range = imin:imax
#   j_range = jmin:jmax
#   return img[i_range, j_range]
# end

"""
Retrieve 1d array of block match pairs from the original images
"""
function get_blockmatch_images(meshset, k, mesh_type, radius)
  matches = meshset.matches[k]
  index = matches.(symbol(mesh_type, "_index"))
  mesh = meshset.meshes[findIndex(meshset, index)]
  points = get_matched_points(meshset, k)
  # src_points_t, dst_points_t = get_matched_points_t(meshset, k)
  offset = mesh.disp
  img = getFloatImage(mesh)
  bm_imgs = []
  for pt in (mesh_type == "src" ? points[1] : points[2])
    push!(bm_imgs, sliceimg(img, pt-offset, radius))
  end
  return bm_imgs
end

"""
Make one image from two blockmatch images, their difference, & their overlay
"""
function create_filtered_images(src_imgs, dst_imgs)
  images = []
  for (n, (src_img, dst_img)) in enumerate(zip(src_imgs, dst_imgs))
    println(n, "/", length(src_imgs))
    diff_img = convert(Image{RGB}, src_img-dst_img)
    imgA = grayim(Image(src_img))
    imgB = grayim(Image(dst_img))
    yellow_img = Overlay((imgA,imgB), (RGB(1,0,0), RGB(0,1,0)))
    pairA = convert(Image{RGB}, src_img)
    pairB = convert(Image{RGB}, dst_img)
    left_img = vcat(pairA, pairB)
    right_img = vcat(diff_img, yellow_img)
    img = hcat(left_img, right_img)
    push!(images, img)
  end
  return images
end

"""
Edit blockmatches with paging
"""
function edit_blockmatches(images)
  max_images_to_display = 60
  no_of_images = length(images)
  pages = ceil(Int, no_of_images / max_images_to_display)
  blockmatch_ids = Set()
  for page in 1:pages
    start = (page-1)*max_images_to_display + 1
    finish = start-1 + min(max_images_to_display, length(images)-start-1)
    println(start, finish)
    page_ids = display_blockmatches(images[start:finish], true, start)
    blockmatch_ids = union(blockmatch_ids, page_ids)
  end
  return blockmatch_ids
end

"""
Display blockmatch images in a grid to be clicked on
"""
function display_blockmatches(images, edit_mode_on=false, start_index=1)
  no_of_images = length(images)
  println("Displaying ", no_of_images, " images")
  grid_height = 6
  grid_width = 10
  # aspect_ratio = 1.6
  # grid_height = ceil(Int, sqrt(no_of_images/aspect_ratio))
  # grid_width = ceil(Int, aspect_ratio*grid_height)
  img_canvas_grid = canvasgrid(grid_height, grid_width, pad=1)
  match_index = 0
  blockmatch_ids = Set()
  e = Condition()

  function right_click(k)
    if in(k, blockmatch_ids)
      blockmatch_ids = setdiff(blockmatch_ids, Set(k))
    else
      push!(blockmatch_ids, k)
    end
    println(collect(blockmatch_ids))
  end

  for j = 1:grid_width
    for i = 1:grid_height
      match_index += 1
      n = match_index + start_index - 1
      if match_index <= no_of_images
        img = images[match_index]
        # imgc, img2 = view(img_canvas_grid[i,j], make_isotropic(img))
        imgc, img2 = view(img_canvas_grid[i,j], img)
        img_canvas = canvas(imgc)
        if edit_mode_on
          bind(img_canvas, "<Button-3>", path->right_click(n))
          win = Tk.toplevel(img_canvas)
          bind(win, "<Destroy>", path->notify(e))
        end
      end
    end
  end
  if edit_mode_on
    wait(e)
  end
  return blockmatch_ids
end

"""
`IMFUSE_SECTION` - Stitch section with seam overlays.

INCOMPLETE
"""
function imfuse_section(meshes)
    img_reds = []
    img_greens = []
    bbs_reds = []
    bbs_greens = []
    for mesh in meshes
        img, bb = meshwarp(mesh)
        img = restrict(img)
        bb = BoundingBox(bb/2..., size(img)[1], size(img)[2])
        if (mesh.index[3] + mesh.index[4]) % 2 == 1
            push!(img_reds, img)
            push!(bbs_reds, bb)
        else
            push!(img_greens, img)
            push!(bbs_greens, bb)
        end
    end
    global_ref = sum(bbs_reds) + sum(bbs_greens)
    red_img = zeros(Int(global_ref.h), Int(global_ref.w))
    for (idx, (img, bb)) in enumerate(zip(img_reds, bbs_reds))
        println(idx)
        i = bb.i - global_ref.i+1
        j = bb.j - global_ref.j+1
        w = bb.w-1
        h = bb.h-1
        red_img[i:i+h, j:j+w] = max(red_img[i:i+h, j:j+w], img)
        img_reds[idx] = 0
        gc()
    end
    green_img = zeros(Int(global_ref.h), Int(global_ref.w))
    for (idx, (img, bb)) in enumerate(zip(img_greens, bbs_greens))
        println(idx)
        i = bb.i - global_ref.i+1
        j = bb.j - global_ref.j+1
        w = bb.w-1
        h = bb.h-1
        green_img[i:i+h, j:j+w] = max(green_img[i:i+h, j:j+w], img)
        img_greens[idx] = 0
        gc()
    end
    O, O_bb = imfuse(red_img, [0,0], green_img, [0,0])
    view(make_isotropic(O))
end 

"""
Display index k match pair meshes are two frames in movie to scroll between
"""
function section_movie(meshset, slice_range=(20000:24000, 20000:24000), downsample=2)
  global_bb = get_global_bb(meshset)
  offset = [global_bb.i, global_bb.j]
  all_imgs = []
  all_nodes = []
  for mesh in meshset.meshes
    img = getFloatImage((mesh.index[1], mesh.index[2], -4, -4))
    img = img[slice_range...]
    nodes = hcat(mesh.nodes_t...) .- offset
    for i = 1:downsample
      img = restrict(img)
      nodes /= 2
    end
    push!(all_imgs, img)
    push!(all_nodes, collect(nodes))
  end
  imgs = Image(cat(3, all_imgs...), timedim=3)
  imgc, img2 = view(imgs)
  n_groups = length(all_nodes)
  for (idx, node_group) in enumerate(all_nodes)
    r = idx*1.0 / n_groups
    an_pts = draw_points(imgc, img2, node_group, RGB(r,0,0))
  end
  return imgc, img2
end

function scan_section_movie(meshset, divisions=8, downsample=2)
  global_bb = get_global_bb(meshset)
  all_nodes = []
  for mesh in meshset.meshes
    nodes = hcat(mesh.nodes_t...) .- offset
    for i = 1:downsample
      nodes /= 2
    end
    push!(all_nodes, [nodes])
  end

  ispan = ceil(Int64, global_bb.h/divisions)
  jspan = ceil(Int64, global_bb.w/divisions)
  overlap = 200
  for j=1:divisions
    for i=1:divisions
      imin = min((i-1)*ispan - overlap, 1)
      jmin = min((j-1)*jspan - overlap, 1)
      imax = min(i*ispan, global_bb.h)
      jmax = min(j*jspan, global_bb.w)
      slice_range = (imin:imax, jmin:jmax)

      all_imgs = []
      for mesh in meshset.meshes
        img = getFloatImage((mesh.index[1], mesh.index[2], -4, -4))[slice_range...]
        # img = getFloatImage(mesh)
        for i = 1:downsample/2
          img = restrict(img)
        end
        push!(all_imgs, img)
      end
      imgs = Image(cat(3, all_imgs...), timedim=3)
      imgc, img2 = view(imgs)
      n_groups = length(all_nodes)
      for (idx, node_group) in enumerate(all_nodes)
        r = idx*1.0 / n_groups
        an_pts = draw_points(imgc, img2, node_group, RGB(r,0,0))
      end

      e = Condition()
      c = canvas(imgc)
      win = Tk.toplevel(c)
      bind(win, "<Destroy>", path->notify(e))

      wait(e)
    end
  end
end

function write_prealignment_thumbnails(downsample=8)
  img_filenames = filter(x -> x[end-2:end] == "tif", readdir(PREALIGNED_DIR))
  for filename_A in img_filenames
    img_preceding = filter(x -> parseName(x)[2]-1 == parseName(filename_A)[2], img_filenames)
    if length(img_preceding) > 0
      filename_B = img_preceding[1]
      println(filename_B, "-", filename_A)
      A = getFloatImage(joinpath(PREALIGNED_DIR, filename_A))
      for i = 1:downsample/2
        A = restrict(A)
      end
      B = getFloatImage(joinpath(PREALIGNED_DIR, filename_B))
      for i = 1:downsample/2
        B = restrict(B)
      end
      B_offset = PREALIGNED_OFFSETS[find(i -> PREALIGNED_OFFSETS[i,1]==filename_B[1:end-4], 1:size(PREALIGNED_OFFSETS, 1)), 3:4]
      O, O_bb = imfuse(A, [0,0], B, B_offset)
      println("Writing ", filename_B[1:end-4])
      fn = string(filename_B[1:end-4], "-", filename_A[1:end-4], ".jpg")
      imwrite(O, joinpath(PREALIGNED_DIR, "review", fn))
    end
  end
end  



