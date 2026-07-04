function R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, coeff, dv, feature_list)
% NEIGHBOR_FAR_RESPONSES  Content/border/mutual DVs for near and far patch pairs.
%   R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, coeff, dv, feature_list)
%
%   For each reference patch (i,j) in the GTR image, forms two NEAR pairs (its
%   lower and right neighbours) and two FAR pairs (randomly sampled beyond
%   cfg.gtr.dcrit), and returns the content DV, border DV, and mutual similarity
%   for each, plus same/different ground truth. Shared by pipeline stages s6, s7.
%
%   Inputs
%     cfg          - config struct.
%     pimg         - GTR image in ABR-ready LMS space (from make_gtr_image).
%     rho          - mutual-similarity matrix (segmentation.mutual_similarity).
%     map          - szp x szp region-label map for this trial.
%     bin_bounds,n_bins - histogram bounds (nat_stat_bayes.load_bin_bounds).
%     coeff        - LMS->ABR rotation.
%     dv           - struct of trained DV function handles: dv.h, dv.e, dv.c, dv.b (from quad2fun).
%     feature_list - indicator vector of DV features to compute.
%
%   Output R (struct): rcn,rbn,rmn (near content/border/mutual), rcf,rbf,rmf (far),
%     same_near, same_far (1 = same region), ncnt (number of pairs of each kind).
%
%   Note: the reference patch's grayscale is contrast-normalized on a fresh copy
%   per pair (the original reused/re-normalized it in place across pairs — a
%   stateful bug; fixed here, flagged for Geisler).

    szp  = cfg.gtr.szp;
    psz  = size(pimg, 1) / szp;
    dcrit = cfg.gtr.dcrit;
    b0   = cfg.gtr.power_suppress;
    thr  = cfg.dv.edge_thresh;
    nh   = cfg.features.spot_dims;
    ne   = cfg.features.edge_dv_dims;
    m0   = cfg.norm.target_mean;
    c0   = cfg.norm.target_contrast;

    ncnt = 2 * (szp - 1)^2;
    [rcn, rbn, rmn] = deal(zeros(1, ncnt));
    [rcf, rbf, rmf] = deal(zeros(1, ncnt));
    same_near = zeros(1, ncnt);
    same_far  = zeros(1, ncnt);
    scnt = 0; dcnt = 0;

    for i = 1:szp-1
        for j = 1:szp-1
            ref_num = (i-1)*szp + j;
            p1 = prep(i, j);

            % near — lower neighbour (dir 1)
            scnt = scnt + 1;
            [rcn(scnt), rbn(scnt)] = pair_cb(p1, prep(i+1, j), 1);
            same_near(scnt) = map(i, j) == map(i+1, j);
            rmn(scnt) = rho(ref_num, i*szp + j);

            % near — right neighbour (dir 2)
            scnt = scnt + 1;
            [rcn(scnt), rbn(scnt)] = pair_cb(p1, prep(i, j+1), 2);
            same_near(scnt) = map(i, j) == map(i, j+1);
            rmn(scnt) = rho(ref_num, (i-1)*szp + j+1);

            % two far pairs (dir 2, matching the original's leftover dir)
            for f = 1:2
                dcnt = dcnt + 1;
                [x2, y2] = far_patch();
                [rcf(dcnt), rbf(dcnt)] = pair_cb(p1, prep(x2, y2), 2);
                same_far(dcnt) = map(i, j) == map(x2, y2);
                rmf(dcnt) = rho(ref_num, (x2-1)*szp + y2);
            end
        end
    end

    R = struct('rcn', rcn, 'rbn', rbn, 'rmn', rmn, 'rcf', rcf, 'rbf', rbf, 'rmf', rmf, ...
               'same_near', same_near, 'same_far', same_far, 'ncnt', ncnt);

    % ---- nested helpers (share cfg/dv/bounds/coeff via the parent workspace) ----
    function p = prep(r, c)
        x = (r-1)*psz + 1; y = (c-1)*psz + 1;
        p = vislib.ptch_norm(pimg(x:x+psz-1, y:y+psz-1, :), m0, c0, 3, 3);
        p = nat_stat_bayes.apply_color_rotation(p, coeff, psz);
    end

    function [rc, rb] = pair_cb(pa, pb, dir)
        a1 = pa(:, :, 1);  a2 = pb(:, :, 1);
        rp = log(nat_stat_bayes.dv_power(a1, a2, b0, psz));
        spot = nat_stat_bayes.dv_spot_hist(pa, pb, psz, bin_bounds, n_bins, feature_list);
        rh = dv.h(log([spot(nh(1)), spot(nh(2)), spot(nh(3))])');
        a1 = vislib.cntrst_norm(a1, c0, psz);      % fresh copy each pair (bug fix)
        a2 = vislib.cntrst_norm(a2, c0, psz);
        edge = nat_stat_bayes.dv_edge_hist(a1, a2, thr, bin_bounds, n_bins, cfg.dv.sd1, cfg.dv.nsd1, cfg.dv.sd2, cfg.dv.nsd2, feature_list);
        re = dv.e(log([edge(ne(1)), edge(ne(2)), edge(ne(3))])');
        border = nat_stat_bayes.dv_border(a1, a2, psz, dir, cfg.dv.sd1, cfg.dv.nsd1, false);
        rb = dv.b(border(1:2)');
        rc = dv.c([rp, rh, re]');
    end

    function [x2, y2] = far_patch()
        while true
            x2 = randi(szp); y2 = randi(szp);
            if sqrt((i - x2)^2 + (j - y2)^2) > dcrit
                return;
            end
        end
    end
end
