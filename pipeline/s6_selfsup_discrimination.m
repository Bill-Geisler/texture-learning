function out = s6_selfsup_discrimination(cfg, method, itype, lev, ntrl)
% S6_SELFSUP_DISCRIMINATION  Per-image self-supervised texture discrimination.
%   out = s6_selfsup_discrimination(cfg, method, itype, lev)
%
%   Pipeline stage 6 (merges self_sup_train_bnd_{bc,bc_shft,c_shft}.m). For each
%   GTR image, computes content/border/mutual DVs for near & far pairs, applies a
%   per-image self-supervised step, and sweeps the grouping criterion (gc) x
%   mutual-similarity weight (wm) to produce near-far and same-different accuracy
%   surfaces. Returns the trial-averaged surfaces.
%
%   method:
%     'bc'      - retrain the border+content bound on this image (classify_normals).
%     'bc_shft' - load the trained bc bound; learn a scalar shift of the bc DV.
%     'c_shft'  - load the trained bc bound; learn a scalar shift of the content DV.
%   itype: texture dataset (default per method: bc/bc_shft -> 3 Brodatz, c_shft -> 1 Pertex).
%   lev:   eccentricity level (default 1).
%
%   Run `setup` first; requires stages 2,4,5 artifacts + IntClassNorm.
%   NOTE: pd differs by method (bc=4, others=8) and levb=1 for bins — preserved,
%   flagged for Geisler (see QUESTIONS_FOR_GEISLER.md).

    mustBeMember(method, {'bc', 'bc_shft', 'c_shft'});
    switch method
        case 'bc',      mp = struct('pd',4,'itype',3,'dgc',0.4,'gcmx',4,'dms',0.4,'msmx',4,'load_bc',false);
        case 'bc_shft', mp = struct('pd',8,'itype',3,'dgc',0.8,'gcmx',8,'dms',0.8,'msmx',8,'load_bc',true);
        case 'c_shft',  mp = struct('pd',8,'itype',1,'dgc',0.8,'gcmx',8,'dms',0.8,'msmx',8,'load_bc',true);
    end
    if nargin < 3 || isempty(itype), itype = mp.itype; end
    if nargin < 4 || isempty(lev),   lev = 1; end
    if nargin < 5 || isempty(ntrl), ntrl = 40; end   % trials per session
    levb = 1;                                   % bin-bounds level (see note)
    cfg.optics.pupil_diameter = mp.pd;          % method-specific pupil for the OTF

    feature_list = zeros(1,20); feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat        = zeros(1,20); cstat([1 5 6 7 9 10 11 13 14]) = 5;

    % artifacts: rotation, bin bounds, trained DV handles
    if cfg.optics.apply, cdf_file = 'cdfs_abr_mo13_mo23_cs33_otf.mat'; else, cdf_file = 'cdfs_abr_mo13_mo23_cs33.mat'; end
    tmp = load(fullfile(cfg.paths.models, cdf_file), 'coeff');
    coeff = tmp.coeff;
    [n_bins, bin_bounds] = nat_stat_bayes.load_bin_bounds(cstat, levb, double(cfg.optics.apply));
    dv = load_dv_handles(cfg, lev, mp.load_bc);

    % texture sheets + trial stimuli
    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, lev);
    texs = gtr.sample_texture_ids(nimg, cfg.gtr.n_regions, ntrl);
    [~, maps] = gtr.grow_region_masks(cfg.gtr.szp, cfg.gtr.n_regions, ntrl, cfg.gtr.seed_radius, cfg.gtr.coverage);

    % criterion / mutual-similarity-weight grid
    gc_vec = 0:mp.dgc:mp.gcmx;   ngc = numel(gc_vec);
    wm_vec = 0:mp.dms:mp.msmx;   nms = numel(wm_vec);
    [pc, pcs, pcd, pcnf] = deal(zeros(ngc, nms, ntrl));

    for trl = 1:ntrl
        [pimg, px, py] = make_gtr_image(cfg, imgr, imgg, imgb, texs(trl,:), maps(:,:,trl));
        phiall = segmentation.content_similarity_matrix(pimg, cfg.gtr.szp, size(pimg,1)/cfg.gtr.szp, ...
            px, py, coeff, bin_bounds, n_bins, feature_list, dv.h, dv.e, dv.c, cfg);
        rho = segmentation.mutual_similarity(phiall);
        R = neighbor_far_responses(cfg, pimg, rho, maps(:,:,trl), bin_bounds, n_bins, coeff, dv, feature_list);

        % per-image self-supervised step -> combined near/far decision variables qbs/qbd
        [qbs, qbd] = self_sup_decision(method, R, dv);

        % sweep gc (outer) x wm (inner)
        for j = 1:ngc
            gc = gc_vec(j);
            for k = 1:nms
                wm = wm_vec(k);
                [pc(j,k,trl), pcs(j,k,trl), pcd(j,k,trl), pcnf(j,k,trl)] = ...
                    score(qbs, qbd, R.rmn, R.rmf, R.same_near, R.same_far, gc, wm);
            end
        end
    end

    out.pcav   = mean(pc,   3);
    out.pcsav  = mean(pcs,  3);
    out.pcdav  = mean(pcd,  3);
    out.pcnfav = mean(pcnf, 3);
    out.gc = gc_vec;  out.wm = wm_vec;  out.method = method;  out.itype = itype;  out.lev = lev;
    fprintf('s6 (%s, itype %d, lev %d): mean near-far PC max %.3f\n', method, itype, lev, max(out.pcav,[],'all'));
end

% ------------------------------------------------------------------------------
function dv = load_dv_handles(cfg, lev, load_bc)
    tag = num2str(lev);
    dv.h = handle_for('dbndh');
    dv.e = handle_for('dbnde');
    dv.c = handle_for('dbndc');
    dv.b = handle_for('dbndb');
    if load_bc
        dv.bc = handle_for('dbndbc');
    end
    function h = handle_for(var)
        s = load(fullfile(cfg.paths.models, [var 'NO' tag '.mat']), var);
        h = quad2fun(s.(var), 0);
    end
end

% ------------------------------------------------------------------------------
function [qbs, qbd] = self_sup_decision(method, R, dv)
% Returns the combined border+content decision variable for near (qbs) and far
% (qbd) pairs after the per-image self-supervised step.
    n = R.ncnt;
    qbs = zeros(1, n);  qbd = zeros(1, n);
    switch method
        case 'bc'                                   % refit the bc bound on this image
            bd = classify_normals([R.rbn', R.rcn'], [R.rbf', R.rcf'], 'input_type', 'samp', 'plotmode', 0);
            dvbc = quad2fun(bd.samp_opt_bd, 0);
            for i = 1:n
                qbs(i) = dvbc([R.rbn(i), R.rcn(i)]');
                qbd(i) = dvbc([R.rbf(i), R.rcf(i)]');
            end
        case 'bc_shft'                              % shift the pre-trained bc DV
            rbcn = apply_bc(dv.bc, R.rbn, R.rcn);
            rbcf = apply_bc(dv.bc, R.rbf, R.rcf);
            copt = best_criterion(rbcn, rbcf, 5);
            qbs = rbcn - copt;
            qbd = rbcf - copt;
        case 'c_shft'                               % shift the content DV, then bc bound
            rcn = nan_to_zero(R.rcn);  rcf = nan_to_zero(R.rcf);
            rbn = nan_to_zero(R.rbn);  rbf = nan_to_zero(R.rbf);
            copt = best_criterion(rcn, rcf, 1);
            for i = 1:n
                qbs(i) = dv.bc([rbn(i), rcn(i) - copt]');
                qbd(i) = dv.bc([rbf(i), rcf(i) - copt]');
            end
    end
end

function v = apply_bc(dvbc, rb, rc)
    v = zeros(1, numel(rb));
    for i = 1:numel(rb)
        v(i) = dvbc([rb(i), rc(i)]');           % border-first ordering (see merge spec)
    end
    v(isnan(v)) = 0;
end

function x = nan_to_zero(x), x(isnan(x)) = 0; end

function copt = best_criterion(near_vals, far_vals, hi_fallback)
% Criterion maximizing same/different accuracy (near = same, far = different).
    lo = mean(far_vals);  hi = mean(near_vals);
    if isnan(hi), hi = lo + hi_fallback; end
    step = (hi - lo) / 100;
    if step <= 0, copt = lo; return; end
    copt = lo;  best = 0;
    for crit = lo:step:hi
        pc = (sum(near_vals >= crit) + sum(far_vals < crit)) / (numel(near_vals) + numel(far_vals));
        if pc > best, best = pc; copt = crit; end
    end
end

% ------------------------------------------------------------------------------
function [pc, pcs, pcd, pcnf] = score(qbs, qbd, rmn, rmf, same_near, same_far, gc, wm)
% Near-far and same-different accuracy accounting for one (gc, wm) cell.
    ncnt = numel(qbs);
    ncs = 0; ncd = 0; sc = 0; dc = 0; ncn = 0; ncf = 0;
    for i = 1:ncnt
        near_dv = qbs(i) + wm*rmn(i);
        far_dv  = qbd(i) + wm*rmf(i);
        if same_near(i) == 1
            sc = sc + 1;
            if near_dv >= gc, ncs = ncs + 1; ncn = ncn + 1; end
        else
            dc = dc + 1;
            if near_dv <  gc, ncd = ncd + 1; else, ncn = ncn + 1; end
        end
        if same_far(i) == 1
            sc = sc + 1;
            if far_dv >= gc, ncs = ncs + 1; else, ncf = ncf + 1; end
        else
            dc = dc + 1;
            if far_dv <  gc, ncd = ncd + 1; ncf = ncf + 1; end
        end
    end
    pc   = (ncd + ncs) / (2*ncnt);
    pcs  = ncs / sc;
    pcd  = ncd / dc;
    pcnf = (ncn + ncf) / (2*ncnt);
end
