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

% Dock all demo figures into one window. Works in the classic MATLAB desktop.
% (In R2025a's new desktop this docks to the desktop rather than a figure
% container, and programmatic docking is limited -- use the figure window's dock
% button if it doesn't take.)
set(0, 'defaultfigurewindowstyle', 'docked');

% --- 0. Choose the demo mode ('quick' or 'full') ---
%   'quick': fast -- skips training (stages 1-5), uses the shipped pre-trained bounds.
%   'full':  re-trains the model from scratch over all patch pairs (slow).
demo_type = '';
while ~ismember(demo_type, {'quick', 'full'})
    demo_type = lower(strtrim(input('Run demo in ''quick'' or ''full'' mode? [quick/full, default quick]: ', 's')));
    if isempty(demo_type), demo_type = 'quick'; end
end

if strcmp(demo_type, 'full')
    reply = input(['\nThis will train the model from scratch, which takes a while, and will replace the ' ...
        'model parameter files that came pre-installed with this package. Continue? (y/n): '], 's');
    if ~strcmpi(reply, 'y')
        fprintf('Aborting: run_demo stopped before training.\n');
        return;
    end

    fprintf('\n--- Running Pipeline Stages 1-5: Training the Model ---\n');

    % Stage 1: Learn Color Transform (Decorrelation)
    % First, the raw RGB camera sensor responses are converted into LMS cone responses.
    % This initial RGB-to-LMS transform uses a fixed matrix calibrated to the specific
    % camera used to capture the natural image dataset.
    % Next, consistent with early visual processing (and optimal encoding), we transform
    % the LMS axes to an ABR (Achromatic, Blue-yellow, Red-green) space so the joint
    % distribution of features has minimal correlation.
    fprintf('-> Running Stage 1: s1_learn_color_transform...\n');
    % Capture the learned LMS->ABR rotation to plot in Stage 1 (over all images).
    coeff_s1 = s1_learn_color_transform(cfg, true);

    % Stage 2+3: Learn Feature Priors AND Make Near/Far Training Pairs (single pass)
    % In one pass over the natural images, compute the natural prior distributions
    % (CDFs) of the low-level image features, and form the proximity-proxy training
    % pairs: "near" pairs (likely same texture) and "far" pairs (likely different).
    % Priors are eccentricity-dependent (ecc blurs + downsamples), so they are learned
    % from the same ecc image as the pairs.
    ecc = 1; % Eccentricity of 1 = fovea
    fprintf('-> Running Stage 2+3: s23_learn_priors_and_pairs...\n');
    s23_learn_priors_and_pairs(cfg, ecc, true);

    % Stage 4: Optimize Adaptive Histogram Bins
    % For each feature dimension, we discretize the feature space into adaptive bins.
    % This prepares the data to estimate the task-specific feature likelihoods (i.e.
    % probability distributions of features for near vs. far pairs).
    fprintf('-> Running Stage 4: s4_optimize_bins...\n');
    s4_optimize_bins(cfg, [1 5 9 10 13 14], ecc, true);   % spot [1 13 14] + edge DV [5 9 10]

    % Stage 5: Train Decision Variables and Bounds
    % Using the near/far pairs as ground truth, we train the Bayesian decision variables
    % (content, border, and combined) and the optimal decision bounds (e.g., QSVM boundary).
    % This maximizes near-far categorization accuracy, which the paper shows mathematically
    % also optimizes same-different categorization.
    fprintf('-> Running Stage 5: s5_train_decision_vars...\n');
    % Capture the exact points the bounds trained on, to plot in Stage 5.
    [R_near, R_far] = s5_train_decision_vars(cfg, ecc, 1, true);

    fprintf('Training complete.');
else
    fprintf('\nSkipping Stages 1-5 (Training). Using the pre-built shipped models.\n');
    R_near = []; R_far = [];
    coeff_s1 = [];   % quick mode: plot_stage1 uses the shipped transform + a single image
end

%% --- PLOTTING STAGES 1-5 ---
ecc = 1;
    fprintf('-> Plotting Stage 1 (colour transforms)...\n');
    plot_stage1(cfg, coeff_s1);            % full mode: learned coeff + pixels from all images; quick: shipped + one image
    fprintf('-> Plotting Stage 1b (multi-scale gradient structure)...\n');
    plot_stage1b_gradients(cfg, coeff_s1); % same split; multi-scale gradient structure (illustrative, not in pipeline)
    fprintf('-> Plotting Stage 2 (feature priors)...\n');
    plot_stage2(cfg, ecc);
    fprintf('-> Plotting Stage 3 (near/far pairs)...\n');
    plot_stage3(cfg, ecc);

    % Points for the Stage 5 plots. Full mode reuses the exact pairs the bounds
    % trained on (all images, captured above). Quick mode used the shipped bounds
    % without training, so it samples a representative set from a single image.
    if isempty(R_near)
        fprintf('\n--- Sampling patch responses for Stage 5 plots ---\n');
        [R_near, R_far] = compute_demo_responses(cfg, ecc);
    else
        fprintf('\n--- Stage 5 plots use the %d near / %d far training pairs ---\n', ...
            size(R_near, 1), size(R_far, 1));
    end

    fprintf('-> Plotting Stage 5 (intermediate spot/edge/border DVs)...\n');
    plot_stage5_intermediate(cfg, ecc, R_near, R_far);
    fprintf('-> Plotting Stage 5 (trained decision bounds)...\n');
    plot_stage5(cfg, ecc, R_near, R_far);
drawnow;

% --- 1. check the shipped (or newly trained) artifacts are present ---
if cfg.optics.apply, bins_file = 'AHEO_bins.mat'; else, bins_file = 'AHE_bins.mat'; end
needed = {prior_filename(cfg, 1), ...
          'decision_bounds_ecc_1.mat', bins_file};
present = cellfun(@(f) exist(fullfile(cfg.paths.models, f), 'file') > 0, needed);
if ~all(present)
    error('demo:missingArtifacts', ...
        ['Missing trained artifacts in data/models: %s\n' ...
         'Run pipeline stages s1-s5 first by setting run_training_stages=true, or restore data/models.'], ...
        strjoin(needed(~present), ', '));
end
fprintf('Trained model artifacts found in %s\n', cfg.paths.models);

% --- 2. run the self-supervised discrimination stage (s6) on GTR images ---
% Randomize the GTR image draws so stages 6/7 build different textures each run.
% (MATLAB starts every session from the same default RNG state, so a shuffle -- not
% just the absence of a fixed seed -- is what makes the images vary.)
rng('shuffle');
method = 'bc';    % per-image retraining of the border+content bound (paper: NCB)
itype  = 3;       % 3 = Brodatz (source textures)
ntrl   = 2;       % GTR images to average over (small, for a quick demo)

fprintf('\n--- Stage 6: Self-Supervised Discrimination ---\n');
fprintf('Applying the decision variables learned from natural images (Stages 1-5)\n');
fprintf('to GTR (grown-texture-region) images built from Brodatz source textures.\n');
fprintf('Method: %s, Dataset: Brodatz, Trials: %d.\n', method, ntrl);
fprintf('(Builds GTR images and computes all pairwise similarities.)\n');
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
drawnow;

% --- 4. apply the same segmentation to a natural image (self-supervised, no ground truth) ---
fprintf('\n--- Stage 8: Natural-Image Segmentation ---\n');
fprintf('Running the same self-supervised segmentation (64x64 patches) on a natural image.\n');
fprintf('It has no ground-truth regions, so gcopt/wmopt are still learned from proximity,\n');
fprintf('and the region-merge parameters are carried over from the Stage 7 GTR sweep.\n');
plot_stage8_natural(cfg, out7, 'ncb', ecc);

fprintf('\nDemo Complete! Check the generated figure windows.\n');
