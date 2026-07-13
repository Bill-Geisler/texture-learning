% nat_near_far_patches_cnn.m
% sample texture image patch pairs from 16-bit linear rgb natural images and save
% near/far A-channel (achromatic) pairs to a single .mat file (loaded whole at train time)
%
% NOT used by cnn/train_cnn.m, which now samples near/far pairs on the fly (see
% getTwinBatch_nat_live.m + load_nat_A_pool.m) so pairs never repeat. This script is
% kept as a standalone tool for offline inspection/regeneration of a fixed pair set.
%
cfg = config;
psz = cfg.patch.size;
n_samp = 100;
same_max_dist = 1;
down_level = 1; % resolution scale-down (power of 2: 1,2,4,8) -- eccentricity model
prescale = 255 / cfg.natural.max_val;   % 16-bit linear -> 0..255 (matches training)

% Ingestion goes through the shared vislab.nat_stat_bayes.source_to_lms (same
% function + params as the on-the-fly training sampler and the Bayesian pipeline),
% keeping the A (achromatic) channel. Image list from list_natural_images(cfg).

files = list_natural_images(cfg);
n_img = numel(files);

% per-image results collected in cells (parfor-sliced), concatenated after.
% each patch pair is [psz psz 2]: dim 3 holds the two patches (1 = reference,
% 2 = partner), kept separate rather than stitched. stored 8-bit (A/achromatic
% channel of the ABR transform).
nearC = cell(1,n_img);
farC  = cell(1,n_img);

parfor k = 1:n_img
    rng(k); % per-image seed: reproducible regardless of parfor execution order
    fprintf('%s\n', files{k});

    % process this image into its achromatic (A) channel (uint8, 0-255) via the
    % shared helper -- the same routine the on-the-fly training sampler uses, so
    % the two paths stay identical (see cnn_plan.md)
    [~, A] = vislab.nat_stat_bayes.source_to_lms(files{k}, cfg, struct('prescale', prescale, 'ecc', down_level));
    A = uint8(A * 255 / max(A(:)));

    near_k = zeros(psz,psz,2,n_samp,'uint8');
    far_k  = zeros(psz,psz,2,n_samp,'uint8');
    for i = 1:n_samp
        % find near and far patch coords (always returns a valid set)
        coords = find_nat_patch(A,psz,same_max_dist);

        % near pair -> separated along dim 3
        x_a = coords(1,1); y_a = coords(1,2);
        x_b = coords(2,1); y_b = coords(2,2);
        near_k(:,:,1,i)=uint8(A(x_a:x_a+psz-1,y_a:y_a+psz-1));
        near_k(:,:,2,i)=uint8(A(x_b:x_b+psz-1,y_b:y_b+psz-1));

        % far pair -> separated along dim 3
        x_a = coords(3,1); y_a = coords(3,2);
        x_b = coords(4,1); y_b = coords(4,2);
        far_k(:,:,1,i)=uint8(A(x_a:x_a+psz-1,y_a:y_a+psz-1));
        far_k(:,:,2,i)=uint8(A(x_b:x_b+psz-1,y_b:y_b+psz-1));
    end
    nearC{k} = near_k;
    farC{k}  = far_k;
end

near = cat(4,nearC{:});
far  = cat(4,farC{:});

% save all pairs to a single file. -v7.3 (HDF5) supports large arrays and
% allows lazy slicing via matfile() later if the set outgrows RAM
outdir = fullfile(cfg.paths.stimuli, 'nat');
if ~exist(outdir,'dir'); mkdir(outdir); end
if down_level>1
    outfile = fullfile(outdir, ['patch_pairs_dsmpl_' num2str(down_level) '.mat']);
else
    outfile = fullfile(outdir, 'patch_pairs.mat');
end
save(outfile,'near','far','-v7.3')

%% show a few example near/far pairs (reference | partner)
n_show = 5;
i_near = randi(size(near,4),1,n_show);
i_far  = randi(size(far,4),1,n_show);
figure;
tiledlayout(2,n_show,'TileSpacing','compact','Padding','compact');
for j = 1:n_show
    nexttile; imshow([near(:,:,1,i_near(j)) near(:,:,2,i_near(j))],[]);
    title(sprintf('near #%d',i_near(j)));
end
for j = 1:n_show
    nexttile; imshow([far(:,:,1,i_far(j)) far(:,:,2,i_far(j))],[]);
    title(sprintf('far #%d',i_far(j)));
end
