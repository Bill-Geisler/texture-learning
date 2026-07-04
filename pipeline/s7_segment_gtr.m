function out = s7_segment_gtr(cfg, method, itype, lev, n_images)
% S7_SEGMENT_GTR  Self-supervised segmentation of grown-texture-region images.
%   out = s7_segment_gtr(cfg, method, itype, lev, n_images)
%
%   Pipeline stage 7 (merges tex_grp_s_p_ms_SS_{ncm,ncbm}.m). For each GTR image:
%     1. Learn the per-image grouping criterion gcopt and mutual-similarity weight
%        wmopt from the near/far self-supervised discrimination task (same machinery
%        as stage s6 -- neighbor_far_responses + self_sup_decision + nearfar_score_grid).
%     2. Build the neighbour border+content similarity matrix, combine it with the
%        mutual similarity into mu = phi + wmopt*rho, and group the patches
%        (segmentation.group_patches) into regions.
%     3. Score the segmentation by counting exactly-correct regions
%        (segmentation.count_correct_regions), swept over the region-merge criterion
%        (mc) and a grouping-criterion offset (dgc) applied to gcopt.
%
%   method (which self-supervised decision variable sets gcopt/wmopt):
%     'nc'  - content-based: shift the content DV (was ..._ncm; self_sup 'c_shft').
%     'ncb' - border+content-based: trained bc DV, no shift (was ..._ncbm; 'bc_noshift').
%   itype:    texture dataset (default 3 = Brodatz).
%   lev:      eccentricity level (default 1).
%   n_images: number of GTR images to average over (default 120 = 10 seeds x 12).
%
%   Run `setup` first; requires stages 2,4,5 artifacts + IntClassNorm.
%   NOTE: the original hardcoded the neighbour distance dmin=64 px regardless of
%   level; here it is the actual patch size (= 64/lev), which matters only for
%   lev>1 (flagged for Geisler). pd=4 and levb=1 preserved from the originals.

    if nargin < 2 || isempty(method),   method = 'ncb'; end
    if nargin < 3 || isempty(itype),    itype = 3; end
    if nargin < 4 || isempty(lev),      lev = 1; end
    if nargin < 5 || isempty(n_images), n_images = 120; end
    mustBeMember(method, {'nc', 'ncb'});
    ss_method = struct('nc', 'c_shft', 'ncb', 'bc_noshift').(method);   % self_sup_decision token

    levb = 1;                                   % bin-bounds level (see note)
    cfg.optics.pupil_diameter = 4;              % pupil for the OTF (both originals)
    szp    = cfg.gtr.szp;
    psz    = cfg.patch.size / lev;              % patch size in pixels = neighbour distance
    ntexr  = cfg.gtr.n_regions;

    feature_list = zeros(1,20); feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat        = zeros(1,20); cstat([1 5 6 7 9 10 11 13 14]) = 5;

    % artifacts: rotation, bin bounds, trained DV handles (bc bound needed)
    if cfg.optics.apply, cdf_file = 'cdfs_abr_mo13_mo23_cs33_otf.mat'; else, cdf_file = 'cdfs_abr_mo13_mo23_cs33.mat'; end
    tmp = load(fullfile(cfg.paths.models, cdf_file), 'coeff');
    coeff = tmp.coeff;
    [n_bins, bin_bounds] = nat_stat_bayes.load_bin_bounds(cstat, levb, double(cfg.optics.apply));
    dv = load_dv_handles(cfg, lev, true);

    % texture sheets
    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, lev);

    % discrimination grid (to pick gcopt/wmopt) and segmentation sweeps
    gc_vec  = 0 : 0.8 : 8;        % grouping criterion
    wm_vec  = 0 : 0.8 : 9.6;      % mutual-similarity weight
    mc_vec  = 0 : 0.2 : 1;        % region-merge criterion
    cc_vec  = 1.1;               % confidence criterion (single value in the originals)
    dgc_vec = 0 : 0.25 : 2;      % grouping-criterion offset added to gcopt
    nmc = numel(mc_vec);  ndgc = numel(dgc_vec);  ncc = numel(cc_vec);

    ngtrimg = 12;                                % GTR images per random seed
    nseed   = ceil(n_images / ngtrimg);
    nregs   = zeros(nmc, ndgc, n_images);        % correct-region count per (mc, dgc, image)

    imgnum = 0;
    for seed = 1:nseed
        rng(seed - 1);                           % reseed per block of 12 (matches originals)
        for g = 1:ngtrimg
            imgnum = imgnum + 1;
            if imgnum > n_images, break; end

            % --- build one GTR image (rng order: textures -> masks -> far sampling) ---
            texs = gtr.sample_texture_ids(nimg, ntexr, 1);
            [~, map3] = gtr.grow_region_masks(szp, ntexr, 1, cfg.gtr.seed_radius, cfg.gtr.coverage);
            map = map3(:, :, 1);
            [pimg, px, py] = make_gtr_image(cfg, imgr, imgg, imgb, texs(1,:), map);

            % --- content similarity + mutual similarity ---
            phiall = segmentation.content_similarity_matrix(pimg, szp, psz, px, py, ...
                coeff, bin_bounds, n_bins, feature_list, dv.h, dv.e, dv.c, cfg);
            rho = segmentation.mutual_similarity(phiall);

            % --- 1. learn gcopt/wmopt from the self-supervised near/far task ---
            R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, coeff, dv, feature_list);
            [qbs, qbd] = self_sup_decision(ss_method, R, dv);
            [~, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
            [row_best, col_at] = max(pcnf, [], 2);   % best wm per gc
            [~, J] = max(row_best);                  % best gc
            gcopt = gc_vec(J);
            wmopt = wm_vec(col_at(J));

            % --- 2. neighbour similarity + combined mu = phi + wmopt*rho ---
            [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, szp, psz, px, py, ...
                psz, coeff, bin_bounds, n_bins, feature_list, dv, cfg);
            mu = (phi + wmopt * rho) .* (phi ~= 0);  % combine only on neighbouring pairs

            % --- 3. group + score, swept over dgc x mc (x cc) ---
            for l = 1:ndgc
                for k = 1:nmc
                    nreg = 0;
                    for c = 1:ncc
                        [~, ngrps, groups2d] = segmentation.group_patches(mu, dst, szp, ...
                            gcopt + dgc_vec(l), cc_vec(c), psz, px, py, phiall, mc_vec(k));
                        nreg = segmentation.count_correct_regions(map, ntexr, groups2d, ngrps, szp);
                    end
                    nregs(k, l, imgnum) = nreg;      % last cc (single cc in the originals)
                end
            end
        end
        if imgnum >= n_images, break; end
    end

    nregs = nregs(:, :, 1:min(imgnum, n_images));
    ngtr  = size(nregs, 3);
    exact = double(nregs == ntexr);

    out.nregs      = nregs;
    out.nregs_ave  = mean(nregs, 3);                 % mean correct regions per (mc, dgc)
    out.nregs5_ave = mean(exact, 3);                 % fraction of images fully correct
    out.nregs_sd   = std(nregs, 1, 3) / sqrt(ngtr);  % std error of correct regions
    out.nregs5_sd  = std(exact, 1, 3) / sqrt(ngtr);  % std error of fully-correct fraction
    out.mc = mc_vec;  out.dgc = dgc_vec;
    out.method = method;  out.itype = itype;  out.lev = lev;  out.n_images = ngtr;

    [best, idx] = max(out.nregs5_ave, [], 'all', 'linear');
    [ki, li] = ind2sub(size(out.nregs5_ave), idx);
    fprintf(['s7 (%s, itype %d, lev %d, %d imgs): peak fully-correct = %.1f%% ', ...
             'at merge=%.2f, dgc=%.2f (mean correct regions there = %.2f)\n'], ...
             method, itype, lev, ngtr, 100*best, mc_vec(ki), dgc_vec(li), out.nregs_ave(ki, li));
end
