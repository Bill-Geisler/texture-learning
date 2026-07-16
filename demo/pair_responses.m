function R = pair_responses(patches, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg)
% PAIR_RESPONSES  Per-pair [rh1 rh2 rh3 re1 re3 re4 rp rb1 rb2], dropping outliers
%   (|.| >= 25 in rh/re/rp). Shared by compute_demo_responses and the Stage 5 plots.
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    lo = -25; hi = 25;
    n_pairs = size(patches, 4);
    R = zeros(n_pairs, 9);
    n = 0;
    for i = 1:n_pairs
        % Stored pairs are A (1-channel) -> passthrough; the synth fallback builds
        % 3-channel patches -> normalized+rotated to A here (same as before).
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
