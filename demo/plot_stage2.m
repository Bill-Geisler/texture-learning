function plot_stage2(cfg, ecc)
% PLOT_STAGE2  Show the natural feature priors (PDFs) and the
%   task-optimized adaptive bins for the spot, edge and bar features.
    out_path = fullfile(cfg.paths.models, prior_filename(cfg, ecc));
    if ~isfile(out_path), return; end
    priors = load(out_path);

    if cfg.optics.apply, bin_file = 'AHEO_bins.mat'; else, bin_file = 'AHE_bins.mat'; end
    bin_path = fullfile(cfg.paths.models, bin_file);
    has_bins = isfile(bin_path);
    if has_bins
        S = load(bin_path);
        ecc_idx = find(S.eccs == ecc, 1);
    end

    figure('Name', 'Stage 2: Natural Priors, and task-optimized bins', 'Position', [100 100 800 1000]);
    sgtitle('Stage 2: Natural Priors, and task-optimized bins');

    trunc_xlim = @(e, N) xlim([e(max(1, find(N >= 0.01, 1, 'first'))), e(max(1, find(N >= 0.99, 1, 'first')))]);

    % Base size for 5x5 kernel
    sz5 = 0.05;
    % Proportional size for 3x3 kernel
    sz3 = sz5 * (3/5);

    function plot_feature(ax_idx, e, N, dim, xl_str)
        subplot(4,2,ax_idx);
        pdf = diff([0, N]); % PDF from CDF
        plot(e(1:end-1), pdf, 'LineWidth', 2); hold on;
        set(gca, 'YTick', []); % Remove y-axis ticks for PDF plots
        % ylim([0 1]); % Removed ylim because PDF can exceed 1 or have a different scale
        trunc_xlim(e, N);
        if has_bins && ~isempty(S.bin_bounds{dim, ecc_idx})
            bnds = S.bin_bounds{dim, ecc_idx};
            for b = bnds', xline(b, 'k-', 'LineWidth', 0.5); end
        end
        xlabel(xl_str);
    end

    % --- SPOT FEATURES (Rows 1 & 2) ---
    % 1. Achromatic (Dim 1)
    plot_feature(1, priors.ea, priors.Na, 1, 'Achromatic');

    % 2. Center-Surround Small (Dim 13)
    plot_feature(3, priors.ecs2, priors.Ncs2, 13, 'Center-Surround (Small)');
    pos6 = get(gca, 'Position'); axes('Position', [pos6(1)+pos6(3)-0.01-sz3, pos6(2)+0.02, sz3, sz3]);
    imagesc([-1 -1 -1; -1 8 -1; -1 -1 -1]); colormap(gca, gray); axis image off;

    % 3. Center-Surround Large (Dim 14)
    plot_feature(4, priors.ecs4, priors.Ncs4, 14, 'Center-Surround (Large)');
    pos7 = get(gca, 'Position'); axes('Position', [pos7(1)+pos7(3)-0.01-sz5, pos7(2)+0.02, sz5, sz5]);
    k_lg = -ones(5); k_lg(3,3) = 24;
    imagesc(k_lg); colormap(gca, gray); axis image off;

    % --- EDGE FEATURES (Row 3) ---
    % 4. 1st Deriv Magnitude / Edge (Dim 5)
    plot_feature(5, priors.em, priors.Nm, 5, '1st Deriv (Edge) Magnitude');
    pos2 = get(gca, 'Position'); axes('Position', [pos2(1)+pos2(3)-0.01-sz3, pos2(2)+0.02, sz3, sz3]);
    imagesc([-1 0 1; -2 0 2; -1 0 1]); colormap(gca, gray); axis image off;

    % 5. 1st Deriv Orientation / Edge (Dim 6)
    plot_feature(6, priors.eo, priors.No, 6, '1st Deriv (Edge) Orientation (degrees)');
    xlim([-180 180]); xticks([-180 0 180]);
    pos3 = get(gca, 'Position'); axes('Position', [pos3(1)+pos3(3)-0.01-sz3, pos3(2)+0.02, sz3, sz3]);
    imagesc([-1 0 1; -2 0 2; -1 0 1]); colormap(gca, gray); axis image off;

    % --- BAR FEATURES (Row 4) ---
    % 6. 2nd Deriv Magnitude / Bar (Dim 9)
    plot_feature(7, priors.em2, priors.Nm2, 9, '2nd Deriv (Bar) Magnitude');
    pos4 = get(gca, 'Position'); axes('Position', [pos4(1)+pos4(3)-0.01-sz3, pos4(2)+0.02, sz3, sz3]);
    imagesc([-1 2 -1; -1 2 -1; -1 2 -1]); colormap(gca, gray); axis image off;

    % 7. 2nd Deriv Orientation / Bar (Dim 10)
    plot_feature(8, priors.eo2, priors.No2, 10, '2nd Deriv (Bar) Orientation (degrees)');
    xlim([-90 90]); xticks([-90 0 90]);
    pos5 = get(gca, 'Position'); axes('Position', [pos5(1)+pos5(3)-0.01-sz3, pos5(2)+0.02, sz3, sz3]);
    imagesc([-1 2 -1; -1 2 -1; -1 2 -1]); colormap(gca, gray); axis image off;
end
