function setup()
% SETUP  Put texture-learning and its dependencies on the MATLAB path.
%   Run once per MATLAB session before using the pipeline:
%       >> setup
%
%   Adds to the path:
%     * this repo (its +segmentation and +gtr packages, pipeline/, and twin-net/ --
%       the latter needs the Deep Learning Toolbox)
%     * data/models  (shipped trained artifacts: PCA/CDF/bin/DV .mat files)
%     * vislab (the shared code library) -- the +vislab package inside the
%       sibling vislab-common repo (the lab's local dev layout)
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
    addpath(fullfile(repo_root, 'demo'));                      % run_demo plotting/helper functions
    addpath(fullfile(repo_root, 'twin-net'));                  % twin-network code (needs Deep Learning Toolbox)
    addpath(genpath(fullfile(repo_root, 'data', 'models')));   % shipped .mat artifacts

    % --- shared lab library (vislab): a sibling folder next to this repo.
    %     If it isn't found, try to clone it automatically (needs git + network);
    %     if that fails too, warn with a manual clone command. ---
    commons = locate_folder(repo_root, '+vislab');
    if isempty(commons)
        commons = fetch_commons(repo_root);
    end
    if isempty(commons)
        warning('texture_learning:setup:noCommons', ...
            ['vislab-common not found and could not be fetched automatically. ', ...
             'Clone it next to this repo:  git clone https://github.com/abhranildas/vislab-common']);
    else
        addpath(fileparts(commons));                                     % exposes vislab.lib.*, vislab.nat_stat_bayes.*
    end

    % --- installed add-on toolboxes -------------------------------------------
    % These are installed via the MATLAB Add-On Explorer / File Exchange; we do
    % NOT bundle or add their source from this repo. Normally MATLAB puts an
    % installed add-on's folder on the path at startup -- but that does not always
    % happen in headless (`matlab -batch`) sessions (observed: gx2 gets added,
    % IntClassNorm does not). So if a probe function is missing, we locate the
    % *installed* add-on and add it ourselves, then warn only if it is truly
    % absent. gx2 is handled first because IntClassNorm depends on it.
    ensure_addon_on_path('gx2cdf', 'Generalized chi-square distribution*', ...
        'Generalized chi-square distribution (gx2)', 'https://github.com/abhranildas/gx2');
    ensure_addon_on_path('classify_normals', 'Integrate and Classify Normal Distributions*', ...
        'Integrate and Classify Normal Distributions', 'https://github.com/abhranildas/IntClassNorm');

    % --- shared data store: vislab-common/data (~23 GB, obtained manually) ---
    if ~isfolder(fullfile(repo_root, '..', 'vislab-common', 'data'))
        warning('texture_learning:setup:noData', ...
            ['vislab-common/data not found next to this repo. It is the large (~23 GB) shared data store ', ...
             '(natural images + texture sheets); obtain it separately and place it in vislab-common/data ', ...
             '(see README). Code that reads it will fail until then.']);
    end
end

function folder = fetch_commons(repo_root)
% Auto-fetch the shared library by cloning the vislab-common repo as a sibling
% (../vislab-common); the +vislab package lives inside it. Needs git on the PATH
% and network access; returns '' if the clone fails (caller then warns).
    folder = '';
    repo_dir = fullfile(repo_root, '..', 'vislab-common');
    url = 'https://github.com/abhranildas/vislab-common.git';
    fprintf('vislab-common not found; trying to clone it to %s ...\n', repo_dir);
    [status, out] = system(sprintf('git clone "%s" "%s"', url, repo_dir));
    target = fullfile(repo_dir, '+vislab');
    if status == 0 && isfolder(fullfile(target, '+lib'))
        folder = target;
        fprintf('Cloned vislab-common.\n');
    else
        fprintf(2, 'Could not auto-fetch vislab-common (git missing or offline?).\n%s\n', out);
    end
end

function folder = locate_folder(repo_root, name)
% Find the +vislab package: inside the sibling vislab-common repo (canonical),
% else as a sibling of / inside this repo (older dev layouts).
    candidates = {fullfile(repo_root, '..', 'vislab-common', name), ...
                  fullfile(repo_root, name), ...
                  fullfile(repo_root, '..', name)};
    folder = '';
    for i = 1:numel(candidates)
        if isfolder(candidates{i})
            folder = candidates{i};
            return;
        end
    end
end

function ensure_addon_on_path(probe_function, folder_pattern, toolbox_name, url)
% Ensure an INSTALLED add-on toolbox's functions are on the path.
%   If PROBE_FUNCTION already resolves, do nothing. Otherwise find the installed
%   add-on folder (matching FOLDER_PATTERN under the add-ons install directory)
%   and add it -- this uses the installed add-on, never any lab-local source.
%   Warn with install guidance only if it still cannot be found (not installed).
    if exist(probe_function, 'file') ~= 0
        return;                               % already on the path -- nothing to do
    end
    tb_dir = addons_toolboxes_dir();
    if ~isempty(tb_dir)
        hits = dir(fullfile(tb_dir, folder_pattern));
        for i = 1:numel(hits)
            if hits(i).isdir
                addpath(genpath(fullfile(tb_dir, hits(i).name)));
            end
        end
    end
    if exist(probe_function, 'file') == 0
        warning('texture_learning:setup:missingToolbox', ...
            ['Required MATLAB toolbox "%s" not found (cannot find %s). Install it via the ', ...
             'MATLAB Add-On Explorer / File Exchange: %s'], toolbox_name, probe_function, url);
    end
end

function d = addons_toolboxes_dir()
% Best-effort path to the "<...>/MATLAB Add-Ons/Toolboxes" install directory,
% without hardcoding a username. Try the add-ons install-folder setting first,
% then fall back to the parent folder of an already-resolvable add-on function.
    d = '';
    try
        root = settings().matlab.addons.InstallationFolder.ActiveValue; % "<...>/MATLAB Add-Ons"
        cand = fullfile(root, 'Toolboxes');
        if isfolder(cand), d = cand; return; end
        if isfolder(root),  d = root;  return; end
    catch
        % settings tree not available in this release -- use the fallback below
    end
    for probe = {'gx2cdf', 'gx2pdf', 'gx2inv'}     % gx2 auto-registers; use it as an anchor
        w = which(probe{1});
        if ~isempty(w)
            d = fileparts(fileparts(w));           % ...\Toolboxes\<addon>\fn.m -> ...\Toolboxes
            return;
        end
    end
end
