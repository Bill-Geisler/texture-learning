% texture_same_diff_patches_cnn.m
% Build same/different texture patch-pair TEST sets for the twin CNN, from several
% texture databases in vislab-common/data/textures. Produces TWO sets:
%
%   same,      diff       -- ALL databases combined (balanced), "different" pairs may
%                            cross databases (two textures from anywhere in the pool)
%   same_brod, diff_brod  -- Brodatz only (both patches from Brodatz textures)
%
% Each is [psz psz 2 N] uint8; dim 3 holds the two patches of a pair (1 = reference,
% 2 = partner), matching the natural-image near/far layout so getTwinBatchPairs can
% slice it directly. Saved to data/stimuli/textures/patch_pairs.mat.
%
% Ingestion goes through the shared vislab.nat_stat_bayes.source_to_lms with the
% per-database flags from cfg.textures -- the SAME function and flags the Bayesian
% load_texture_images uses -- so the texture test patches are processed identically
% to the natural-image training patches and cannot diverge from the Bayesian model.
%
% Balancing: each database contributes the same number of distinct textures (capped) and
% the same number of pairs, so the large low-variety pertex set cannot swamp the metric.

cfg = config;
psz = cfg.patch.size;
texdir = cfg.paths.textures;
down_level = 1;              % resolution scale-down; must match the training patches

n_tex_per_db  = 60;          % cap on distinct textures used per DB (subsample larger DBs)
n_same = 10000; n_diff = 10000;          % all-textures pairs of each type
n_same_brod = 5000; n_diff_brod = 5000;  % Brodatz-only pairs of each type

% per-database ingestion flags come from cfg.textures (single source, shared with the
% Bayesian load_texture_images), so gray/gamma/resize can't drift between the models.
db_names = fieldnames(cfg.textures);

% load a capped, random subset of each database as achromatic uint8 images
allTex   = {};                 % every loaded texture (balanced pool)
brodTex  = {};                 % Brodatz subset (for the Brodatz-only set)
for d = 1:numel(db_names)
    name = db_names{d};
    p = cfg.textures.(name);
    files = dir(fullfile(texdir, name, ['*.' p.ext]));
    n_use = min(n_tex_per_db, numel(files));
    sel = randperm(numel(files), n_use);
    fprintf('%s: using %d of %d textures\n', name, n_use, numel(files));
    for i = 1:n_use
        [~, A] = vislab.nat_stat_bayes.source_to_lms(fullfile(files(sel(i)).folder, files(sel(i)).name), cfg, ...
            struct('gray', p.gray, 'gamma', p.gamma, 'resize_pertex', p.resize, 'ecc', down_level));
        A = uint8(A * 255 / max(A(:)));
        allTex{end+1} = A; %#ok<SAGROW>
        if strcmp(name, 'brodatz'), brodTex{end+1} = A; end %#ok<SAGROW>
    end
end

% all-textures set: same = one random texture twice; diff = two different textures from
% anywhere in the pool (cross-database allowed)
[same, diff] = make_pairs(allTex, n_same, n_diff, psz);

% Brodatz-only set (both patches Brodatz)
[same_brod, diff_brod] = make_pairs(brodTex, n_same_brod, n_diff_brod, psz);

% save both sets
outdir = fullfile(cfg.paths.stimuli, 'textures');
if ~exist(outdir, 'dir'); mkdir(outdir); end
if down_level > 1
    outfile = fullfile(outdir, ['patch_pairs_dsmpl_' num2str(down_level) '.mat']);
else
    outfile = fullfile(outdir, 'patch_pairs.mat');
end
save(outfile, 'same', 'diff', 'same_brod', 'diff_brod', '-v7.3')

%% show a few example pairs from the all-textures set (reference | partner)
n_show = 5;
i_same = randi(size(same,4), 1, n_show);
i_diff = randi(size(diff,4), 1, n_show);
figure;
tiledlayout(2, n_show, 'TileSpacing', 'compact', 'Padding', 'compact');
for j = 1:n_show
    nexttile; imshow([same(:,:,1,i_same(j)) same(:,:,2,i_same(j))], []);
    title(sprintf('same #%d', i_same(j)));
end
for j = 1:n_show
    nexttile; imshow([diff(:,:,1,i_diff(j)) diff(:,:,2,i_diff(j))], []);
    title(sprintf('diff #%d', i_diff(j)));
end

%% ------- local functions -------
function [same, diff] = make_pairs(tex, n_same, n_diff, psz)
    n = numel(tex);
    same = zeros(psz, psz, 2, n_same, 'uint8');
    for i = 1:n_same
        k = randi(n);                          % one random texture, two patches
        same(:,:,1,i) = rand_patch(tex{k}, psz);
        same(:,:,2,i) = rand_patch(tex{k}, psz);
    end
    diff = zeros(psz, psz, 2, n_diff, 'uint8');
    for i = 1:n_diff
        kk = randperm(n, 2);                   % two different textures, one patch each
        diff(:,:,1,i) = rand_patch(tex{kk(1)}, psz);
        diff(:,:,2,i) = rand_patch(tex{kk(2)}, psz);
    end
end

function p = rand_patch(t, psz)
    sz = size(t);
    x = randi(sz(1) - psz + 1);
    y = randi(sz(2) - psz + 1);
    p = t(x:x+psz-1, y:y+psz-1);
end
