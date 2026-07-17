function [P, G, Gn] = prep_grid(image, psz, cfg)
% PREP_GRID  Prepare every patch of the image grid ONCE.
%   [P, G, Gn] = segmentation.prep_grid(image, psz, cfg)
%
%   The single source of per-patch preparation shared by
%   segmentation.content_similarity_matrix, segmentation.neighbor_similarity_matrix
%   and neighbor_far_responses (which previously each had their own copy and
%   re-prepared patches per pair). For every grid cell it extracts the patch,
%   mean-normalizes it (ptch_norm type 3), rotates LMS->ABR, and also returns the
%   raw and contrast-normalized achromatic channels -- so the all-pairs / neighbour
%   loops just index these instead of recomputing.
%
%   The grid size follows the image: size(image)/psz patches in each dimension, so
%   the image may be rectangular (any whole number of patches per side).
%
%   Inputs
%     image - texture-region image, [H x W x 3] (H, W each a multiple of psz).
%     psz   - patch side length in pixels.
%     cfg   - config struct (uses cfg.norm.target_mean / target_contrast).
%
%   Outputs (each a [H/psz x W/psz] cell, indexed by grid coordinate {gx, gy})
%     P  - [psz x psz x 3] ABR patch.
%     G  - [psz x psz] raw achromatic channel (P(:,:,1)), for the power DV.
%     Gn - [psz x psz] contrast-normalized achromatic channel, for the edge/border DVs.
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    npx = size(image, 1) / psz;      % patch rows
    npy = size(image, 2) / psz;      % patch cols
    P  = cell(npx, npy);
    G  = cell(npx, npy);
    Gn = cell(npx, npy);
    for gx = 1:npx
        for gy = 1:npy
            rows = (gx - 1) * psz + (1:psz);
            cols = (gy - 1) * psz + (1:psz);
            p = vislab.lib.ptch_norm(image(rows, cols, :), m0, c0, 3, 3);
            p = vislab.nat_stat_bayes.apply_color_rotation(p);   % shared LMS->ABR transform
            P{gx, gy}  = p;
            G{gx, gy}  = p(:, :, 1);
            Gn{gx, gy} = vislab.lib.cntrst_norm(p(:, :, 1), c0, psz);
        end
    end
end
