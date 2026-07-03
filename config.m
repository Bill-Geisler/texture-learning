function cfg = config()
% CONFIG  Central configuration for the texture-learning pipeline.
%   cfg = config()  returns a struct of data paths, optical/physical constants,
%   the camera->LMS colour matrix, patch geometry, normalization defaults, and
%   the task-feature definitions. Pipeline stage functions take cfg and may
%   override stage-specific fields.
%
%   EDIT cfg.paths.data_root below if the shared global_data store is not a
%   sibling of this repo.

    repo_root = fileparts(mfilename('fullpath'));

    % --- data locations ---
    cfg.paths.repo_root      = repo_root;
    cfg.paths.data_root      = fullfile(repo_root, '..', 'global_data');   % shared lab data store
    cfg.paths.natural_images = fullfile(cfg.paths.data_root, 'CPS natural images');
    cfg.paths.textures       = fullfile(cfg.paths.data_root, 'textures');
    cfg.paths.models         = fullfile(repo_root, 'data', 'models');      % shipped trained artifacts
    cfg.paths.derived        = fullfile(repo_root, 'data', 'derived');     % generated (patch pairs, results)

    % --- eye optics (Watson OTF) ---
    cfg.optics.ppd            = 60;      % pixels per degree
    cfg.optics.pupil_diameter = 4;       % mm
    cfg.optics.wavelength     = 550;     % nm
    cfg.optics.apply          = true;    % apply optics (the "_otf" / filter == 1 path)

    % --- camera RGB -> human LMS cone matrix ---
    cfg.color.rgb_to_lms = [ 4.370, 1.338,  0.118;
                             6.984, 8.373, -0.922;
                            -1.096,-0.667,  5.814];

    % --- patch geometry at level 1 (fovea); divide by the eccentricity level for others ---
    cfg.patch.image_size = 640;   % GTR image size in pixels (level 1)
    cfg.patch.size       = 64;    % 1-deg patch size in pixels (level 1)

    % --- luminance/contrast normalization ---
    cfg.norm.target_mean     = 128;
    cfg.norm.target_contrast = 0.25;

    % --- reproducibility ---
    cfg.seed = 0;

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
    cfg.features.spot_dims = [1 13 14];     % default spot/color features used by the pipeline
    cfg.features.edge_dims = [5 7 9 10];    % default edge/bar features used by the pipeline
end
