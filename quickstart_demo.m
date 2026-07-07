% quickstart_demo.m  —  End-to-end demonstration of the texture-learning pipeline.
%
%   Run it (from anywhere):   >> run <path-to-repo>/quickstart_demo.m
%   or:   >> cd <repo>; setup; run quickstart_demo.m
%
% What it does:
%   Demonstrates the entire texture-learning pipeline described in the 
%   "Proximity as a Ground-Truth Proxy for Training Texture Discrimination and Segmentation" paper.
%   
%   Stages 1-5 involve training the model from scratch using calibrated natural images,
%   where spatial proximity serves as a ground-truth proxy for whether two patches are
%   the same or different textures. This training is computationally expensive and
%   requires the full natural image dataset in vislab-common/data. 
%
%   For convenience, this demo defaults to skipping stages 1-5 and uses the SHIPPED 
%   trained model in data/models to directly run the self-supervised 
%   texture-discrimination stage (s6) and segmentation stage (s7) on 
%   "Grown-Texture-Region" (GTR) images. GTR images are constructed by growing 
%   random regions and filling them with source textures from datasets like Brodatz.
%   All six texture datasets (Pertex, Fabric, Brodatz, VisTex, McGill) are supported.
%
%   To re-run the expensive training stages 1-5, set `run_training_stages = true` below.

% --- locate the repo and set up the path ---
repo_root = fileparts(mfilename('fullpath'));
cd(repo_root);
setup;
cfg = config;

% --- 0. (Optional) Run Pipeline Stages 1-5: Training the Model ---
run_training_stages = false; % Set to true to re-train the model from scratch

if run_training_stages
    fprintf('\n--- Running Pipeline Stages 1-5: Training the Model ---\n');
    fprintf('Note: This requires the calibrated natural images in vislab-common/data.\n\n');
    
    % Stage 1: Learn Color Transform (Decorrelation)
    % First, the raw RGB camera sensor responses are converted into LMS cone responses. 
    % This initial RGB-to-LMS transform uses a fixed matrix calibrated to the specific 
    % camera used to capture the natural image dataset.
    % Next, consistent with early visual processing (and optimal encoding), we transform 
    % the LMS axes to an ABR (Achromatic, Blue-yellow, Red-green) space so the joint 
    % distribution of features has minimal correlation.
    fprintf('-> Running Stage 1: s1_learn_color_transform...\n');
    s1_learn_color_transform(cfg);

    % Stage 2: Learn Feature CDFs
    % We compute the task-independent prior probability distributions (Cumulative 
    % Distribution Functions) for the generic image features (edge, spot, power spectrum) 
    % measured from natural images.
    fprintf('-> Running Stage 2: s2_learn_feature_cdfs...\n');
    s2_learn_feature_cdfs(cfg);

    % Stage 3: Make Near/Far Training Pairs
    % The fundamental principle of the paper: proximity is a proxy for same-different labels.
    % We sample reference patches from natural images and create "near" pairs (likely 
    % same texture) and "far" pairs (likely different textures) for training.
    ecc = 1; % Eccentricity of 1 = fovea
    fprintf('-> Running Stage 3: s3_make_nearfar_pairs...\n');
    s3_make_nearfar_pairs(cfg, ecc);

    % Stage 4: Optimize Adaptive Histogram Bins
    % For each feature dimension, we discretize the feature space into adaptive bins.
    % This prepares the data to estimate the task-specific feature likelihoods (i.e.
    % probability distributions of features for near vs. far pairs).
    for dim = [1 5 6 7 9 10 11 13 14]
        fprintf('-> Running Stage 4: s4_optimize_bins for dim %d...\n', dim);
        s4_optimize_bins(cfg, dim, ecc);
    end

    % Stage 5: Train Decision Variables and Bounds
    % Using the near/far pairs as ground truth, we train the Bayesian decision variables 
    % (content, border, and combined) and the optimal decision bounds (e.g., QSVM boundary). 
    % This maximizes near-far categorization accuracy, which the paper shows mathematically 
    % also optimizes same-different categorization.
    fprintf('-> Running Stage 5: s5_train_decision_vars...\n');
    s5_train_decision_vars(cfg, ecc);
    
    fprintf('Training complete! Models saved to data/models/\n\n');
else
    fprintf('\nSkipping Stages 1-5 (Training). Using the pre-built shipped models.\n');
end

% --- PLOTTING STAGES 1-5 ---
fprintf('\n--- Generating Illustrative Plots for Stages 1-5 ---\n');
ecc = 1;
plot_stage1(cfg);
plot_stage2(cfg, ecc);
plot_stage3(cfg, ecc);
plot_stage5(cfg, ecc);
drawnow;

% --- 1. check the shipped (or newly trained) artifacts are present ---
needed = {'cdfs_abr_mo13_mo23_cs33_otf.mat', ...
          'dbndhNO1.mat', 'dbndeNO1.mat', 'dbndcNO1.mat', 'dbndbNO1.mat', 'AHEO_bins.mat'};
present = cellfun(@(f) exist(fullfile(cfg.paths.models, f), 'file') > 0, needed);
if ~all(present)
    error('demo:missingArtifacts', ...
        ['Missing trained artifacts in data/models: %s\n' ...
         'Run pipeline stages s1-s5 first by setting run_training_stages=true, or restore data/models.'], ...
        strjoin(needed(~present), ', '));
end
fprintf('Trained model artifacts found in %s\n', cfg.paths.models);

% --- 2. run the self-supervised discrimination stage (s6) on GTR images ---
method = 'bc';    % per-image retraining of the border+content bound (paper: NCB)
itype  = 3;       % 3 = Brodatz (source textures)
ntrl   = 2;       % GTR images to average over (small, for a quick demo)

fprintf('\n--- Stage 6: Self-Supervised Discrimination ---\n');
fprintf('Applying the decision variables learned from natural images (Stages 1-5)\n');
fprintf('to GTR (grown-texture-region) images built from Brodatz source textures.\n');
fprintf('Method: %s, Dataset: Brodatz, Trials: %d.\n', method, ntrl);
fprintf('(Builds GTR images and computes all pairwise similarities -- takes a few minutes.)\n');
try
    out6 = s6_selfsup_discrimination(cfg, method, itype, ecc, ntrl);
catch err
    if contains(err.identifier, 'datasetMissing')
        error('demo:noTextureData', ...
            ['Brodatz texture sheets are not available/readable in %s.\n' ...
             'Ensure vislab-common/data/textures/brodatz/B*.gif are downloaded locally.'], ...
            cfg.paths.textures);
    else
        rethrow(err);
    end
end

[best, idx] = max(out6.pcav, [], 'all', 'linear');
[gi, wi] = ind2sub(size(out6.pcav), idx);
fprintf('\nStage 6 Result: peak mean near-far accuracy = %.1f%%\n', 100 * best);
fprintf('        at criterion = %.2f, mutual-similarity weight = %.2f\n', out6.gc(gi), out6.wm(wi));
plot_stage6(out6, method);
drawnow;

% --- 3. run the segmentation stage (s7) on GTR images ---
fprintf('\n--- Stage 7: GTR Segmentation ---\n');
fprintf('Using the grouping criterion and mutual-similarity weight learned in Stage 6,\n');
fprintf('we now perform the actual region grouping and segmentation of the GTR images.\n');
try
    out7 = s7_segment_gtr(cfg, 'ncb', itype, ecc, ntrl);
catch err
    rethrow(err);
end

[best, idx] = max(out7.nregs5_ave, [], 'all', 'linear');
[ki, li] = ind2sub(size(out7.nregs5_ave), idx);
fprintf('\nStage 7 Result: peak fully-correct regions = %.1f%%\n', 100 * best);
fprintf('        at merge = %.2f, dgc = %.2f\n', out7.mc(ki), out7.dgc(li));
plot_stage7(cfg, out7, 'ncb', itype, ecc);
fprintf('\nDemo Complete! Check the generated figure windows.\n');


% =========================================================================
% HELPER PLOTTING FUNCTIONS
% =========================================================================

function plot_stage1(cfg)
    try
        % Load a natural image from the dataset for illustration
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if isfile(img_path)
            img = double(imread(img_path));
        else
            img = double(imread('peppers.png')); % fallback
        end
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

function plot_stage2(cfg, ecc)
    if cfg.optics.apply, out_file = 'cdfs_abr_mo13_mo23_cs33_otf.mat'; else, out_file = 'cdfs_abr_mo13_mo23_cs33.mat'; end
    out_path = fullfile(cfg.paths.models, out_file);
    if ~isfile(out_path), return; end
    cdfs = load(out_path);
    
    if cfg.optics.apply, bin_file = 'AHEO_bins.mat'; else, bin_file = 'AHE_bins.mat'; end
    bin_path = fullfile(cfg.paths.models, bin_file);
    has_bins = isfile(bin_path);
    if has_bins
        S = load(bin_path);
        ecc_idx = find(S.eccs == ecc, 1);
    end
    
    figure('Name', 'Task-independent CDF''s, and task-optimized bins', 'Position', [100 100 800 1000]);
    sgtitle('Task-independent CDF''s, and task-optimized bins');
    
    trunc_xlim = @(e, N) xlim([e(max(1, find(N >= 0.01, 1, 'first'))), e(max(1, find(N >= 0.99, 1, 'first')))]);
    
    % Base size for 5x5 kernel
    sz5 = 0.05; 
    % Proportional size for 3x3 kernel
    sz3 = sz5 * (3/5);
    
    function plot_feature(ax_idx, e, N, dim, xl_str)
        subplot(4,2,ax_idx);
        plot(e(1:end-1), N, 'LineWidth', 2); hold on; ylim([0 1]); trunc_xlim(e, N);
        if has_bins && ~isempty(S.bin_bounds{dim, ecc_idx})
            bnds = S.bin_bounds{dim, ecc_idx};
            for b = bnds', xline(b, 'k-', 'LineWidth', 0.5); end
        end
        xlabel(xl_str);
    end

    % --- SPOT FEATURES (Rows 1 & 2) ---
    % 1. Achromatic (Dim 1)
    plot_feature(1, cdfs.ea, cdfs.Na, 1, 'Achromatic');
    
    % 2. Center-Surround Small (Dim 13)
    plot_feature(3, cdfs.ecs2, cdfs.Ncs2, 13, 'Center-Surround (Small)');
    pos6 = get(gca, 'Position'); axes('Position', [pos6(1)+pos6(3)-0.01-sz3, pos6(2)+0.02, sz3, sz3]);
    imagesc([-1 -1 -1; -1 8 -1; -1 -1 -1]); colormap(gca, gray); axis image off;
    
    % 3. Center-Surround Large (Dim 14)
    plot_feature(4, cdfs.ecs4, cdfs.Ncs4, 14, 'Center-Surround (Large)');
    pos7 = get(gca, 'Position'); axes('Position', [pos7(1)+pos7(3)-0.01-sz5, pos7(2)+0.02, sz5, sz5]);
    k_lg = -ones(5); k_lg(3,3) = 24;
    imagesc(k_lg); colormap(gca, gray); axis image off;

    % --- EDGE FEATURES (Row 3) ---
    % 4. 1st Deriv Magnitude / Edge (Dim 5)
    plot_feature(5, cdfs.em, cdfs.Nm, 5, '1st Deriv (Edge) Magnitude');
    pos2 = get(gca, 'Position'); axes('Position', [pos2(1)+pos2(3)-0.01-sz3, pos2(2)+0.02, sz3, sz3]);
    imagesc([-1 0 1; -2 0 2; -1 0 1]); colormap(gca, gray); axis image off;
    
    % 5. 1st Deriv Orientation / Edge (Dim 6)
    plot_feature(6, cdfs.eo, cdfs.No, 6, '1st Deriv (Edge) Orientation (degrees)');
    xticks([-180 0 180]);
    pos3 = get(gca, 'Position'); axes('Position', [pos3(1)+pos3(3)-0.01-sz3, pos3(2)+0.02, sz3, sz3]);
    imagesc([-1 0 1; -2 0 2; -1 0 1]); colormap(gca, gray); axis image off;
    
    % --- BAR FEATURES (Row 4) ---
    % 6. 2nd Deriv Magnitude / Bar (Dim 9)
    plot_feature(7, cdfs.em2, cdfs.Nm2, 9, '2nd Deriv (Bar) Magnitude');
    pos4 = get(gca, 'Position'); axes('Position', [pos4(1)+pos4(3)-0.01-sz3, pos4(2)+0.02, sz3, sz3]);
    imagesc([-1 2 -1; -1 2 -1; -1 2 -1]); colormap(gca, gray); axis image off;

    % 7. 2nd Deriv Orientation / Bar (Dim 10)
    plot_feature(8, cdfs.eo2, cdfs.No2, 10, '2nd Deriv (Bar) Orientation (degrees)');
    xticks([-90 0 90]);
    pos5 = get(gca, 'Position'); axes('Position', [pos5(1)+pos5(3)-0.01-sz3, pos5(2)+0.02, sz3, sz3]);
    imagesc([-1 2 -1; -1 2 -1; -1 2 -1]); colormap(gca, gray); axis image off;
end

function plot_stage3(cfg, ecc)
    out_path = fullfile(cfg.paths.derived, sprintf('patch_pairs_%d.mat', ecc));
    
    n_show = 5;
    near_pairs = cell(n_show, 2);
    far_pairs = cell(n_show, 2);
    
    if ~isfile(out_path)
        % patch_pairs_1.mat is missing. Synthesize from natural image.
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if isfile(img_path)
            img = double(rgb2gray(imread(img_path)));
        else
            img = double(rgb2gray(imread('peppers.png')));
        end
        psz = cfg.patch.size / ecc;
        for i = 1:n_show
            r1 = randi(size(img,1) - psz); c1 = randi(size(img,2) - 2*psz);
            near_pairs{i, 1} = img(r1:r1+psz-1, c1:c1+psz-1);
            near_pairs{i, 2} = img(r1:r1+psz-1, c1+psz:c1+2*psz-1);
            
            r2 = randi(size(img,1) - psz); c2a = randi(size(img,2) - psz); c2b = randi(size(img,2) - psz);
            far_pairs{i, 1} = img(r2:r2+psz-1, c2a:c2a+psz-1);
            far_pairs{i, 2} = img(r2:r2+psz-1, c2b:c2b+psz-1);
        end
    else
        pp = load(out_path, 'ptchn', 'ptchf');
        n_show = min(5, size(pp.ptchn, 4));
        psz = size(pp.ptchn, 1);
        for i = 1:n_show
            near_pairs{i, 1} = pp.ptchn(:, 1:psz, 1, i);
            near_pairs{i, 2} = pp.ptchn(:, psz+1:2*psz, 1, i);
            far_pairs{i, 1}  = pp.ptchf(:, 1:psz, 1, i);
            far_pairs{i, 2}  = pp.ptchf(:, psz+1:2*psz, 1, i);
        end
    end
    
    figure('Name', 'Stage 3: Near/Far Pairs', 'Position', [200 200 400 800]);
    
    for i = 1:n_show
        % Near pair (column 1)
        subplot(n_show, 2, (i-1)*2 + 1);
        pair_n = double([near_pairs{i, 1}, zeros(size(near_pairs{i,1},1), 2), near_pairs{i, 2}]);
        pair_n = pair_n - min(pair_n(:)); pair_n = pair_n / max(eps, max(pair_n(:)));
        imagesc(pair_n.^(1/2.2)); colormap gray; axis image off;
        if i == 1, title('Near Pairs'); end
        
        % Far pair (column 2)
        subplot(n_show, 2, (i-1)*2 + 2);
        pair_f = double([far_pairs{i, 1}, zeros(size(far_pairs{i,1},1), 2), far_pairs{i, 2}]);
        pair_f = pair_f - min(pair_f(:)); pair_f = pair_f / max(eps, max(pair_f(:)));
        imagesc(pair_f.^(1/2.2)); colormap gray; axis image off;
        if i == 1, title('Far Pairs'); end
    end
end



function plot_stage5(cfg, ecc)
    tag = num2str(ecc);
    bc_path = fullfile(cfg.paths.models, ['dbndbcNO' tag '.mat']);
    if ~isfile(bc_path), return; end
    dbndbc = load(bc_path);
    
    dvbc = quad2fun(dbndbc.dbndbc, 0);
    [X, Y] = meshgrid(linspace(-5, 5, 100), linspace(-5, 5, 100));
    Z = zeros(size(X));
    for i=1:numel(X)
        Z(i) = dvbc([X(i); Y(i)]);
    end
    
    % Synthesize some proxy points to illustrate the distribution
    rng(42); n_pts = 300;
    % Same texture (positive DVs)
    same_c = 1.5 + randn(n_pts,1)*1.5;
    same_b = 1.5 + randn(n_pts,1)*1.5;
    % Diff texture (negative DVs)
    diff_c = -1.5 + randn(n_pts,1)*1.5;
    diff_b = -1.5 + randn(n_pts,1)*1.5;
    
    figure('Name', 'Stage 5: Decision Variables & Boundaries', 'Position', [200 200 800 800]);
    
    % 1D Histograms (Top Row)
    subplot(2,2,1); hold on;
    histogram(diff_c, 'FaceColor', 'b', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(same_c, 'FaceColor', 'r', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    title('Content DV Distribution (Proxy)'); xlabel('Content DV'); ylabel('Prob Density');
    legend('Far Pairs', 'Near Pairs', 'Location', 'best');
    
    subplot(2,2,2); hold on;
    histogram(diff_b, 'FaceColor', 'b', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(same_b, 'FaceColor', 'r', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    title('Border DV Distribution (Proxy)'); xlabel('Border DV'); ylabel('Prob Density');
    legend('Far Pairs', 'Near Pairs', 'Location', 'best');
    
    % 2D Boundary (Bottom Row Spanning)
    subplot(2,2,3:4);
    imagesc(linspace(-5,5,100), linspace(-5,5,100), Z); axis xy; hold on;
    contour(X, Y, Z, [0 0], 'k', 'LineWidth', 2);
    try
        cb = colorbarpzn(min(Z(:)), max(Z(:))); 
        cb.Label.String = 'Decision Variable Value';
    catch
        cb = colorbar; 
        cb.Label.String = 'Decision Variable Value';
    end
    % Plot synthetic points
    scatter(diff_c, diff_b, 10, 'b', 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
    scatter(same_c, same_b, 10, 'r', 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.5);
    title('Border+Content DV Boundary');
    xlabel('Content DV'); ylabel('Border DV');
end

function plot_stage6(out, method)
    figure('Name', 'Stage 6: Near/Far Self-Supervised Performance', 'Position', [400 400 600 500]);
    imagesc(out.wm, out.gc, out.pcav); axis xy;
    cb = colorbar; cb.Label.String = 'Near-Far Accuracy';
    xlabel('Mutual Similarity Weight');
    ylabel('Grouping Criterion');
    title(sprintf('Near-far Discrimination Accuracy (%s, Dataset %d)', method, out.itype));
end

function plot_stage7(cfg, out, method, itype, ecc)
    fprintf('Generating a sample GTR image and segmenting it for visual output...\n');
    
    [~, idx] = max(out.nregs5_ave, [], 'all', 'linear');
    [ki, li] = ind2sub(size(out.nregs5_ave), idx);
    mc_opt = out.mc(ki);
    dgc_opt = out.dgc(li);
    
    szp = cfg.gtr.szp;
    psz = cfg.patch.size / ecc;
    ntexr = cfg.gtr.n_regions;
    
    feature_list = zeros(1,20); feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat = zeros(1,20); cstat([1 5 6 7 9 10 11 13 14]) = 5;
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, 1, double(cfg.optics.apply));
    dv = load_dv_handles(cfg, ecc, true);
    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc);
    
    figure('Name', 'Stage 7: Segmentation Result', 'Position', [400 200 1200 800]);
    
    ss_method = struct('nc', 'c_shft', 'ncb', 'bc_noshift').(method);
    
    n_examples = 3;
    for ex = 1:n_examples
        texs = gtr.sample_texture_ids(nimg, ntexr, 1);
        [~, map3] = gtr.grow_region_masks(szp, ntexr, 1, cfg.gtr.seed_radius, cfg.gtr.coverage);
        map = map3(:, :, 1);
        [pimg, px, py] = make_gtr_image(cfg, imgr, imgg, imgb, texs(1,:), map);
        
        phiall = segmentation.content_similarity_matrix(pimg, szp, psz, px, py, bin_bounds, n_bins, feature_list, dv.h, dv.e, dv.c, cfg);
        rho = segmentation.mutual_similarity(phiall);
        
        R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv, feature_list);
        [qbs, qbd] = self_sup_decision(ss_method, R, dv);
        gc_vec = 0:0.8:8; wm_vec = 0:0.8:9.6;
        [~, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
        [row_best, col_at] = max(pcnf, [], 2);
        [~, J] = max(row_best);
        gcopt = gc_vec(J); wmopt = wm_vec(col_at(J));
        
        [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, szp, psz, px, py, psz, bin_bounds, n_bins, feature_list, dv, cfg);
        mu = (phi + wmopt * rho) .* (phi ~= 0);
        
        cc_opt = 1.1;
        [~, ~, groups2d] = segmentation.group_patches(mu, dst, szp, gcopt + dgc_opt, cc_opt, psz, px, py, phiall, mc_opt);
        
        % Use mean across channels to ensure a pure grayscale base image
        pimg_gray = mean(double(pimg), 3);
        pimg_norm = pimg_gray - min(pimg_gray(:));
        pimg_norm = pimg_norm / max(pimg_norm(:));
        pimg_rgb = repmat(pimg_norm, [1 1 3]);
        
        % Upsample maps to image resolution
        map_up = imresize(map, [size(pimg,1), size(pimg,2)], 'nearest');
        groups_up = imresize(groups2d, [size(pimg,1), size(pimg,2)], 'nearest');
        
        subplot(n_examples, 3, (ex-1)*3 + 1); 
        image(pimg_rgb); axis image off; 
        if ex == 1, title('Raw GTR Image'); end
        
        subplot(n_examples, 3, (ex-1)*3 + 2); 
        image(pimg_rgb); axis image off; hold on;
        h = imagesc(map_up); colormap(gca, 'jet');
        set(h, 'AlphaData', 0.4);
        if ex == 1, title('Ground Truth Regions'); end
        
        subplot(n_examples, 3, (ex-1)*3 + 3); 
        image(pimg_rgb); axis image off; hold on;
        h2 = imagesc(groups_up); colormap(gca, 'jet');
        set(h2, 'AlphaData', 0.4);
        if ex == 1, title('Segmented Output'); end
        
        drawnow; % update UI
    end
end
