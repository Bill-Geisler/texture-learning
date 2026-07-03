function setup()
% SETUP  Put texture-learning and its dependencies on the MATLAB path.
%   Run once per MATLAB session before using the pipeline:
%       >> setup
%
%   Adds to the path:
%     * this repo (its +segmentation and +gtr packages, and pipeline/)
%     * data/models  (shipped trained artifacts: PCA/CDF/bin/DV .mat files)
%     * vision-commons (the shared code library) -- a git submodule inside this
%       repo, or a sibling folder next to it (the lab's local dev layout)
%
%   Also VERIFIES the required MATLAB add-on toolboxes are installed. These are
%   installed through the MATLAB Add-On Explorer / File Exchange -- they are NOT
%   bundled with this repo and NOT fetched as source:
%     * Integrate and Classify Normal Distributions  (classify_normals, quad2fun)
%         https://github.com/abhranildas/IntClassNorm
%     * Generalized chi-square distribution  (gx2*, used by the above)
%         https://github.com/abhranildas/gx2

    repo_root = fileparts(mfilename('fullpath'));
    addpath(repo_root);                                        % local +segmentation, +gtr
    addpath(fullfile(repo_root, 'pipeline'));                  % s1..s7 pipeline stages
    addpath(genpath(fullfile(repo_root, 'data', 'models')));   % shipped .mat artifacts

    % --- shared code (our own): submodule inside the repo, else sibling folder ---
    commons = locate_folder(repo_root, 'vision-commons');
    if isempty(commons)
        warning('texture_learning:setup:noCommons', ...
            ['vision-commons not found (looked for a submodule in this repo and a sibling ', ...
             'folder). Clone with --recurse-submodules, or place vision-commons next to this repo.']);
    else
        addpath(commons);                                     % exposes vislib.*, nat_stat_bayes.*
    end

    % --- installed add-on toolboxes (verify only; do NOT add their source) ---
    require_toolbox('classify_normals', ...
        'Integrate and Classify Normal Distributions', 'https://github.com/abhranildas/IntClassNorm');
    require_toolbox('gx2cdf', ...
        'Generalized chi-square distribution (gx2)', 'https://github.com/abhranildas/gx2');
end

function folder = locate_folder(repo_root, name)
% Prefer a submodule inside the repo; fall back to a sibling folder.
    candidates = {fullfile(repo_root, name), fullfile(repo_root, '..', name)};
    folder = '';
    for i = 1:numel(candidates)
        if isfolder(candidates{i})
            folder = candidates{i};
            return;
        end
    end
end

function require_toolbox(probe_function, toolbox_name, url)
% Warn (with install guidance) if a required add-on toolbox is not installed.
    if exist(probe_function, 'file') == 0
        warning('texture_learning:setup:missingToolbox', ...
            ['Required MATLAB toolbox "%s" not found (cannot find %s). Install it via the ', ...
             'MATLAB Add-On Explorer / File Exchange: %s'], toolbox_name, probe_function, url);
    end
end
