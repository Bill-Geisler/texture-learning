function s5_train_decision_vars(cfg, ecc, eccb)
% S5_TRAIN_DECISION_VARS  Train the near/far decision-variable bounds from patch pairs.
%   s5_train_decision_vars(cfg, ecc)
%   s5_train_decision_vars(cfg, ecc, eccb)
%
%   Pipeline stage 5 (was nat_near_far_dv_2.m). Using the proximity proxy
%   (near = "same", far = "different"), computes the power, spot, edge and border
%   feature responses for all patch pairs, then trains quadratic decision bounds
%   (via classify_normals) for, in order: spot (h), edge (e), content (c =
%   power+spot+edge), border (b), and content). Saves the struct of all bounds to
%   data/models/decision_bounds_ecc<ecc>.mat.
%
%   Run `setup` first; run stages 2-4 before. Requires IntClassNorm
%   (classify_normals, quad2fun).
%
%   Inputs
%     cfg  - config struct (see config.m).
%     ecc  - eccentricity downsample factor of the patch pairs (1,2,4,8).
%     eccb - eccentricity of the histogram bin bounds to use (default 1, matching the
%            original; set to ecc to use same-eccentricity bins -- flagged for Geisler).
%
%   NOTE: power suppression b0 = 16 here (training) and now also in the content-
%   similarity computation (cfg.dv.power_suppress=16) -- Geisler unified them (2026-07;
%   content-sim was 10). Outliers (|log DV| >= 25) are dropped, as in the original.

    if nargin < 3 || isempty(eccb), eccb = 1; end
    psz    = cfg.patch.size / ecc;
    btype  = 5;                            % natural-image bound type
    b0     = 16;                           % weak-power suppression for training
    thresh = cfg.dv.edge_thresh;
    nh     = cfg.features.spot_dims;       % [1 13 14]
    ne     = cfg.features.edge_dv_dims;    % [5 9 10]

    feature_list = zeros(1, 20);  feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat        = zeros(1, 20);  cstat([1 5 6 7 9 10 11 13 14]) = btype;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, eccb, double(cfg.optics.apply));
    % (LMS->ABR rotation is auto-loaded by apply_color_rotation from the shared store)

    pp = load(fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc)), 'ptchn', 'ptchf');

    % response matrices: columns [rh1 rh2 rh3 re1 re3 re4 rp rb1 rb2], rows = kept pairs
    near = pair_responses(pp.ptchn, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);
    far  = pair_responses(pp.ptchf, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);

    % spot (h): features [1 13 14]
    dbndh = train_bound(near(:, 1:3), far(:, 1:3));
    dvh = quad2fun(dbndh, 0);

    % edge (e): features [5 9 10]
    dbnde = train_bound(near(:, 4:6), far(:, 4:6));
    dve = quad2fun(dbnde, 0);

    % content (c): [power, spot DV, edge DV]
    content_near = [near(:, 7), apply_dv(dvh, near(:, 1:3)), apply_dv(dve, near(:, 4:6))];
    content_far  = [far(:, 7),  apply_dv(dvh, far(:, 1:3)),  apply_dv(dve, far(:, 4:6))];
    dbndc = train_bound(content_near, content_far);
    dvc = quad2fun(dbndc, 0);

    % border (b): features [rb1 rb2]
    dbndb = train_bound(near(:, 8:9), far(:, 8:9));
    dvb = quad2fun(dbndb, 0);

    % border+content (bc): [content DV, border DV]
    bc_near = [apply_dv(dvc, content_near), apply_dv(dvb, near(:, 8:9))];
    bc_far  = [apply_dv(dvc, content_far),  apply_dv(dvb, far(:, 8:9))];
    dbndbc = train_bound(bc_near, bc_far);

    % save all bounds
    dbnd.h  = dbndh;
    dbnd.e  = dbnde;
    dbnd.c  = dbndc;
    dbnd.b  = dbndb;
    dbnd.bc = dbndbc;
    
    tag = num2str(ecc);
    reply = input(sprintf('s5: Save decision variables to disk and overwrite decision_bounds_ecc%s.mat? (y/n): ', tag), 's');
    if strcmpi(reply, 'y')
        save(fullfile(cfg.paths.models, ['decision_bounds_ecc' tag '.mat']), 'dbnd');
        fprintf('s5: trained + saved decision_bounds_ecc%s (%d near, %d far pairs)\n', tag, size(near,1), size(far,1));
    else
        fprintf('s5: skipped saving decision variables.\n');
    end
end

% ------------------------------------------------------------------------------
function R = pair_responses(patches, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg)
% Per-pair [rh1 rh2 rh3 re1 re3 re4 rp rb1 rb2], dropping outliers (|.|>=25 in rh/re/rp).
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    lo = -25; hi = 25;
    n_pairs = size(patches, 4);
    R = zeros(n_pairs, 9);
    n = 0;
    for i = 1:n_pairs
        % patches are stored as A (1-channel); patch_to_a passes them through. Older
        % 3-channel LMS files are normalized+rotated to A here instead (same result).
        p1 = vislab.nat_stat_bayes.patch_to_a(patches(1:psz, 1:psz, :, i),       m0, c0);
        p2 = vislab.nat_stat_bayes.patch_to_a(patches(1:psz, psz+1:2*psz, :, i), m0, c0);
        a1 = p1(:, :, 1);
        a2 = p2(:, :, 1);

        rp   = log(vislab.nat_stat_bayes.dv_power(a1, a2, b0, psz));
        spot = vislab.nat_stat_bayes.dv_spot_hist(p1, p2, psz, bin_bounds, n_bins, feature_list);
        rh = log([spot(nh(1)), spot(nh(2)), spot(nh(3))]);

        a1 = vislab.lib.cntrst_norm(a1, c0, psz);
        a2 = vislab.lib.cntrst_norm(a2, c0, psz);
        border = vislab.nat_stat_bayes.dv_border(a1, a2, psz, 2, cfg.dv.sd1, cfg.dv.nsd1, false);
        edge   = vislab.nat_stat_bayes.dv_edge_hist(a1, a2, thresh, bin_bounds, n_bins, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        re = log([edge(ne(1)), edge(ne(2)), edge(ne(3))]);

        check = [rh, re, rp];
        if all(check > lo) && all(check < hi)
            n = n + 1;
            R(n, :) = [rh, re, rp, border(1), border(2)];
        end
    end
    R = R(1:n, :);
end

% ------------------------------------------------------------------------------
function bd = train_bound(same, different)
% Sample-optimized quadratic bound between two response clouds.
    result = classify_normals(same, different, 'input_type', 'samp', 'plotmode', 0);
    bd = result.samp_opt_bd;
end

% ------------------------------------------------------------------------------
function y = apply_dv(dv_fun, X)
% Apply a quad2fun decision-variable handle to each row of X.
    y = zeros(size(X, 1), 1);
    for i = 1:size(X, 1)
        y(i) = dv_fun(X(i, :)');
    end
end
