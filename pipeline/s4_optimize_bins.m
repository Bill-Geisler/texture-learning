function s4_optimize_bins(cfg, dims, ecc, autosave)
% S4_OPTIMIZE_BINS  Learn adaptive-histogram bin bounds for feature(s)/eccentricity.
%   s4_optimize_bins(cfg, dims, ecc)
%   s4_optimize_bins(cfg, dims, ecc, autosave)
%
%   autosave (optional) - true/false to save/skip without asking (used by
%   run_demo, which confirms once up front); omit to be asked interactively.
%
%   Pipeline stage 4 (was opt_bins_nat.m + test_bnds_nat.m). Using the prior CDF
%   of features in `dims` (from stage 2) and the near/far patch pairs (stage 3),
%   greedily splits histogram bins (adaptive histogram equalization): a split is
%   kept if it reduces the proximity (near-vs-far) classification error by more
%   than a criterion fraction. The learned bounds are stored in ONE consolidated
%   file holding all features x eccentricities -- data/models/AHEO_bins.mat
%   (optics applied) or AHE_bins.mat (no optics). Each call to this function
%   updates the (dims, ecc) slots of that file (read-modify-write). File structure:
%     bin_bounds - cell [n_features x n_ecc], bin_bounds{f,e} = column of bin edges
%     n_bins     - double [n_features x n_ecc], counts
%     eccs     - 1 x n_ecc eccentricities (columns); btype - 5 (natural).
%
%   Run `setup` first; run stages 2 (priors) and 3 (patch pairs for `ecc`) before.
%   Requires the IntClassNorm toolbox (classify_normals).
%
%   Inputs
%     cfg  - config struct (see config.m).
%     dims - feature dimension(s) (e.g. [1 5 9 10 13 14]; see cfg.features.names).
%     ecc  - eccentricity downsample factor (1,2,4,8).

    btype   = 5;                          % bound type: natural images = 5
    err_crit = 0.002;                     % min fractional error reduction to keep a split
    max_bins = 100;
    psz = cfg.patch.size / ecc;

    % --- load priors and patch pairs ONCE for all dims ---
    priors = load(fullfile(cfg.paths.models, prior_filename(cfg, ecc)));

    pp = load(fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc)), 'ptchn', 'ptchf');
    ptchn = pp.ptchn;
    ptchf = pp.ptchf;

    % --- store into the consolidated bin-bounds file
    if cfg.optics.apply, file = 'AHEO_bins.mat'; else, file = 'AHE_bins.mat'; end
    out_path = fullfile(cfg.paths.models, file);
    [bin_bounds, n_bins_all, eccs] = load_or_init_bounds(out_path);
    ecc_idx = find(eccs == ecc, 1);
    if isempty(ecc_idx)
        eccs(end+1) = ecc;               % new eccentricity column
        ecc_idx = numel(eccs);
    end

    for dim = dims(:)'
        fprintf('s4: Optimizing adaptive bins for feature "%s"...\n', cfg.features.names{dim});
        [prior_x, prior_p] = prior_for_dim(priors, dim);

        % Featurize each patch ONCE (bin-independent). The greedy search below only
        % re-bins these values per candidate, instead of recomputing the steerable /
        % center-surround responses for every pair on every candidate split.
        [near_a, near_b] = feature_values(ptchn, dim, psz, cfg);
        [far_a,  far_b]  = feature_values(ptchf, dim, psz, cfg);

        % --- adaptive histogram equalization: greedy bin splitting ---
        n_edges = numel(prior_p);
        n_bins = 2;
        grown = n_bins;
        [bounds, indices] = vislab.nat_stat_bayes.make_bins(prior_x, prior_p, n_bins);
        bounds(1) = prior_x(1);
        bounds(n_bins + 1) = prior_x(n_edges);

        frozen = zeros(max_bins, 1);          % 1 = bin will not be split further
        prev_err = 1.0;

        done = false;
        while ~done
            n_bins = grown;
            offset = 0;
            for i = 1:n_bins
                if frozen(i) == 0
                    [cand_bounds, cand_indices] = vislab.nat_stat_bayes.find_bin_bound(bounds, indices, grown, i + offset, prior_x, prior_p);
                    err = proximity_error(cand_bounds, near_a, near_b, far_a, far_b, cfg);
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
        bin_bounds{dim, ecc_idx} = bounds(:);  % column of bin edges for this (dim, ecc)
        n_bins_all(dim, ecc_idx) = nbnds;
    end

    out = struct('bin_bounds', {bin_bounds}, 'n_bins', n_bins_all, 'eccs', eccs, 'btype', btype);
    if numel(dims) > 1
        dim_str = sprintf('[%s]', num2str(dims(:)'));
    else
        dim_str = num2str(dims);
    end
    if nargin < 4 || isempty(autosave)
        reply = input(sprintf('s4: Save bin bounds to disk and overwrite %s for dims %s? (y/n): ', file, dim_str), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(out_path, '-struct', 'out');
        fprintf('s4: dims %s ecc %d -> updated %s\n', dim_str, ecc, out_path);
    else
        fprintf('s4: skipped saving bin bounds for dims %s.\n', dim_str);
    end
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
function [prior_x, prior_p] = prior_for_dim(priors, dim)
% Map a feature dimension to its prior CDF (edges, cumulative prob) in the file.
    switch dim
        case 1,  prior_x = priors.ea;   prior_p = priors.Na;
        case 2,  prior_x = priors.eb;   prior_p = priors.Nb;
        case 3,  prior_x = priors.er;   prior_p = priors.Nr;
        case 5,  prior_x = priors.em;   prior_p = priors.Nm;
        case 6,  prior_x = priors.eo;   prior_p = priors.No;
        case 7,  prior_x = priors.emo;  prior_p = priors.Nmo;
        case 9,  prior_x = priors.em2;  prior_p = priors.Nm2;
        case 10, prior_x = priors.eo2;  prior_p = priors.No2;
        case 11, prior_x = priors.emo2; prior_p = priors.Nmo2;
        case 12, prior_x = priors.ecs1; prior_p = priors.Ncs1;
        case 13, prior_x = priors.ecs2; prior_p = priors.Ncs2;
        case 14, prior_x = priors.ecs4; prior_p = priors.Ncs4;
        otherwise
            error('s4:badDim', 'No CDF for feature dimension %d.', dim);
    end
end

% ------------------------------------------------------------------------------
function [Va, Vb] = feature_values(patches, dim, psz, cfg)
% Precompute, ONCE per feature, the per-pair raw values that get histogrammed for
% `dim` on both patches of every pair -- the bin-INDEPENDENT half of the DV. Uses
% the same featurizers as the decision variables (vislab spot_features /
% edge_features), so the values are identical to what dv_spot_hist / dv_edge_hist
% would compute; only the (bin-dependent) histogram + LLR is deferred to eval_r.
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    is_edge = dim > 3 && dim <= 11;
    feature_list = zeros(1, 20);
    feature_list(dim) = 1;
    n_pairs = size(patches, 4);
    Va = cell(n_pairs, 1);
    Vb = cell(n_pairs, 1);
    for i = 1:n_pairs
        % patches are stored as A (1-channel); patch_to_a passes them through. Older
        % 3-channel LMS files are normalized+rotated to A here instead (same result).
        p1 = vislab.nat_stat_bayes.patch_to_a(patches(1:psz, 1:psz, :, i),       m0, c0);
        p2 = vislab.nat_stat_bayes.patch_to_a(patches(1:psz, psz+1:2*psz, :, i), m0, c0);
        if is_edge
            a1 = vislab.lib.cntrst_norm(p1(:, :, 1), c0, psz);
            a2 = vislab.lib.cntrst_norm(p2(:, :, 1), c0, psz);
            fa = vislab.nat_stat_bayes.edge_features(a1, 0, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
            fb = vislab.nat_stat_bayes.edge_features(a2, 0, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        else
            fa = vislab.nat_stat_bayes.spot_features(p1, psz, feature_list);
            fb = vislab.nat_stat_bayes.spot_features(p2, psz, feature_list);
        end
        Va{i} = fa{dim};
        Vb{i} = fb{dim};
    end
end

% ------------------------------------------------------------------------------
function err = proximity_error(cand_bounds, near_a, near_b, far_a, far_b, cfg)
% Near-vs-far classification error for one feature under candidate bin bounds, from
% the precomputed per-pair values (was test_bnds_nat.m). near = "same", far =
% "different" (proximity proxy).
    rng(cfg.seed);
    near = eval_r(near_a, near_b, cand_bounds);
    far  = eval_r(far_a,  far_b,  cand_bounds);
    % samp_balance=true: near/far counts differ (independent outlier rejection above),
    % but the proximity proxy is symmetric, so score the class-balanced error rather
    % than the count-weighted one that would favour the majority class.
    result = classify_normals(near, far, 'input_type', 'samp', 'plotmode', 0, 'samp_balance', true);
    err = result.samp_opt_err;
end

% ------------------------------------------------------------------------------
function r = eval_r(Va, Vb, edges)
% Per-pair single-feature log LLR under candidate bin `edges`, dropping outliers
% below -25 (as in the original). Only re-bins the precomputed values -- the
% multinomial LLR of the two patches' histograms -- with no feature recomputation.
    n_pairs = numel(Va);
    r = zeros(n_pairs, 1);
    n = 0;
    for i = 1:n_pairs
        N1 = histcounts(Va{i}, edges);
        N2 = histcounts(Vb{i}, edges);
        rv = log(vislab.nat_stat_bayes.multinomial_llr(N1, N2));
        if rv >= -25                       % drop -inf / extreme outliers
            n = n + 1;
            r(n) = rv;
        end
    end
    r = r(1:n);
end
