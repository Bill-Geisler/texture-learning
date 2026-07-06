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
%   texture-discrimination stage (s6) on Brodatz grown-texture-region (GTR) images.
%   It then prints and plots the resulting near-far / same-different accuracy surface 
%   (cf. the paper's Fig. 4). All six texture datasets (Pertex, Fabric, Brodatz, VisTex, McGill) 
%   are supported; each just needs its sheets present in vislab-common/data/textures.
%
%   To run stages 1-5, set `run_training_stages = true` below.

% --- locate the repo and set up the path ---
repo_root = fileparts(mfilename('fullpath'));
cd(repo_root);
setup;
cfg = config;

% --- 0. (Optional) Run Pipeline Stages 1-5: Training the Model ---
run_training_stages = true; % Set to true to re-train the model from scratch

if run_training_stages
    fprintf('\n--- Running Pipeline Stages 1-5: Training the Model ---\n');
    fprintf('Note: This requires the calibrated natural images in vislab-common/data.\n\n');
    
    % Stage 1: Learn Color Transform (Decorrelation)
    % Consistent with early visual processing (and optimal encoding), we first transform 
    % the color axes (LMS to ABR) so the joint distribution of features has small correlations.
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
    fprintf('\nSkipping Stages 1-5 (Training). Using the pre-built shipped model.\n');
end

% --- 1. check the shipped (or newly trained) artifacts are present ---
needed = {'cdfs_abr_mo13_mo23_cs33_otf.mat', ...
          'dbndhNO1.mat', 'dbndeNO1.mat', 'dbndcNO1.mat', 'dbndbNO1.mat', 'AHEO_bins.mat'};
% (the LMS->ABR transform now lives in the shared vislab-common/data/cps_lms2abr_otf.mat;
%  the demo reads its rotation from the cdfs file, so it isn't checked here.)
present = cellfun(@(f) exist(fullfile(cfg.paths.models, f), 'file') > 0, needed);
if ~all(present)
    error('demo:missingArtifacts', ...
        ['Missing trained artifacts in data/models: %s\n' ...
         'Run pipeline stages s1-s5 first (see README), or restore data/models.'], ...
        strjoin(needed(~present), ', '));
end
fprintf('Trained model found in %s\n', cfg.paths.models);

% --- 2. run the self-supervised discrimination stage on Brodatz ---
method = 'bc';    % per-image retraining of the border+content bound (paper: NCB)
itype  = 3;       % 3 = Brodatz (data present in vislab-common/data/textures/brodatz)
ecc    = 1;       % foveal
ntrl   = 2;       % GTR images to average over (small, for a quick demo)

fprintf('\nRunning s6 discrimination: method=%s, Brodatz, %d trial(s).\n', method, ntrl);
fprintf('(Builds GTR images and computes all pairwise similarities -- takes a few minutes.)\n');
try
    out = s6_selfsup_discrimination(cfg, method, itype, ecc, ntrl);
catch err
    if contains(err.identifier, 'datasetMissing')
        error('demo:noTextureData', ...
            ['Brodatz texture sheets are not available/readable in %s.\n' ...
             'Ensure vislab-common/data/textures/brodatz/B*.gif are downloaded locally (see USER_TODO.md).'], ...
            cfg.paths.textures);
    else
        rethrow(err);
    end
end

% --- 3. report and plot the result ---
[best, idx] = max(out.pcav, [], 'all', 'linear');
[gi, wi] = ind2sub(size(out.pcav), idx);
fprintf('\nResult: peak mean near-far accuracy = %.1f%%\n', 100 * best);
fprintf('        at criterion = %.2f, mutual-similarity weight = %.2f\n', out.gc(gi), out.wm(wi));

figure('Name', 'texture-learning demo');
imagesc(out.wm, out.gc, out.pcav); axis xy; colorbar; clim([0.5 1]);
xlabel('mutual similarity weight');
ylabel('grouping criterion');
title(sprintf('Near-far discrimination accuracy (%s, Brodatz)', method));
fprintf('\nDone. The figure shows accuracy across the criterion x mutual-weight grid.\n');
