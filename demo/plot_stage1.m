function plot_stage1(cfg, coeff)
% PLOT_STAGE1  Illustrate the Stage 1 colour transforms (RGB -> LMS -> ABR).
%   plot_stage1(cfg)          quick mode: use the shipped LMS->ABR rotation and
%                             scatter pixels from a SINGLE natural image.
%   plot_stage1(cfg, coeff)   full mode: use the just-learned rotation COEFF and
%                             scatter pixels sampled from ALL natural images (the
%                             images the transform was learned from), capped for
%                             plotting speed. These are raw image pixels, not the
%                             per-patch-normalized pixels PCA was actually fit on, so
%                             the cloud is illustrative of -- not identical to -- the
%                             PCA input; the decorrelation it shows still holds.
%
%   The scatters show why the pipeline rotates to ABR: the RGB/LMS clouds are
%   elongated/correlated, the ABR cloud is decorrelated (PCA axes). The RGB->LMS
%   step uses the real lab camera calibration (vislab.lib.rgb2lms); only the
%   LMS->ABR rotation is learned in Stage 1.

    max_pts = cfg.demo.scatter_points;   % shared cap on plotted points

    files = list_natural_images(cfg);
    if isempty(files)
        fprintf('Could not find natural images for Stage 1 plot.\n');
        return;
    end

    % LMS->ABR rotation: use the learned one if given (full mode), else the shipped
    % one from disk (quick mode).
    if nargin < 2 || isempty(coeff)
        if cfg.optics.apply, fname = 'cps_lms2abr_otf.mat'; else, fname = 'cps_lms2abr.mat'; end
        s = load(fullfile(cfg.paths.data_root, fname), 'coeff');
        coeff = s.coeff;
        use_all = false;                         % quick mode: single image
    else
        use_all = true;                          % full mode: all training images
    end

    % --- gather the pixel cloud (RGB and LMS) ---
    if use_all
        per_img = max(1, ceil(max_pts / numel(files)));   % spread the cap across images
        rgb_pts = zeros(per_img * numel(files), 3);
        lms_pts = zeros(per_img * numel(files), 3);
        n = 0;
        for f = 1:numel(files)
            img_f = double(imread(files{f}));
            if size(img_f, 3) == 1, img_f = repmat(img_f, [1 1 3]); end
            rgb_f = reshape(img_f, [], 3);
            lms_f = reshape(vislab.lib.rgb2lms(img_f), [], 3);
            idx = randi(size(rgb_f, 1), per_img, 1);       % random pixels from this image
            rgb_pts(n+1:n+per_img, :) = rgb_f(idx, :);
            lms_pts(n+1:n+per_img, :) = lms_f(idx, :);
            n = n + per_img;
        end
        rgb_pts = rgb_pts(1:n, :);
        lms_pts = lms_pts(1:n, :);
    else
        img_f = double(imread(files{1}));
        if size(img_f, 3) == 1, img_f = repmat(img_f, [1 1 3]); end
        rgb_pts = reshape(img_f, [], 3);
        lms_pts = reshape(vislab.lib.rgb2lms(img_f), [], 3);
        step = max(1, ceil(size(rgb_pts, 1) / max_pts));   % thin to the cap
        rgb_pts = rgb_pts(1:step:end, :);
        lms_pts = lms_pts(1:step:end, :);
    end
    abr_pts = lms_pts * coeff;

    % --- figure: example image on top, the three colour-space clouds below ---
    img_show = double(imread(files{1}));
    figure('Name', 'Stage 1: Color Transforms (RGB -> LMS -> ABR)', 'Position', [100 100 1200 800]);

    subplot(2, 3, 1:3);
    image((img_show / max(img_show(:))).^(1/2.2)); axis image off;
    if use_all
        title(sprintf('Example Source Image (clouds below: %d pixels from all %d images)', ...
            size(rgb_pts, 1), numel(files)));
    else
        title('Example image (gamma-corrected)');
    end

    subplot(2, 3, 4); scatter3(rgb_pts(:,1), rgb_pts(:,2), rgb_pts(:,3), 3, 'k', '.');
    title('1. RGB Space'); xlabel('R'); ylabel('G'); zlabel('B');
    grid on; set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);   % no tick labels, keep grid

    subplot(2, 3, 5); scatter3(lms_pts(:,1), lms_pts(:,2), lms_pts(:,3), 3, 'k', '.');
    title('2. LMS Cone Space'); xlabel('L'); ylabel('M'); zlabel('S');
    grid on; set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);

    subplot(2, 3, 6); scatter3(abr_pts(:,1), abr_pts(:,2), abr_pts(:,3), 3, 'k', '.');
    title('3. ABR (Decorrelated) Space'); xlabel('A'); ylabel('B'); zlabel('R');
    grid on; set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);
end
