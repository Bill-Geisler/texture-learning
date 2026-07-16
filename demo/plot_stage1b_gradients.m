function plot_stage1b_gradients(cfg)
% PLOT_STAGE1B_GRADIENTS  Illustrative (exploratory) figure: the multi-scale
%   first-derivative (gradient) structure of natural images, computed on
%   isolated 64x64 patches (the model's actual same/different input size) taken
%   from the achromatic (A) channel of the SAME sample image as the Stage 1
%   colour figure.
%
%   The model currently uses a SINGLE-scale (sigma=1 px) first-derivative
%   steerable filter for its edge features. This panel measures the same filter
%   FORM (vislab.lib.steerable_kernels) across scales on many 64x64 A-channel
%   patches and shows:
%     1. horizontal and vertical responses are ~uncorrelated (H independent of V);
%     2. responses ARE strongly correlated across scale within each orientation;
%     3. PCA gives a decorrelated multi-scale basis -- the same idea as the
%        Stage 1 RGB->ABR colour rotation, one level up.
%
%   TRUNCATION (smooth illustration): this figure deliberately builds WIDER
%   kernels than the model. The model uses nsd=3 (half-width 1.5*sigma), which
%   truncates the Gaussian while it is still ~32% of peak -- so the raw and PC
%   filters come out visibly "blocky" (sharp square support). For a clean,
%   smoothly-tapered illustration (matching the efficient-coding deck) we use
%   nsd=6 here (half-width 3*sigma, ~5% of peak at the edge). This changes only
%   how the filters LOOK; it does not touch the model or any trained artifact.
%   See docs/uniform-steerable-gradients.md for the eventual plan to make the
%   kernel definition uniform across repos.
%
%   PATCH-SIZE LIMIT: a steerable kernel is nsd*sigma px wide, so it must fit
%   inside the 64px patch and leave a usable valid interior. At nsd=6 the largest
%   scale sigma=8 is 48x48 (3/4 of the patch, ~16x16 valid); larger sigma would
%   leave too little, so the scale list is capped at sigma=8. Raise sd_list only
%   if you also grab surrounding image context for each patch.
%
%   NOTE: purely illustrative -- NOT wired into the pipeline. PCA is on the RAW
%   (linear) responses so it is a genuine linear decorrelation; the model's
%   per-patch contrast normalization is not applied here.

    nsd     = 6;                      % kernel width (SDs) for a SMOOTH illustration; the model itself uses cfg.dv.nsd1 = 3
    sd_list = [1 2 4 8];              % sigma=1 is the model's current scale; capped so nsd*sigma fits a 64px patch
    n_scales = numel(sd_list);
    psz     = cfg.patch.size;         % 64 px: the 1-deg patch the same/different features run on
    n_patches = 400;                  % isolated patches sampled from the image

    % --- same sample image and colour transform as plot_stage1 ---
    try
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if ~isfile(img_path), error('CPS natural image not found.'); end
        img = double(imread(img_path));
    catch
        fprintf('Could not load natural image for Stage 1b plot.\n');
        return;
    end
    img_lms = vislab.lib.rgb2lms(img);
    if cfg.optics.apply, fname = 'cps_lms2abr_otf.mat'; else, fname = 'cps_lms2abr.mat'; end
    s = load(fullfile(cfg.paths.data_root, fname), 'coeff');
    coeff = s.coeff;

    % achromatic (A) channel of ABR space -- features are computed on A only
    [h, w, ~] = size(img_lms);
    abr = reshape(reshape(img_lms, [], 3) * coeff, h, w, 3);
    A = abr(:, :, 1);

    % apply the eye's optics, matching the model's feature-extraction preprocessing
    if cfg.optics.apply
        A = vislab.lib.otf_filter(A, cfg.optics.ppd, cfg.optics.pupil_diameter, cfg.optics.wavelength);
    end

    % --- steerable kernels; check every one fits inside a 64px patch ---
    max_hw = ceil(nsd * max(sd_list) / 2);   % border lost to the largest kernel
    vpx = psz - 2 * max_hw;                  % valid interior per patch (shared across scales)
    if vpx < 1
        error('plot_stage1b:filterTooLarge', ...
              'sigma=%d filter (%dpx) does not fit in a %dpx patch.', max(sd_list), nsd*max(sd_list), psz);
    end
    kh_bank = cell(1, n_scales);
    KHc = cell(1, n_scales); KVc = cell(1, n_scales);
    for i = 1:n_scales
        [KHc{i}, KVc{i}] = vislab.lib.steerable_kernels(sd_list(i), nsd);
        kh_bank{i} = KHc{i};
    end

    % --- sample isolated psz x psz patches on a regular grid (deterministic) ---
    % features run on each patch ALONE (no surrounding context), so we crop the
    % largest kernel's border and keep the identical valid interior at every scale.
    xs_grid = 1:psz:(h - psz + 1);
    ys_grid = 1:psz:(w - psz + 1);
    [gx, gy] = ndgrid(xs_grid, ys_grid);
    locs = [gx(:), gy(:)];
    if size(locs, 1) > n_patches                    % thin out to n_patches, evenly
        locs = locs(round(linspace(1, size(locs, 1), n_patches)), :);
    end
    n_patches = size(locs, 1);

    H = zeros(n_patches * vpx^2, n_scales);          % horizontal responses
    V = zeros(n_patches * vpx^2, n_scales);          % vertical responses
    row = 0;
    for p = 1:n_patches
        patch = A(locs(p,1):locs(p,1)+psz-1, locs(p,2):locs(p,2)+psz-1);
        for i = 1:n_scales
            gh = conv2(patch, KHc{i}, 'same'); gh = gh(max_hw+1:end-max_hw, max_hw+1:end-max_hw);
            gv = conv2(patch, KVc{i}, 'same'); gv = gv(max_hw+1:end-max_hw, max_hw+1:end-max_hw);
            H(row+1:row+vpx^2, i) = gh(:);
            V(row+1:row+vpx^2, i) = gv(:);
        end
        row = row + vpx^2;
    end
    R_all = [H, V];                                  % (n_patches*vpx^2) x (2*n_scales)

    % --- statistics: PCA on the JOINT horizontal+vertical set (like the deck) ---
    % Column order of R_all is [H sigma1..N, V sigma1..N].
    C_raw = corrcoef(R_all);                                           % (2*n_scales) square
    [pca_coeff, ~, ~, ~, explained] = pca(R_all);                      % joint PCA -> PCs come in H/V pairs
    [~, scoreH] = pca(H);                                              % H-only PCA scores (= H-dominant joint PCs, since H_|_V), for the decorrelation scatter
    nf = 2 * n_scales;

    feat_kernels = [KHc, KVc];                        % raw kernel for each feature column
    feat_sigma   = [sd_list, sd_list];                % sigma per feature column (for the corr-matrix ticks)

    % pad every feature kernel to a common K x K
    K = ceil(nsd * max(sd_list));
    pad = zeros(K, K, nf);
    for f = 1:nf
        k = feat_kernels{f}; [kh, kw] = size(k);
        r0 = floor((K - kh)/2) + 1; c0 = floor((K - kw)/2) + 1;
        pad(r0:r0+kh-1, c0:c0+kw-1, f) = k;
    end

    % PCA "filters": each PC rendered as the linear combination of the raw kernels
    % given by its coefficient column. Because H is uncorrelated with V, each PC is
    % (nearly) pure-H or pure-V, so they alternate orientation by variance. Sign is
    % arbitrary. (With the wide nsd=6 truncation used here they taper smoothly; at
    % the model's nsd=3 each scale has a sharp square support and the sum would step
    % at those boundaries, looking blocky -- see the TRUNCATION note in the header.)
    pc_filt = cell(1, nf); pc_isH = false(1, nf);
    for c = 1:nf
        pc_filt{c} = sum(pad .* reshape(pca_coeff(:, c), [1 1 nf]), 3);
        pc_isH(c)  = sum(abs(pca_coeff(1:n_scales, c))) >= sum(abs(pca_coeff(n_scales+1:end, c)));
    end

    cmap_div = local_diverging();                                      % red(-)-white-blue(+)

    % =====================================================================
    figure('Name', 'Stage 1b: Multi-scale gradient structure', ...
           'Position', [40 40 1500 980]);
    t = tiledlayout(3, 6, 'TileSpacing', 'compact', 'Padding', 'compact');
    t.Units = 'normalized'; t.OuterPosition = [0 0 1 0.93];   % leave a top strip for the title
    annotation(gcf, 'textbox', [0.1 0.94 0.8 0.05], ...
        'String', 'Stage 1b: joint dist. of gradients at different scales on example natural image', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', 'FontSize', 12, 'EdgeColor', 'none');

    sc = n_scales:-1:1;                                                % scale order, largest sigma first
    sig_sc_lab = arrayfun(@(s) sprintf('\\sigma=%d', s), sd_list(sc), 'UniformOutput', false);

    % --- Row 1a: raw steerable filters, single grid (H top row, V bottom row) ---
    nexttile([1 3]);
    imagesc(local_kernel_grid(KHc(sc), KVc(sc), K)); axis image; clim([-1 1]); colormap(gca, gray);
    set(gca, 'XTick', ((1:n_scales) - 0.5) * K, 'XTickLabel', sig_sc_lab, ...
             'YTick', [0.5 1.5] * K, 'YTickLabel', {'H', 'V'}, 'TickLength', [0 0]);
    title('raw steerable filters');

    % --- Row 1b: PCA filters, single grid (H-dominant PCs top, V-dominant bottom) ---
    h_pcs = find(pc_isH);  v_pcs = find(~pc_isH);                      % each variance-sorted; column j is the j-th H/V pair
    nexttile([1 3]);
    imagesc(local_kernel_grid(pc_filt(h_pcs), pc_filt(v_pcs), K)); axis image; clim([-1 1]); colormap(gca, gray); hold on;
    set(gca, 'XTick', [], 'YTick', [0.5 1.5] * K, 'YTickLabel', {'H', 'V'}, 'TickLength', [0 0]);
    for j = 1:numel(h_pcs)
        text((j-1)*K + 1, 1,     sprintf('PC%d', h_pcs(j)), 'VerticalAlignment', 'top', 'FontSize', 8, 'Color', 'w');
    end
    for j = 1:numel(v_pcs)
        text((j-1)*K + 1, K + 1, sprintf('PC%d', v_pcs(j)), 'VerticalAlignment', 'top', 'FontSize', 8, 'Color', 'w');
    end
    title('PCA filters');

    % --- Row 2a: raw H responses at the 3 largest scales (correlated cloud) ---
    nobs = size(H, 1);
    si   = round(linspace(1, nobs, min(nobs, 3000)));                 % subsample for a readable scatter
    big3 = sc(1:3);                                                    % 3 largest scales
    nexttile([1 3]);
    scatter3(H(si, big3(1)), H(si, big3(2)), H(si, big3(3)), 6, 'k', '.');
    grid on; view(3);
    local_bulk_lims(H(:, big3(1)), H(:, big3(2)), H(:, big3(3)));   % zoom past outliers to the bulk
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []); % drop tick labels, keep grid
    xlabel(sprintf('H \\sigma=%d', sd_list(big3(1))));
    ylabel(sprintf('H \\sigma=%d', sd_list(big3(2))));
    zlabel(sprintf('H \\sigma=%d', sd_list(big3(3))));
    title('horizontal steerable responses');

    % --- Row 2b: PCA of the H responses (decorrelated cloud) ---
    nexttile([1 3]);
    scatter3(scoreH(si, 1), scoreH(si, 2), scoreH(si, 3), 6, 'k', '.');
    grid on; view(3);
    local_bulk_lims(scoreH(:, 1), scoreH(:, 2), scoreH(:, 3));
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []); % drop tick labels, keep grid
    xlabel('PC1'); ylabel('PC2'); zlabel('PC3');
    title('PCA of horizontal steerable responses');

    % --- Row 3a: response correlation matrix (H/V blocks, sigma-labelled) ---
    nexttile([1 2]);
    hv = n_scales + 0.5; th = (n_scales + 1)/2;
    sig_lab = arrayfun(@(s) sprintf('%d', s), feat_sigma, 'UniformOutput', false);
    imagesc(C_raw, [-1 1]); axis image; colormap(gca, cmap_div); colorbar; hold on;
    plot([hv hv], [0.5 nf+0.5], 'k-', 'LineWidth', 1.2);
    plot([0.5 nf+0.5], [hv hv], 'k-', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:nf, 'XTickLabel', sig_lab, 'YTick', 1:nf, 'YTickLabel', sig_lab, 'TickLength', [0 0]);
    text(th, -0.9, 'H', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    text(n_scales+th, -0.9, 'V', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    text(-1.6, th, 'H', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    text(-1.6, n_scales+th, 'V', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    xlabel('\sigma'); ylabel('\sigma');
    title('steerable response correlations');

    % --- Row 3b: PCA coefficients (rows = H/V x sigma, cols = PCs; shows alternation) ---
    nexttile([1 2]);
    mx = max(abs(pca_coeff(:)));
    imagesc(pca_coeff, [-mx mx]); axis image; colormap(gca, cmap_div); colorbar; hold on;
    plot([0.5 nf+0.5], [hv hv], 'k-', 'LineWidth', 1.2);   % divide H rows from V rows
    set(gca, 'XTick', 1:nf, 'YTick', 1:nf, 'YTickLabel', sig_lab, 'TickLength', [0 0]);
    text(-1.6, th, 'H', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    text(-1.6, n_scales+th, 'V', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Clipping', 'off');
    xlabel('principal component'); ylabel('\sigma');
    title('PCA coefficients');

    % --- Row 3c: variance explained ---
    nexttile([1 2]);
    bar(explained, 'FaceColor', [0.3 0.5 0.8]); hold on;
    plot(cumsum(explained), '-o', 'Color', [0.8 0.3 0.3], 'LineWidth', 1.2);
    xlabel('principal component'); ylabel('% variance'); ylim([0 105]); xlim([0.5 nf+0.5]);
    title(sprintf('variance explained (PC1+2 = %.0f%%)', sum(explained(1:2))));
end

function M = local_kernel_grid(top_kernels, bot_kernels, K)
% Two-row montage: TOP_KERNELS on the top row, BOT_KERNELS on the bottom row.
% Each kernel is padded to K x K and per-kernel normalized to [-1,1], then laid
% out left-to-right. Returns a (2K) x (ncol*K) image.
    rows = {top_kernels, bot_kernels};
    ncol = max(numel(top_kernels), numel(bot_kernels));
    M = zeros(2 * K, ncol * K);
    for r = 1:2
        ks = rows{r};
        for i = 1:numel(ks)
            k = ks{i};
            k = k / max(abs(k(:)));             % per-kernel normalize to [-1,1]
            [kh, kw] = size(k);
            r0 = (r-1)*K + floor((K - kh) / 2) + 1;
            c0 = (i-1)*K + floor((K - kw) / 2) + 1;
            M(r0:r0+kh-1, c0:c0+kw-1) = k;
        end
    end
end

function local_bulk_lims(x, y, z)
% Set the current 3D axes' x/y/z limits to each variable's 0.5-99.5 percentile,
% so a few extreme outliers don't stretch the axes and flatten the bulk cloud.
    q = [0.5 99.5];
    xl = prctile(x, q); yl = prctile(y, q); zl = prctile(z, q);
    if diff(xl) > 0, xlim(xl); end
    if diff(yl) > 0, ylim(yl); end
    if diff(zl) > 0, zlim(zl); end
end

function cmap = local_diverging()
% Red (negative) - white (zero) - blue (positive) diverging colormap.
    n   = 128;
    top = [ones(n, 1), linspace(0, 1, n)', linspace(0, 1, n)'];   % red -> white
    bot = [linspace(1, 0, n)', linspace(1, 0, n)', ones(n, 1)];   % white -> blue
    cmap = [top; bot];
end
