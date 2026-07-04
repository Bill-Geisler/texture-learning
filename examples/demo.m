% demo.m  —  End-to-end demonstration of the texture-learning pipeline.
%
%   Run it (from anywhere):   >> run <path-to-repo>/examples/demo.m
%   or:   >> cd <repo>; setup; run examples/demo.m
%
% What it does:
%   Uses the SHIPPED trained model in data/models (produced by pipeline stages
%   s1-s5) to run the self-supervised texture-discrimination stage (s6) on
%   Brodatz grown-texture-region (GTR) images, then prints and plots the
%   resulting near-far / same-different accuracy surface (cf. the paper's Fig. 4).
%
%   Re-learning the model from scratch (stages s1-s5) instead requires the
%   calibrated natural images in global_data; see the README "pipeline" section.
%   Datasets other than Brodatz/Fabric (Pertex, VisTex, McGill) need additional
%   data — see USER_TODO.md.

% --- locate the repo and set up the path ---
this_dir  = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_dir);
cd(repo_root);
setup;
cfg = config;

% --- 1. check the shipped trained artifacts are present ---
needed = {'PCA_matrix_3_OTF.mat', 'cdfs_abr_mo13_mo23_cs33_otf.mat', ...
          'dbndhNO1.mat', 'dbndeNO1.mat', 'dbndcNO1.mat', 'dbndbNO1.mat', 'AHEO511.mat'};
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
itype  = 3;       % 3 = Brodatz (data present in global_data/textures/brodatz)
lev    = 1;       % foveal
ntrl   = 2;       % GTR images to average over (small, for a quick demo)

fprintf('\nRunning s6 discrimination: method=%s, Brodatz, %d trial(s).\n', method, ntrl);
fprintf('(Builds GTR images and computes all pairwise similarities -- takes a few minutes.)\n');
try
    out = s6_selfsup_discrimination(cfg, method, itype, lev, ntrl);
catch err
    if contains(err.identifier, 'datasetMissing') || contains(err.identifier, 'pertexPending')
        error('demo:noTextureData', ...
            ['Brodatz texture sheets are not available/readable in %s.\n' ...
             'Ensure global_data/textures/brodatz/B*.gif are downloaded locally (see USER_TODO.md).'], ...
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
