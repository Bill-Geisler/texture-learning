function texture_ids = sample_texture_ids(n_textures, n_regions, n_trials)
% SAMPLE_TEXTURE_IDS  Random balanced texture-sheet assignment per trial.
%   texture_ids = gtr.sample_texture_ids(n_textures, n_regions, n_trials)
%
%   Assigns a texture-sheet number to each region of each trial's GTR image,
%   drawing from balanced random permutations of 1:n_textures so that sheets are
%   used about equally often. (Was mk_texs.m.)
%
%   Inputs
%     n_textures - number of texture sheets to choose from.
%     n_regions  - number of texture regions per GTR image.
%     n_trials   - number of trials (images).
%
%   Output
%     texture_ids - [n_trials x n_regions] matrix of texture-sheet indices.

    % Build a long list of stacked random permutations of 1:n_textures, then take
    % the first n_regions*n_trials of them (same random-stream usage as the original).
    n_blocks = floor(n_regions * n_trials / n_textures) + 1;
    texture_list = zeros(n_blocks * n_textures, 1);
    for b = 1:n_blocks
        texture_list((b-1)*n_textures + (1:n_textures)) = randperm(n_textures);
    end
    texture_ids = reshape(texture_list(1:n_regions*n_trials), n_regions, n_trials)';
end
