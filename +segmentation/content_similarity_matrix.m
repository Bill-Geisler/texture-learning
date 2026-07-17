function phi = content_similarity_matrix(image, patch_size, patch_x, patch_y, ...
        bin_bounds, n_bins, dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
% CONTENT_SIMILARITY_MATRIX  All-pairs content similarity between image patches.
%   phi = segmentation.content_similarity_matrix(image, patch_size, ...
%       patch_x, patch_y, bin_bounds, n_bins, ...
%       dv_spot_fun, dv_edge_fun, dv_content_fun, cfg)
%
%   For every pair of patches, computes the content decision variable (paper:
%   ln L_c) by combining the power, spot/colour-histogram, and edge-histogram
%   DVs via the trained content decision function. Returns the symmetric
%   similarity matrix phi (phi_ij). (Was mk_phi.m; now uses vislab and
%   takes preloaded bin bounds + a cfg struct instead of hardcoded constants.)
%
%   Inputs
%     image          - texture-region image, [H x W x 3] (may be rectangular).
%     patch_size     - patch side length in pixels.
%     patch_x,patch_y- patch-index -> grid-coordinate maps (these carry the grid shape).
%     bin_bounds,n_bins - histogram bin bounds/counts (vislab.nat_stat_bayes.load_bin_bounds).
%     dv_spot_fun    - trained spot DV function handle (quad2fun of dbndh).
%     dv_edge_fun    - trained edge DV function handle (quad2fun of dbnde).
%     dv_content_fun - trained content DV function handle (quad2fun of dbndc).
%     cfg            - config struct (see config.m): uses cfg.norm, cfg.dv, cfg.features.
%
%   Output
%     phi - [n x n] symmetric content-similarity matrix (n = number of patches).

    n = numel(patch_x);
    spot_dims = cfg.features.spot_dims;     % [1 13 14]
    edge_dims = cfg.features.edge_dv_dims;  % [5 9 10]
    b0 = cfg.dv.power_suppress;

    % prep every patch once (extract + normalize + rotate; raw and contrast-norm gray)
    [P, G, Gn] = segmentation.prep_grid(image, patch_size, cfg);
    if cfg.dv.contrast_normalize, E = Gn; else, E = G; end   % gray fed to the edge DV

    % featurize every patch once (power spectrum + spot/edge histograms); the pair
    % loop below then only combines them (segmentation.content_dv_pair).
    CF = segmentation.content_features(P, G, E, patch_size, bin_bounds, n_bins, spot_dims, edge_dims, cfg);

    % All-pairs combine is the O(n^2) cost -> parfor over reference patches (runs
    % serially without the Parallel Computing Toolbox). Each iteration fills the upper
    % part of its row; the matrix is symmetrized afterwards.
    phi = zeros(n, n);
    parfor i = 1:n
        fa = CF{patch_x(i), patch_y(i)};
        row = zeros(1, n);
        for j = i+1:n
            row(j) = segmentation.content_dv_pair(fa, CF{patch_x(j), patch_y(j)}, patch_size, b0, ...
                dv_spot_fun, dv_edge_fun, dv_content_fun, spot_dims, edge_dims);
        end
        phi(i, :) = row;
    end
    phi = phi + phi.';                      % symmetric; diagonal stays 0 (self-similarity unused)
end
