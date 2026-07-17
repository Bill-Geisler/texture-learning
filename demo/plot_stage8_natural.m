function plot_stage8_natural(cfg, out7, method, ecc)
% PLOT_STAGE8_NATURAL  Segment a natural image with the GTR segmentation machinery.
%   plot_stage8_natural(cfg, out7, method, ecc)
%
%   Applies the exact self-supervised segmentation used on GTR images (stage 7) to
%   a real natural image, using the same 64x64 (= cfg.patch.size/ecc) patches. The
%   image is clipped to the largest square that is a whole number of patches.
%
%   Unlike a GTR image, a natural image has NO ground-truth region map, so:
%     * the per-image grouping criterion gcopt and mutual-similarity weight wmopt
%       are still learned self-supervised -- they come from the near/far accuracy
%       (nearfar_score_grid's pcnf), which uses proximity only, not the true map.
%       A dummy (all-zero) map is passed to neighbor_far_responses; it only fills
%       the same/different labels, which feed the discarded same/different scores.
%     * there is nothing to score the segmentation against, so no accuracy is
%       reported, and the region-merge parameters (mc, dgc) cannot be tuned here --
%       they are carried over from the GTR sweep (out7's best cell).
%
%   Inputs
%     cfg    - config struct.
%     out7   - the struct returned by s7_segment_gtr (for its optimal mc/dgc).
%     method - 'ncb' (border+content) or 'nc' (content); default 'ncb'.
%     ecc    - eccentricity (default 1).

    if nargin < 3 || isempty(method), method = 'ncb'; end
    if nargin < 4 || isempty(ecc),    ecc = 1;       end
    ss_method = struct('nc', 'c_shft', 'ncb', 'bc_noshift').(method);

    psz    = cfg.patch.size / ecc;
    cc_opt = 1.1;                                    % confidence criterion (as in s7)

    % --- best (mc, dgc) from the GTR sweep: no ground truth here to tune them ---
    [~, idx] = max(out7.nregs5_ave, [], 'all', 'linear');
    [ki, li] = ind2sub(size(out7.nregs5_ave), idx);
    mc_opt  = out7.mc(ki);
    dgc_opt = out7.dgc(li);

    % --- pick the natural image, halve it, clip each dimension to whole patches ---
    files    = list_natural_images(cfg);
    img_name = '12_16_143';                  % filename stem of the image to segment
    idx = find(contains(files, img_name), 1);
    if isempty(idx)
        fprintf('stage 8: image "%s" not found; using the first natural image.\n', img_name);
        idx = 1;
    end
    prescale = 255 / cfg.natural.max_val;
    pimg = vislab.nat_stat_bayes.source_to_lms(files{idx}, cfg, struct('prescale', prescale, 'ecc', ecc));
    npx = floor(size(pimg, 1) / psz);        % patch rows
    npy = floor(size(pimg, 2) / psz);        % patch cols
    if npx < 2 || npy < 2
        fprintf('stage 8: natural image too small (%dx%d) for a %dpx grid.\n', ...
                size(pimg, 1), size(pimg, 2), psz);
        return;
    end
    pimg = pimg(1:npx*psz, 1:npy*psz, :);    % top-left crop, whole patches in each dim
    fprintf('stage 8: segmenting a %dx%d natural image (%dx%d patches of %dpx)...\n', ...
            npx*psz, npy*psz, npx, npy, psz);

    % patch index -> grid (row, col), row-major (linear index = (row-1)*npy + col)
    patch_x = zeros(npx*npy, 1);
    patch_y = zeros(npx*npy, 1);
    p = 0;
    for r = 1:npx
        for c = 1:npy
            p = p + 1;
            patch_x(p) = r;
            patch_y(p) = c;
        end
    end

    % --- artifacts: bin bounds + trained DV handles (same as s7) ---
    cstat = zeros(1, 20); cstat([1 5 9 10 13 14]) = 5;   % spot [1 13 14] + edge DV [5 9 10]
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, 1, double(cfg.optics.apply));
    dv = load_dv_handles(cfg, ecc, true);

    % --- content similarity + mutual similarity ---
    phiall = segmentation.content_similarity_matrix(pimg, psz, patch_x, patch_y, ...
        bin_bounds, n_bins, dv.h, dv.e, dv.c, cfg);
    rho = segmentation.mutual_similarity(phiall);

    % --- learn gcopt/wmopt self-supervised (proximity only; dummy map for the unused labels) ---
    dummy_map = zeros(npx, npy);
    R = neighbor_far_responses(cfg, pimg, rho, dummy_map, bin_bounds, n_bins, dv);
    [qbs, qbd] = self_sup_decision(ss_method, R, dv);
    gc_vec = 0 : 0.8 : 8;  wm_vec = 0 : 0.8 : 9.6;
    [~, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
    [row_best, col_at] = max(pcnf, [], 2);
    [~, J] = max(row_best);
    gcopt = gc_vec(J);  wmopt = wm_vec(col_at(J));

    % --- neighbour similarity + combined mu, then group into regions ---
    [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, psz, patch_x, patch_y, ...
        psz, bin_bounds, n_bins, dv, cfg);
    mu = (phi + wmopt * rho) .* (phi ~= 0);
    [~, ~, groups2d] = segmentation.group_patches(mu, dst, gcopt + dgc_opt, cc_opt, ...
        psz, patch_x, patch_y, phiall, mc_opt);

    % --- plot: natural image beside its segmentation overlay ---
    pimg_gray = mean(double(pimg), 3);
    pimg_norm = pimg_gray - min(pimg_gray(:));
    pimg_norm = pimg_norm / max(pimg_norm(:));
    pimg_rgb  = repmat(pimg_norm, [1 1 3]);
    groups_up = imresize(groups2d, [size(pimg, 1), size(pimg, 2)], 'nearest');
    nreg = numel(unique(groups2d(groups2d > 0)));

    figure('Name', 'Stage 8: Natural-image segmentation', 'Position', [400 200 1000 520]);
    subplot(1, 2, 1);
    image(pimg_rgb); axis image off; title('Natural image');
    subplot(1, 2, 2);
    image(pimg_rgb); axis image off; hold on;
    h = imagesc(groups_up); colormap(gca, 'jet'); set(h, 'AlphaData', 0.4);
    title(sprintf('Self-supervised segmentation (%d regions)', nreg));
    drawnow;
end
