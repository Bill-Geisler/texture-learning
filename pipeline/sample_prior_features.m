function s = sample_prior_features(img_lms, nsmp, psz, cfg, coeff)
% SAMPLE_PRIOR_FEATURES  Sample nsmp isolated patches from one LMS image and return
%   the raw feature values used to build the natural priors (Stage 23). This is the
%   single definition of that per-image sampling, used by s23_learn_priors_and_pairs.
%
%   Inputs
%     img_lms - [H x W x 3] LMS image (at the target eccentricity).
%     nsmp    - number of isolated patches to sample from this image.
%     psz     - patch size in pixels (cfg.patch.size / ecc).
%     cfg     - config struct (normalization).
%     coeff   - LMS->ABR rotation (from Stage 1).
%
%   Output s (columns of sampled values for this image):
%     .lms  [n x 3]      normalized LMS pixels (for the ABR colour-channel CDFs)
%     .g1m .g1o .g1mo    1st-derivative steerable magnitude / orientation / (m x o)
%     .g2m .g2o .g2mo    2nd-derivative steerable magnitude / orientation / (m x o)
%     .cs1 .cs2 .cs4     center-surround ratio / small-linear / large-linear

    c0        = cfg.norm.target_contrast;
    thresh    = 0;                       % keep gradient pixels above this (exclude exact zeros)
    sd1 = cfg.dv.sd1; nsd1 = cfg.dv.nsd1; sd2 = cfg.dv.sd2; nsd2 = cfg.dv.nsd2;
    swid = 3;                            % center-surround window (cs_type 4 uses a fixed 5x5)

    % isolated patches (mean-normalized), via the shared sampler used by stage 1b too
    patches = sample_isolated_patches(img_lms, nsmp, psz, cfg);
    cap = nsmp * psz^2;                  % generous per-image upper bound

    lms   = zeros(cap, 3);   n_lms = 0;
    g1m   = zeros(cap, 1);   g1o = zeros(cap, 1);  g1mo = zeros(cap, 1);  n_g1 = 0;
    g2m   = zeros(cap, 1);   g2o = zeros(cap, 1);  g2mo = zeros(cap, 1);  n_g2 = 0;
    cs1v  = zeros(cap, 1);   n_cs1 = 0;
    cs2v  = zeros(cap, 1);   n_cs2 = 0;
    cs4v  = zeros(cap, 1);   n_cs4 = 0;

    for k = 1:nsmp
        patch = patches(:, :, :, k);

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

    s.lms  = lms(1:n_lms, :);
    s.g1m  = g1m(1:n_g1);    s.g1o = g1o(1:n_g1);    s.g1mo = g1mo(1:n_g1);
    s.g2m  = g2m(1:n_g2);    s.g2o = g2o(1:n_g2);    s.g2mo = g2mo(1:n_g2);
    s.cs1  = cs1v(1:n_cs1);  s.cs2 = cs2v(1:n_cs2);  s.cs4  = cs4v(1:n_cs4);
end
