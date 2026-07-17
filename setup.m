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
%   Also ensures the two required lab add-on toolboxes are available: if either is
%   missing, setup fetches the .mltbx from its latest GitHub release and installs it
%   automatically (matlab.addons.install):
%     * Integrate and Classify Normal Distributions  (classify_normals, quad2fun)
%         https://www.mathworks.com/matlabcentral/fileexchange/84973-integrate-and-classify-normal-distributions
%     * Generalized chi-square distribution  (gx2*, used by the above)
%         https://www.mathworks.com/matlabcentral/fileexchange/85028-generalized-chi-square-distribution
%   (colorbarpzn, used by a demo plot, now ships inside vislab as vislab.lib.colorbarpzn.)

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

    % --- add-on toolboxes -----------------------------------------------------
    % For each: if its probe function already resolves, do nothing. Else try to add
    % an already-installed copy to the path (MATLAB does not always do this in
    % headless `matlab -batch` sessions). Else download the .mltbx from its latest
    % GitHub release and install it automatically. gx2 is handled first because
    % IntClassNorm depends on it. (colorbarpzn now lives in vislab, added above.)
    ensure_addon_on_path('gx2cdf', 'Generalized chi-square distribution*', ...
        'Generalized chi-square distribution (gx2)', ...
        'https://www.mathworks.com/matlabcentral/fileexchange/85028-generalized-chi-square-distribution', ...
        'abhranildas/gx2-matlab');
    ensure_addon_on_path('classify_normals', 'Integrate and Classify Normal Distributions*', ...
        'Integrate and Classify Normal Distributions', ...
        'https://www.mathworks.com/matlabcentral/fileexchange/84973-integrate-and-classify-normal-distributions', ...
        'abhranildas/IntClassNorm');

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

function ensure_addon_on_path(probe_function, folder_pattern, toolbox_name, url, gh_repo)
% Ensure an add-on toolbox's functions are available.
%   1. If PROBE_FUNCTION already resolves, do nothing.
%   2. Else add an already-installed copy to the path (MATLAB does not always do
%      this in headless sessions) -- matching FOLDER_PATTERN under the add-ons dir.
%   3. Else, if GH_REPO ("owner/name") is given, download the .mltbx from that repo's
%      latest GitHub release and install it (matlab.addons.install), then re-add.
%   4. Else (still missing): open URL (File Exchange page) in the browser and warn.
    if exist(probe_function, 'file') ~= 0
        return;                               % already on the path -- nothing to do
    end
    add_installed_to_path(folder_pattern);
    if exist(probe_function, 'file') ~= 0
        return;
    end
    if nargin >= 5 && ~isempty(gh_repo) && install_from_github_release(gh_repo, toolbox_name)
        add_installed_to_path(folder_pattern);
        if exist(probe_function, 'file') ~= 0
            return;
        end
    end
    if ~batchStartupOptionUsed                % don't pop a browser in headless (-batch) runs
        try, web(url, '-browser'); catch, end
    end
    warning('texture_learning:setup:missingToolbox', ...
        ['Required MATLAB toolbox "%s" not found (cannot find %s) and could not be ', ...
         'auto-installed. Install it (Add-On Explorer / File Exchange), then re-run ', ...
         'setup: %s'], toolbox_name, probe_function, url);
end

function add_installed_to_path(folder_pattern)
% Add an already-installed add-on's folder (matching FOLDER_PATTERN under the
% add-ons install directory) to the path.
    tb_dir = addons_toolboxes_dir();
    if isempty(tb_dir), return; end
    hits = dir(fullfile(tb_dir, folder_pattern));
    for i = 1:numel(hits)
        if hits(i).isdir
            addpath(genpath(fullfile(tb_dir, hits(i).name)));
        end
    end
end

function ok = install_from_github_release(gh_repo, toolbox_name)
% Download the .mltbx asset from GH_REPO's latest GitHub release and install it as
% a MATLAB add-on. Needs network; returns false (and prints why) on any failure.
    ok = false;
    try
        opts = weboptions('UserAgent', 'texture-learning-setup', 'Timeout', 60);
        rel = webread(sprintf('https://api.github.com/repos/%s/releases/latest', gh_repo), opts);
        assets = rel.assets;
        dl_url = '';
        for i = 1:numel(assets)
            if iscell(assets), a = assets{i}; else, a = assets(i); end
            if endsWith(a.name, '.mltbx')
                dl_url = a.browser_download_url;
                break;
            end
        end
        if isempty(dl_url)
            fprintf(2, 'setup: no .mltbx asset in %s''s latest release.\n', gh_repo);
            return;
        end
        fprintf('setup: downloading %s (%s) from GitHub ...\n', toolbox_name, rel.tag_name);
        tmp = [tempname, '.mltbx'];
        websave(tmp, dl_url, opts);
        matlab.addons.install(tmp);
        delete(tmp);
        fprintf('setup: installed %s.\n', toolbox_name);
        ok = true;
    catch e
        fprintf(2, 'setup: could not auto-install %s from GitHub (%s).\n', toolbox_name, e.message);
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
