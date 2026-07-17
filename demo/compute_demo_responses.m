function [near, far] = compute_demo_responses(cfg, ecc)
% COMPUTE_DEMO_RESPONSES  Per-pair power/spot/edge/border responses for the Stage 5
%   plots in QUICK mode. Since quick mode uses the shipped bounds without training
%   (and so has no training points to reuse), it samples near/far pairs from a single
%   natural image via sample_demo_pairs (same optics/domain/distance rules as Stage 3)
%   and computes their responses. (Full mode instead reuses the exact pairs s5
%   trained on.)
    btype  = 5;
    b0     = cfg.dv.power_suppress;
    thresh = cfg.dv.edge_thresh;
    psz    = cfg.patch.size / ecc;
    nh     = cfg.features.spot_dims;
    ne     = cfg.features.edge_dv_dims;

    feature_list = zeros(1, 20);  feature_list([1 5 9 10 13 14]) = 1;   % spot [1 13 14] + edge DV [5 9 10]; 6/7/11 unused
    cstat        = zeros(1, 20);  cstat([1 5 9 10 13 14]) = btype;
    eccb = 1;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, eccb, double(cfg.optics.apply));

    [ptchn_sub, ptchf_sub] = sample_demo_pairs(cfg, ecc);
    if isempty(ptchn_sub)
        fprintf('No natural images found; skipping Stage 5 response plots.\n');
        near = []; far = []; return;
    end

    near = pair_responses(ptchn_sub, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);
    far  = pair_responses(ptchf_sub, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);
end
