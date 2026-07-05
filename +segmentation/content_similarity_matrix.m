function phi = content_similarity_matrix(image, n_patches, patch_size, patch_x, patch_y, ...
        bin_bounds, n_bins, feature_list, dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
% CONTENT_SIMILARITY_MATRIX  All-pairs content similarity between image patches.
%   phi = segmentation.content_similarity_matrix(image, n_patches, patch_size, ...
%       patch_x, patch_y, bin_bounds, n_bins, feature_list, ...
%       dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
%
%   For every pair of patches, computes the content decision variable (paper:
%   ln L_c) by combining the power, spot/colour-histogram, and edge-histogram
%   DVs via the trained content decision function. Returns the symmetric
%   similarity matrix phi (phi_ij). (Was mk_phi.m; now uses vislab and
%   takes preloaded bin bounds + a cfg struct instead of hardcoded constants.)
%
%   Inputs
%     image          - texture-region image, [H x W x 3].
%     n_patches      - grid width in patches (image is n_patches^2 patches).
%     patch_size     - patch side length in pixels.
%     patch_x,patch_y- patch-index -> grid-coordinate maps.
%     bin_bounds,n_bins - histogram bin bounds/counts (vislab.nat_stat_bayes.load_bin_bounds).
%     feature_list   - indicator vector of which DV features to compute.
%     dv_spot_fun    - trained spot DV function handle (quad2fun of dbndh).
%     dv_edge_fun    - trained edge DV function handle (quad2fun of dbnde).
%     dv_content_fun - trained content DV function handle (quad2fun of dbndc).
%     cfg            - config struct (see config.m): uses cfg.norm, cfg.dv, cfg.features.
%
%   Output
%     phi - [n_patches^2 x n_patches^2] symmetric content-similarity matrix.

    n = n_patches^2;
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    n_colr = 3;
    color_norm_type = 3;                    % average-mean normalization for colour patches
    spot_dims = cfg.features.spot_dims;     % [1 13 14]
    edge_dims = cfg.features.edge_dv_dims;  % [5 9 10]

    phi = zeros(n, n);
    for i = 1:n
        p1 = prep_patch(image, patch_x(i), patch_y(i), patch_size, m0, c0, color_norm_type, n_colr);
        for j = i+1:n
            p2 = prep_patch(image, patch_x(j), patch_y(j), patch_size, m0, c0, color_norm_type, n_colr);

            gray1 = p1(:, :, 1);            % achromatic channel for power/edge
            gray2 = p2(:, :, 1);

            % power DV
            rp = log(vislab.nat_stat_bayes.dv_power(gray1, gray2, cfg.dv.power_suppress, patch_size));

            % spot / colour-histogram DV
            spot = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, patch_size, bin_bounds, n_bins, feature_list);
            rh = dv_spot_fun(log(spot(spot_dims))');

            % edge-histogram DV (optionally contrast-normalized first)
            if cfg.dv.contrast_normalize
                gray1 = vislab.lib.cntrst_norm(gray1, c0, patch_size);
                gray2 = vislab.lib.cntrst_norm(gray2, c0, patch_size);
            end
            edge = vislab.nat_stat_bayes.dv_edge_hist(gray1, gray2, cfg.dv.edge_thresh, bin_bounds, n_bins, ...
                cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
            re = dv_edge_fun(log(edge(edge_dims))');

            % combined content DV
            rc = dv_content_fun([rp, rh, re]');
            phi(i, j) = rc;
            phi(j, i) = rc;
        end
    end
end

function patch = prep_patch(image, gx, gy, patch_size, m0, c0, norm_type, n_colr)
% Extract the patch at grid (gx,gy), normalize, and rotate into ABR colour space.
    rows = (gx - 1) * patch_size + (1:patch_size);
    cols = (gy - 1) * patch_size + (1:patch_size);
    patch = image(rows, cols, :);
    patch = vislab.lib.ptch_norm(patch, m0, c0, norm_type, n_colr);
    patch = vislab.nat_stat_bayes.apply_color_rotation(patch);   % shared LMS->ABR transform
end
