function s4_optimize_bins(cfg, dim, ecc)
% S4_OPTIMIZE_BINS  Learn adaptive-histogram bin bounds for one feature/eccentricity.
%   s4_optimize_bins(cfg, dim, ecc)
%
%   Pipeline stage 4 (was opt_bins_nat.m + test_bnds_nat.m). Using the prior CDF
%   of feature `dim` (from stage 2) and the near/far patch pairs (stage 3),
%   greedily splits histogram bins (adaptive histogram equalization): a split is
%   kept if it reduces the proximity (near-vs-far) classification error by more
%   than a criterion fraction. The learned bounds are stored in ONE consolidated
%   file holding all features x eccentricities -- data/models/AHEO_bins.mat
%   (optics applied) or AHE_bins.mat (no optics). Each call to this function
%   updates the (dim, ecc) slot of that file (read-modify-write). File structure:
%     bin_bounds - cell [n_features x n_ecc], bin_bounds{f,e} = column of bin edges
%     n_bins     - double [n_features x n_ecc], counts
%     eccs     - 1 x n_ecc eccentricities (columns); btype - 5 (natural).
%
%   Run `setup` first; run stages 2 (CDFs) and 3 (patch pairs for `ecc`) before.
%   Requires the IntClassNorm toolbox (classify_normals).
%
%   Inputs
%     cfg - config struct (see config.m).
%     dim - feature dimension (1,5,6,7,9,10,11,13,14; see cfg.features.names).
%     ecc - eccentricity downsample factor (1,2,4,8).

    btype   = 5;                          % bound type: natural images = 5
    err_crit = 0.002;                     % min fractional error reduction to keep a split
    max_bins = 100;
    psz = cfg.patch.size / ecc;

    % --- prior CDF for this feature (LMS->ABR rotation auto-loaded by apply_color_rotation) ---
    if cfg.optics.apply, cdf_file = 'cdfs_abr_mo13_mo23_cs33_otf.mat'; else, cdf_file = 'cdfs_abr_mo13_mo23_cs33.mat'; end
    cdfs = load(fullfile(cfg.paths.models, cdf_file));
    [cdf_x, cdf_p] = cdf_for_dim(cdfs, dim);

    % --- near/far patch pairs (combined, from stage 3) ---
    pp = load(fullfile(cfg.paths.derived, sprintf('patch_pairs_%d.mat', ecc)), 'ptchn', 'ptchf');
    ptchn = pp.ptchn;
    ptchf = pp.ptchf;

    % --- adaptive histogram equalization: greedy bin splitting ---
    n_edges = numel(cdf_p);
    n_bins = 2;
    grown = n_bins;
    [bounds, indices] = vislab.nat_stat_bayes.make_bins(cdf_x, cdf_p, n_bins);
    bounds(1) = cdf_x(1);
    bounds(n_bins + 1) = cdf_x(n_edges);

    frozen = zeros(max_bins, 1);          % 1 = bin will not be split further
    prev_err = 1.0;

    done = false;
    while ~done
        n_bins = grown;
        offset = 0;
        for i = 1:n_bins
            if frozen(i) == 0
                [cand_bounds, cand_indices] = vislab.nat_stat_bayes.find_bin_bound(bounds, indices, grown, i + offset, cdf_x, cdf_p);
                err = proximity_error(dim, cand_bounds, ptchn, ptchf, psz, cfg);
                if (prev_err - err) / prev_err > err_crit
                    bounds = cand_bounds;
                    indices = cand_indices;
                    prev_err = err;
                    grown = grown + 1;
                    offset = offset + 1;
                    for j = grown:-1:i
                        if frozen(j) == 1
                            frozen(j) = 0;
                            frozen(j + 1) = 1;
                        end
                    end
                else
                    frozen(i) = 1;
                end
            end
        end
        if n_bins == grown
            done = true;
        end
    end
    nbnds = n_bins + 1;
    bnds = bounds(:);                      % column of bin edges for this (dim, ecc)

    % --- store into the consolidated bin-bounds file (one file for all features x
    %     eccentricities; see load_bin_bounds for the exact structure). Each
    %     call updates just the (dim, ecc) slot: read the file if it exists, set the
    %     slot, write back. (Sequential pipeline, so no read/write race.)
    if cfg.optics.apply, file = 'AHEO_bins.mat'; else, file = 'AHE_bins.mat'; end
    out_path = fullfile(cfg.paths.models, file);
    [bin_bounds, n_bins_all, eccs] = load_or_init_bounds(out_path);
    ecc_idx = find(eccs == ecc, 1);
    if isempty(ecc_idx)
        eccs(end+1) = ecc;               % new eccentricity column
        ecc_idx = numel(eccs);
    end
    bin_bounds{dim, ecc_idx} = bnds;
    n_bins_all(dim, ecc_idx) = nbnds;
    out = struct('bin_bounds', {bin_bounds}, 'n_bins', n_bins_all, 'eccs', eccs, 'btype', btype);
    save(out_path, '-struct', 'out');
    fprintf('s4: dim %d ecc %d -> %d bounds; updated %s\n', dim, ecc, nbnds, out_path);
end

% ------------------------------------------------------------------------------
function [bin_bounds, n_bins_all, eccs] = load_or_init_bounds(out_path)
% Load the consolidated bounds file if it exists, else initialize empty containers
% (rows indexed by paper feature number 1..14; columns grow as eccs are added).
    n_features = 14;
    if isfile(out_path)
        S = load(out_path, 'bin_bounds', 'n_bins', 'eccs');
        bin_bounds = S.bin_bounds;
        n_bins_all = S.n_bins;
        eccs     = S.eccs;
    else
        bin_bounds = cell(n_features, 0);
        n_bins_all = zeros(n_features, 0);
        eccs     = [];
    end
end

% ------------------------------------------------------------------------------
function [cdf_x, cdf_p] = cdf_for_dim(cdfs, dim)
% Map a feature dimension to its prior CDF (edges, cumulative prob) in the file.
    switch dim
        case 1,  cdf_x = cdfs.ea;   cdf_p = cdfs.Na;
        case 2,  cdf_x = cdfs.eb;   cdf_p = cdfs.Nb;
        case 3,  cdf_x = cdfs.er;   cdf_p = cdfs.Nr;
        case 5,  cdf_x = cdfs.em;   cdf_p = cdfs.Nm;
        case 6,  cdf_x = cdfs.eo;   cdf_p = cdfs.No;
        case 7,  cdf_x = cdfs.emo;  cdf_p = cdfs.Nmo;
        case 9,  cdf_x = cdfs.em2;  cdf_p = cdfs.Nm2;
        case 10, cdf_x = cdfs.eo2;  cdf_p = cdfs.No2;
        case 11, cdf_x = cdfs.emo2; cdf_p = cdfs.Nmo2;
        case 12, cdf_x = cdfs.ecs1; cdf_p = cdfs.Ncs1;
        case 13, cdf_x = cdfs.ecs2; cdf_p = cdfs.Ncs2;
        case 14, cdf_x = cdfs.ecs4; cdf_p = cdfs.Ncs4;
        otherwise
            error('s4:badDim', 'No CDF for feature dimension %d.', dim);
    end
end

% ------------------------------------------------------------------------------
function err = proximity_error(dim, cand_bounds, ptchn, ptchf, psz, cfg)
% Near-vs-far classification error for one feature under candidate bin bounds
% (was test_bnds_nat.m). Uses the proximity proxy: near = "same", far = "different".
    rng(cfg.seed);
    max_dim = 20;
    is_edge = dim > 3 && dim <= 11;

    n_bins = zeros(1, max_dim);
    n_bins(dim) = numel(cand_bounds);
    bin_bounds = zeros(max_dim, n_bins(dim));
    bin_bounds(dim, 1:n_bins(dim)) = cand_bounds;

    feature_list = zeros(1, max_dim);
    feature_list(dim) = 1;

    near = dim_response(ptchn, dim, is_edge, bin_bounds, n_bins, feature_list, psz, cfg);
    far  = dim_response(ptchf, dim, is_edge, bin_bounds, n_bins, feature_list, psz, cfg);

    result = classify_normals(near, far, 'input_type', 'samp', 'plotmode', 0);
    err = result.samp_opt_err;
end

% ------------------------------------------------------------------------------
function vals = dim_response(patches, dim, is_edge, bin_bounds, n_bins, feature_list, psz, cfg)
% Single-feature log decision-variable response over all patch pairs,
% dropping outliers below -25 (as in the original).
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    n_pairs = size(patches, 4);
    vals = zeros(n_pairs, 1);
    n = 0;
    for i = 1:n_pairs
        p1 = vislab.nat_stat_bayes.apply_color_rotation(vislab.lib.ptch_norm(patches(1:psz, 1:psz, :, i),       m0, c0, 3, 3));
        p2 = vislab.nat_stat_bayes.apply_color_rotation(vislab.lib.ptch_norm(patches(1:psz, psz+1:2*psz, :, i), m0, c0, 3, 3));
        if is_edge
            a1 = vislab.lib.cntrst_norm(p1(:, :, 1), c0, psz);
            a2 = vislab.lib.cntrst_norm(p2(:, :, 1), c0, psz);
            dv = vislab.nat_stat_bayes.dv_edge_hist(a1, a2, 0, bin_bounds, n_bins, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        else
            dv = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, psz, bin_bounds, n_bins, feature_list);
        end
        r = log(dv(dim));
        if r >= -25                       % drop -inf / extreme outliers
            n = n + 1;
            vals(n) = r;
        end
    end
    vals = vals(1:n);
end
