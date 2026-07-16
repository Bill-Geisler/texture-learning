function plot_stage1(cfg)
% PLOT_STAGE1  Illustrate the Stage 1 colour transforms (RGB -> LMS -> ABR)
%   on a sample natural image.
    try
        % Load a natural image from the dataset for illustration
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if ~isfile(img_path)
            error('True CPS natural image not found.');
        end
        img = double(imread(img_path));
    catch
        fprintf('Could not load natural image for Stage 1 plot.\n');
        return;
    end
    % 1. RGB to LMS
    % In the actual pipeline, this initial RGB-to-LMS transform uses a fixed calibration
    % matrix specific to the camera that took the natural images. Here we use an
    % approximate linear mapping to illustrate the concept on a standard test image.
    img_lms = vislab.lib.rgb2lms(img);

    % load coeff
    if cfg.optics.apply, fname = 'cps_lms2abr_otf.mat'; else, fname = 'cps_lms2abr.mat'; end
    s = load(fullfile(cfg.paths.data_root, fname), 'coeff');
    coeff = s.coeff;

    % sample pixels
    pts = reshape(img, [], 3);
    pts = pts(1:100:end, :); % downsample for scatter speed
    lms_pts = reshape(img_lms, [], 3);
    lms_pts = lms_pts(1:100:end, :);
    abr_pts = lms_pts * coeff;

    figure('Name', 'Stage 1: Color Transforms (RGB -> LMS -> ABR)', 'Position', [100 100 1200 800]);

    subplot(2, 3, 1:3);
    image((img / max(img(:))).^(1/2.2)); axis image off;
    title('Source Image (Gamma Corrected)');

    subplot(2, 3, 4); scatter3(pts(:,1), pts(:,2), pts(:,3), 10, 'k', '.');
    title('1. RGB Space'); xlabel('R'); ylabel('G'); zlabel('B');

    subplot(2, 3, 5); scatter3(lms_pts(:,1), lms_pts(:,2), lms_pts(:,3), 10, 'k', '.');
    title('2. LMS Cone Space'); xlabel('L'); ylabel('M'); zlabel('S');

    subplot(2, 3, 6); scatter3(abr_pts(:,1), abr_pts(:,2), abr_pts(:,3), 10, 'k', '.');
    title('3. ABR (Decorrelated) Space'); xlabel('A'); ylabel('B'); zlabel('R');
end
