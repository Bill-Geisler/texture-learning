function CF = content_features(P, G, E, psz, bin_bounds, n_bins, spot_dims, edge_dims, cfg)
% CONTENT_FEATURES  Precompute each grid patch's content features ONCE.
%   CF = segmentation.content_features(P, G, E, psz, bin_bounds, n_bins, ...
%           spot_dims, edge_dims, cfg)
%
%   The featurize half of the content decision variable. The all-pairs / neighbour
%   loops otherwise recompute every patch's power spectrum and feature histograms for
%   each of its pairings -- O(n^2) featurizations of only n distinct patches. This
%   computes them once per patch (O(n)); segmentation.content_dv_pair then just
%   combines two patches' features. Shared by content_similarity_matrix,
%   neighbor_similarity_matrix and neighbor_far_responses.
%
%   Inputs (P, G, E are grid cells from segmentation.prep_grid, indexed {gx,gy})
%     P          - ABR patch (for the spot / colour histograms).
%     G          - raw achromatic channel (for the power spectrum).
%     E          - achromatic channel fed to the edge histograms (contrast-normalized
%                  or raw, chosen by the caller to match its dv_edge_hist call).
%     psz        - patch size in pixels.
%     bin_bounds, n_bins - histogram bin edges / counts (load_bin_bounds).
%     spot_dims  - spot feature dims to histogram (cfg.features.spot_dims, e.g. [1 13 14]).
%     edge_dims  - edge feature dims to histogram (cfg.features.edge_dv_dims, e.g. [5 9 10]).
%     cfg        - config struct (edge threshold + steerable kernel widths).
%
%   Output
%     CF - [gx x gy] cell; CF{gx,gy} is a struct with fields
%            .pspec       normalized power spectrum of G{gx,gy}
%            .hspot{k}    histcounts of spot feature k (k in spot_dims)
%            .hedge{k}    histcounts of edge feature k (k in edge_dims)
    thr = cfg.dv.edge_thresh;                 % only affects unused count features here
    sd1 = cfg.dv.sd1; nsd1 = cfg.dv.nsd1; sd2 = cfg.dv.sd2; nsd2 = cfg.dv.nsd2;
    fl_spot = zeros(1, 20); fl_spot(spot_dims) = 1;
    fl_edge = zeros(1, 20); fl_edge(edge_dims) = 1;
    [nx, ny] = size(P);

    % Featurize each patch independently -> parfor (runs serially without the Parallel
    % Computing Toolbox). This is the per-patch (FFT + steerable) cost shared by
    % content_similarity_matrix, neighbor_similarity_matrix and neighbor_far_responses.
    Pv = P(:);  Gv = G(:);  Ev = E(:);        % linear order so parfor can slice
    CFv = cell(nx * ny, 1);
    parfor k = 1:nx * ny
        s = struct('pspec', vislab.nat_stat_bayes.power_spectrum(Gv{k}), 'hspot', [], 'hedge', []);

        sv = vislab.nat_stat_bayes.spot_features(Pv{k}, psz, fl_spot);
        hs = cell(1, 20);
        for t = 1:numel(spot_dims)
            d = spot_dims(t);  hs{d} = histcounts(sv{d}, bin_bounds(d, 1:n_bins(d)));
        end
        s.hspot = hs;

        ev = vislab.nat_stat_bayes.edge_features(Ev{k}, thr, sd1, nsd1, sd2, nsd2, fl_edge);
        he = cell(1, 20);
        for t = 1:numel(edge_dims)
            d = edge_dims(t);  he{d} = histcounts(ev{d}, bin_bounds(d, 1:n_bins(d)));
        end
        s.hedge = he;

        CFv{k} = s;
    end
    CF = reshape(CFv, nx, ny);
end
