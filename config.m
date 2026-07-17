function cfg = config()
% CONFIG  Central configuration for the texture-learning pipeline.
%   cfg = config()  returns a struct of data paths, optical/physical constants,
%   the camera->LMS colour matrix, patch geometry, normalization defaults, and
%   the task-feature definitions. Pipeline stage functions take cfg and may
%   override stage-specific fields.
%
%   EDIT cfg.paths.data_root below if the shared data store (vislab-common/data)
%   is not next to this repo.

    repo_root = fileparts(mfilename('fullpath'));

    % --- data locations ---
    cfg.paths.repo_root      = repo_root;
    cfg.paths.data_root      = fullfile(repo_root, '..', 'vislab-common', 'data');   % shared lab data store
    cfg.paths.natural_images = fullfile(cfg.paths.data_root, 'CPS natural images');
    cfg.paths.textures       = fullfile(cfg.paths.data_root, 'textures');
    cfg.paths.models         = fullfile(repo_root, 'data', 'models');      % shipped trained artifacts
    cfg.paths.stimuli        = fullfile(repo_root, 'data', 'stimuli');     % generated (patch pairs, results)

    % --- eye optics (Watson OTF) ---
    cfg.optics.ppd            = 60;      % pixels/deg for ALL images (natural, textures, GTR/display):
                                         % the human psychophysics display resolution. (Was 64 for the
                                         % calibrated natural images; unified to 60 -- requires
                                         % regenerating s1-s5 artifacts. See twin-net/net_plan.md.)
    cfg.optics.pupil_diameter = 4;       % mm
    cfg.optics.wavelength     = 550;     % nm
    cfg.optics.apply          = true;    % apply optics (the "_otf" / filter == 1 path)

    % --- calibrated natural-image dataset (for learning priors: stages s1, s2) ---
    cfg.natural.sets      = {'Set9_16', 'Set10_16', 'Set12_16'};  % file-name stems in cfg.paths.natural_images
    cfg.natural.max_val   = 2^14 - 1;   % 14-bit pixel max (images scaled by 255/max_val)
    cfg.natural.target_isolated_patches = 7820;      % total isolated patches to sample across all images
    cfg.natural.target_nearfar_references = 3910;    % total near/far reference locations to sample

    % --- camera RGB -> human LMS cone matrix: now the shared lab calibration,
    %     loaded automatically by vislab.lib.rgb2lms from vislab-common/data/cps_rgb2lms.mat
    %     (no longer hardcoded here). ---

    % --- patch geometry at eccentricity 1 (fovea); divide by the eccentricity for the periphery ---
    cfg.patch.image_size = 640;   % GTR image size in pixels (eccentricity 1, fovea)
    cfg.patch.size       = 64;    % 1-deg patch size in pixels (eccentricity 1, fovea)

    % --- texture-database ingestion flags (single source, used by both the Bayesian
    %     load_texture_images and the twin network's texture test set via source_to_lms):
    %       ext    file extension           gray   grayscale sheet -> replicate to 3 channels
    %       gamma  linearize gamma-compressed sheet   resize  1024px pertex sheet -> image_size ---
    cfg.textures.brodatz = struct('ext','gif','gray',true, 'gamma',false,'resize',false);
    cfg.textures.fabric  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.mcgill  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.vistex  = struct('ext','png','gray',false,'gamma',true, 'resize',false);
    cfg.textures.pertex  = struct('ext','png','gray',true, 'gamma',false,'resize',true);

    % --- luminance/contrast normalization ---
    cfg.norm.target_mean     = 128;
    cfg.norm.target_contrast = 0.25;

    % --- decision-variable computation params (content-similarity / mk_phi context) ---
    cfg.dv.power_suppress     = 16;    % weak Fourier-power suppression (beta); Geisler unified content-sim (was 10) to match DV training (2026-07)
    cfg.dv.edge_thresh        = 50;    % gradient threshold for the edge-count feature
    cfg.dv.sd1  = 1;  cfg.dv.nsd1 = 3; % 1st-derivative steerable kernel (edges)
    cfg.dv.sd2  = 1;  cfg.dv.nsd2 = 3; % 2nd-derivative steerable kernel (bars)
    cfg.dv.contrast_normalize = true;  % contrast-normalize before edge features

    % --- GTR images / segmentation experiments (stages s6, s7) ---
    cfg.gtr.szp          = 10;    % image size in patches (10x10 = 100 patches)
    cfg.gtr.n_regions    = 5;     % texture regions per GTR image (ntexr)
    cfg.gtr.seed_radius  = 1.0;   % region-seed radius as fraction of max
    cfg.gtr.coverage     = 1.0;   % fraction of the grid filled by regions
    cfg.gtr.dcrit        = 7.0;   % min separation (patches) for a "far" pair
    cfg.gtr.power_suppress = 16;  % weak-power beta for the per-pair DVs (matches cfg.dv.power_suppress=16)

    % --- reproducibility ---
    cfg.seed = 0;

    % --- demo plots ---
    cfg.demo.scatter_points = 10000;   % max points drawn in the demo's 3D scatter plots

    % --- task-feature definitions (indices used throughout the DV code) ---
    %   1 A pixel (achromatic)     8  bar count
    %   2 B pixel (blue-yellow)    9  bar magnitude
    %   3 R pixel (red-green)     10  bar orientation
    %   4 edge count             11  bar magnitude x orientation
    %   5 edge magnitude         12  center-surround ratio (small)
    %   6 edge orientation       13  center-surround linear (small)
    %   7 edge mag x orientation 14  center-surround linear (large)
    cfg.features.names = { 'A pixel','B pixel','R pixel', ...
        'edge count','edge mag','edge ori','edge mag x ori', ...
        'bar count','bar mag','bar ori','bar mag x ori', ...
        'cs ratio small','cs linear small','cs linear large' };
    cfg.features.spot_dims    = [1 13 14];  % spot/color features fed to the spot DV
    cfg.features.edge_dims    = [5 7 9 10]; % edge/bar features computed by dv_edge_hist
    cfg.features.edge_dv_dims = [5 9 10];   % subset fed to the content edge DV (skips feature 7)
end
