function s2_learn_feature_priors(cfg)
% S2_LEARN_FEATURE_PRIORS  Measure the natural priors (prior CDFs of low-level features) from natural images.
%   s2_learn_feature_priors(cfg)
%
%   Pipeline stage 2 (was cdfs_of_features.m). Using the LMS->ABR rotation from
%   Pipeline stage 2. Using the LMS->ABR rotation from
%   stage 1, samples 1-deg patches from the natural images and accumulates:
%     * ABR opponent colour-channel values (a, b, r)
%     * 1st-derivative steerable responses (magnitude, orientation, mag x ori)
%     * 2nd-derivative steerable responses (magnitude, orientation, mag x ori)
%     * center-surround responses (ratio, small linear, large linear)
%   then computes the marginal cumulative distribution functions (the paper's
%   natural priors, Fig. 5). These 1D CDFs are the "natural priors" over features. Saves the result
%   to data/models/priors_abr_mo13_mo23_cs33[_otf].mat.
%
%   Run `setup` first; run stage 1 first (or ensure vislab-common/data/cps_lms2abr_otf.mat exists).
%
%   Fixes vs original: the large center-surround prior (Ncs4) is now computed from
%   its own data (csl4), not csl2 (a copy/paste bug) -- behaviour-changing for
%   feature 14; regenerate downstream artifacts. Uses corrected vislab.lib.otf_filter.
%   Diagnostic plots omitted.

    psz       = cfg.patch.size;
    maxval    = cfg.natural.max_val;
    m0        = cfg.norm.target_mean;
    c0        = cfg.norm.target_contrast;
    n_colr    = 3;
    norm_type = 3;                       % average-mean normalization
    n_bins    = 16000;                   % CDF resolution
    thresh    = 0;                       % keep gradient pixels above this (exclude exact zeros)
    sd1 = 1; nsd1 = 3; sd2 = 1; nsd2 = 3;
    swid = 3;                            % center-surround window (cs_type 4 uses a fixed 5x5)

    if cfg.optics.apply, xform_file = 'cps_lms2abr_otf.mat'; else, xform_file = 'cps_lms2abr.mat'; end
    s = load(fullfile(cfg.paths.data_root, xform_file), 'coeff');   % shared lab LMS->ABR transform
    coeff = s.coeff;

    files = list_natural_images(cfg);
    nsmp = ceil(cfg.natural.target_isolated_patches / numel(files));
    cap = numel(files) * nsmp * psz^2;   % generous preallocation upper bound

    lms   = zeros(cap, 3);   n_lms = 0;
    g1m   = zeros(cap, 1);   g1o = zeros(cap, 1);  g1mo = zeros(cap, 1);  n_g1 = 0;
    g2m   = zeros(cap, 1);   g2o = zeros(cap, 1);  g2mo = zeros(cap, 1);  n_g2 = 0;
    cs1v  = zeros(cap, 1);   n_cs1 = 0;
    cs2v  = zeros(cap, 1);   n_cs2 = 0;
    cs4v  = zeros(cap, 1);   n_cs4 = 0;

    for f = 1:numel(files)
        [~, fname, fext] = fileparts(files{f});
        fprintf('sampling %s\n', [fname, fext]);
        img_lms = vislab.nat_stat_bayes.source_to_lms(files{f}, cfg, struct('prescale', 255/maxval));
        [n_rows, n_cols, ~] = size(img_lms);

        for k = 1:nsmp
            x = randi(n_rows - psz);
            y = randi(n_cols - psz);
            patch = img_lms(x:x+psz-1, y:y+psz-1, :);
            patch = vislab.lib.ptch_norm(patch, m0, c0, norm_type, n_colr);

            % accumulate LMS pixel values (for the colour-channel CDFs after rotation)
            lms(n_lms+1 : n_lms+psz^2, :) = reshape(patch, [], 3);
            n_lms = n_lms + psz^2;

            % achromatic (A) channel in ABR space, contrast-normalized
            abr = vislab.nat_stat_bayes.apply_color_rotation(patch, coeff);
            a = vislab.lib.cntrst_norm(abr(:, :, 1), c0, psz);

            % 1st-derivative steerable responses (keep above-threshold)
            [gm, go] = vislab.lib.steerable_grad_response(a, sd1, nsd1);
            keep = gm > thresh;
            vals = gm(keep); ori = go(keep); m = numel(vals);
            g1m(n_g1+1:n_g1+m)  = vals;
            g1o(n_g1+1:n_g1+m)  = ori;
            g1mo(n_g1+1:n_g1+m) = vals .* ori;
            n_g1 = n_g1 + m;

            % 2nd-derivative steerable responses (all pixels)
            [gm2, go2] = vislab.lib.grad2_response(a, sd2, nsd2);
            m2 = numel(gm2);
            g2m(n_g2+1:n_g2+m2)  = gm2(:);
            g2o(n_g2+1:n_g2+m2)  = go2(:);
            g2mo(n_g2+1:n_g2+m2) = gm2(:) .* go2(:);
            n_g2 = n_g2 + m2;

            % center-surround responses (ratio, small linear, large linear)
            cs = vislab.lib.center_surround(a, swid, 1); nc = numel(cs); cs1v(n_cs1+1:n_cs1+nc) = cs(:); n_cs1 = n_cs1 + nc;
            cs = vislab.lib.center_surround(a, swid, 2); nc = numel(cs); cs2v(n_cs2+1:n_cs2+nc) = cs(:); n_cs2 = n_cs2 + nc;
            cs = vislab.lib.center_surround(a, swid, 4); nc = numel(cs); cs4v(n_cs4+1:n_cs4+nc) = cs(:); n_cs4 = n_cs4 + nc;
        end
    end

    % ABR colour-channel values
    abr_all = lms(1:n_lms, :) * coeff;

    % marginal CDFs (edges e*, cumulative N*)
    [Na, ea]   = histcounts(abr_all(:, 1),      n_bins, 'Normalization', 'cdf');
    [Nb, eb]   = histcounts(abr_all(:, 2),      n_bins, 'Normalization', 'cdf');
    [Nr, er]   = histcounts(abr_all(:, 3),      n_bins, 'Normalization', 'cdf');
    [Nm, em]   = histcounts(g1m(1:n_g1),        n_bins, 'Normalization', 'cdf');
    [No, eo]   = histcounts(g1o(1:n_g1),        n_bins, 'Normalization', 'cdf');
    [Nmo, emo] = histcounts(g1mo(1:n_g1),       n_bins, 'Normalization', 'cdf');
    [Nm2, em2] = histcounts(g2m(1:n_g2),        n_bins, 'Normalization', 'cdf');
    [No2, eo2] = histcounts(g2o(1:n_g2),        n_bins, 'Normalization', 'cdf');
    [Nmo2,emo2]= histcounts(g2mo(1:n_g2),       n_bins, 'Normalization', 'cdf');
    [Ncs1,ecs1]= histcounts(cs1v(1:n_cs1),      n_bins, 'Normalization', 'cdf');
    [Ncs2,ecs2]= histcounts(cs2v(1:n_cs2),      n_bins, 'Normalization', 'cdf');
    [Ncs4,ecs4]= histcounts(cs4v(1:n_cs4),      n_bins, 'Normalization', 'cdf');  % fix: was cs2v

    if cfg.optics.apply, out_file = 'priors_abr_mo13_mo23_cs33_otf.mat'; else, out_file = 'priors_abr_mo13_mo23_cs33.mat'; end
    out_path = fullfile(cfg.paths.models, out_file);
    reply = input(sprintf('s2: Save feature priors to disk and overwrite %s? (y/n): ', out_file), 's');
    if strcmpi(reply, 'y')
        save(out_path, 'ea','Na','eb','Nb','er','Nr','em','Nm','eo','No','emo','Nmo', ...
            'em2','Nm2','eo2','No2','emo2','Nmo2','ecs1','Ncs1','ecs2','Ncs2','ecs4','Ncs4','coeff');
        fprintf('s2: saved feature priors to %s (%d patches from %d images)\n', out_path, numel(files)*nsmp, numel(files));
    else
        fprintf('s2: skipped saving feature priors.\n');
    end
end
