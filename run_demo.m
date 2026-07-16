% run_demo.m  —  End-to-end demonstration of the texture-learning pipeline.
%
%   Run it (from anywhere):   >> run <path-to-repo>/run_demo.m
%   or:   >> cd <repo>; setup; run run_demo.m
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
%   For convenience, this demo defaults to `demo_type = 'quick'`, which skips
%   stages 1-5. Instead of loading all patch pairs to train the decision
%   boundaries from scratch, it generates illustrative plots using a fast subset
%   of patch pairs and uses the SHIPPED pre-trained decision bounds (which
%   fully cover all bounds needed for the entire demo pipeline).
%
%   If you set `demo_type = 'full'`, the demo will load all patch pairs to
%   actually train the decision bounds from scratch, and run the entire pipeline
%   (this is computationally expensive).
%
%   The plotting and response-computation helpers live in demo/ (added to the
%   path by setup): plot_stage1, plot_stage1b_gradients, plot_stage2, plot_stage3,
%   plot_stage5_intermediate, plot_stage5, plot_stage6, plot_stage7,
%   compute_demo_responses, pair_responses, apply_dv.

% --- locate the repo and set up the path ---
repo_root = fileparts(mfilename('fullpath'));
cd(repo_root);
setup;
cfg = config;

% --- 0. (Optional) Run Pipeline Stages 1-5: Training the Model ---
% Set demo_type to 'quick' or 'full':
%   'quick': Fast version using a few patch pairs and shipped decision boundaries.
%   'full':  Load all patch pairs to actually train the decision bounds.
demo_type = 'quick';

if strcmp(demo_type, 'full')
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

    % Stage 2: Learn Feature Priors
    % We compute the natural prior probability distributions (Cumulative
    % Distribution Functions) for the generic image features (edge, spot, power spectrum)
    % measured from natural images.
    fprintf('-> Running Stage 2: s2_learn_feature_priors...\n');
    s2_learn_feature_priors(cfg);

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
    fprintf('-> Running Stage 4: s4_optimize_bins...\n');
    s4_optimize_bins(cfg, [1 5 6 7 9 10 11 13 14], ecc);

    % Stage 5: Train Decision Variables and Bounds
    % Using the near/far pairs as ground truth, we train the Bayesian decision variables
    % (content, border, and combined) and the optimal decision bounds (e.g., QSVM boundary).
    % This maximizes near-far categorization accuracy, which the paper shows mathematically
    % also optimizes same-different categorization.
    fprintf('-> Running Stage 5: s5_train_decision_vars...\n');
    s5_train_decision_vars(cfg, ecc);

    fprintf('Training complete.');
else
    fprintf('\nSkipping Stages 1-5 (Training). Using the pre-built shipped models.\n');
end

%% --- PLOTTING STAGES 1-5 ---
fprintf('\n--- Generating Illustrative Plots for Stages 1-5 ---\n');
ecc = 1;
    plot_stage1(cfg);
    plot_stage1b_gradients(cfg);   % illustrative: multi-scale gradient structure (not in pipeline)
    plot_stage2(cfg, ecc);
    plot_stage3(cfg, ecc);

    fprintf('\n--- Computing patch responses for Stage 5 Demo (n=150) ---\n');
    [R_near, R_far] = compute_demo_responses(cfg, ecc);

    plot_stage5_intermediate(cfg, ecc, R_near, R_far);
    plot_stage5(cfg, ecc, R_near, R_far);
drawnow;

% --- 1. check the shipped (or newly trained) artifacts are present ---
needed = {'priors_abr_mo13_mo23_cs33_otf.mat', ...
          'decision_bounds_ecc1.mat', 'AHEO_bins.mat'};
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
fprintf('\nStage 6 Result: peak mean same-different accuracy = %.1f%%\n', 100 * best);
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
