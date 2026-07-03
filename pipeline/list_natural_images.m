function files = list_natural_images(cfg)
% LIST_NATURAL_IMAGES  Full paths of all calibrated natural images across all sets.
%   files = list_natural_images(cfg)
%
%   Collects every <set>_*.png in cfg.paths.natural_images for each stem in
%   cfg.natural.sets. Shared by the natural-image pipeline stages (s1, s2, s4).
%
%   Output
%     files - cell array of full file paths.

    files = {};
    for s = 1:numel(cfg.natural.sets)
        d = dir(fullfile(cfg.paths.natural_images, [cfg.natural.sets{s} '_*.png']));
        for k = 1:numel(d)
            files{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
        end
    end
    if isempty(files)
        error('texture_learning:noNaturalImages', ...
            'No natural images found in %s (looked for %s_*.png).', ...
            cfg.paths.natural_images, strjoin(cfg.natural.sets, ', '));
    end
end
