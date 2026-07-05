function [phi, dst] = neighbor_similarity_matrix(image, n_patches, patch_size, patch_x, patch_y, ...
        neighbor_distance, bin_bounds, n_bins, feature_list, dv, cfg)
% NEIGHBOR_SIMILARITY_MATRIX  Border+content similarity for neighbouring patch pairs.
%   [phi, dst] = segmentation.neighbor_similarity_matrix(image, n_patches, ...
%       patch_size, patch_x, patch_y, neighbor_distance, ...
%       bin_bounds, n_bins, feature_list, dv, cfg)
%
%   For each NEIGHBOURING patch pair (Euclidean patch-centre distance equal to
%   neighbor_distance), computes the power/spot/edge content DV and the border DV
%   and combines them with the trained border+content bound (dv.bc), giving the
%   self-supervised similarity phi_ij used for grouping. Non-neighbour entries are
%   zero. Also returns the full pairwise distance matrix dst. Used by stage s7.
%   (Was the neighbour "phi" loop in tex_grp_s_p_ms_SS_{ncm,ncbm}.m.)
%
%   Inputs mirror segmentation.content_similarity_matrix, plus:
%     neighbor_distance - distance (pixels) identifying a neighbouring pair (= patch_size).
%     dv                - struct of trained DV handles: dv.h, dv.e, dv.c, dv.b, dv.bc.
%
%   Note: per-pair DVs use cfg.gtr.power_suppress (b0=16), matching
%   neighbor_far_responses and content_similarity_matrix (cfg.dv.power_suppress,
%   also 16 since Geisler unified b0 -- 2026-07).

    n = n_patches^2;
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    n_colr = 3;
    norm_type = 3;                          % average-mean normalization for colour patches
    b0 = cfg.gtr.power_suppress;
    spot_dims = cfg.features.spot_dims;     % [1 13 14]
    edge_dims = cfg.features.edge_dv_dims;  % [5 9 10]

    phi = zeros(n, n);
    dst = zeros(n, n);
    for i = 1:n
        x1 = (patch_x(i) - 1) * patch_size + 1;
        y1 = (patch_y(i) - 1) * patch_size + 1;
        p1 = [];                            % lazily prepared only for neighbour pairs
        for j = i+1:n
            x2 = (patch_x(j) - 1) * patch_size + 1;
            y2 = (patch_y(j) - 1) * patch_size + 1;
            dij = sqrt((x1 - x2)^2 + (y1 - y2)^2);
            dst(i, j) = dij;
            dst(j, i) = dij;
            if dij ~= neighbor_distance
                continue;
            end
            if y1 == y2 && x2 > x1          % vertical neighbour -> dir 1; else horizontal -> dir 2
                dir = 1;
            else
                dir = 2;
            end
            if isempty(p1), p1 = prep(i); end
            p2 = prep(j);

            g1 = p1(:, :, 1);  g2 = p2(:, :, 1);        % achromatic channel
            rp = log(vislab.nat_stat_bayes.dv_power(g1, g2, b0, patch_size));
            spot = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, patch_size, bin_bounds, n_bins, feature_list);
            rh = dv.h(log(spot(spot_dims))');
            if cfg.dv.contrast_normalize
                g1 = vislab.lib.cntrst_norm(g1, c0, patch_size);
                g2 = vislab.lib.cntrst_norm(g2, c0, patch_size);
            end
            border = vislab.nat_stat_bayes.dv_border(g1, g2, patch_size, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
            rb = dv.b(border(1:2)');
            edge = vislab.nat_stat_bayes.dv_edge_hist(g1, g2, cfg.dv.edge_thresh, bin_bounds, n_bins, ...
                cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
            re = dv.e(log(edge(edge_dims))');
            rc = dv.c([rp, rh, re]');

            phi(i, j) = dv.bc([rc, rb]');               % [content, border] ordering (Geisler-confirmed; matches s5 dbndbc training)
            phi(j, i) = phi(i, j);
        end
    end

    function p = prep(idx)
        rows = (patch_x(idx) - 1) * patch_size + (1:patch_size);
        cols = (patch_y(idx) - 1) * patch_size + (1:patch_size);
        p = vislab.lib.ptch_norm(image(rows, cols, :), m0, c0, norm_type, n_colr);
        p = vislab.nat_stat_bayes.apply_color_rotation(p);   % shared LMS->ABR transform
    end
end
