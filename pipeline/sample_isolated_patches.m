function patches = sample_isolated_patches(img_lms, nsmp, psz, cfg)
% SAMPLE_ISOLATED_PATCHES  Cut nsmp random mean-normalized isolated patches from one image.
%   patches = sample_isolated_patches(img_lms, nsmp, psz, cfg)
%
%   The single definition of isolated-patch sampling, shared by the natural-prior
%   stage (s23_learn_priors_and_pairs, via sample_prior_features) and the multi-scale
%   gradient figure (demo/plot_stage1b_gradients) so both draw the SAME kind of
%   patch with the SAME preprocessing. Patches are mean-normalized (ptch_norm
%   type 3: scale the whole patch to the average channel mean); they are NOT
%   contrast-normalized or colour-rotated -- callers rotate to ABR / take the A
%   channel / contrast-normalize as each needs.
%
%   Inputs
%     img_lms - [H x W x 3] LMS image (at the target eccentricity).
%     nsmp    - number of isolated patches to sample from this image.
%     psz     - patch size in pixels (cfg.patch.size / ecc).
%     cfg     - config struct (normalization targets).
%
%   Output
%     patches - [psz x psz x 3 x nsmp] mean-normalized LMS patches.
    m0  = cfg.norm.target_mean;
    c0  = cfg.norm.target_contrast;                 % unused by norm_type 3; passed for signature
    [n_rows, n_cols, ~] = size(img_lms);
    patches = zeros(psz, psz, 3, nsmp);
    for k = 1:nsmp
        x = randi(n_rows - psz);
        y = randi(n_cols - psz);
        patches(:, :, :, k) = vislab.lib.ptch_norm(img_lms(x:x+psz-1, y:y+psz-1, :), m0, c0, 3, 3);
    end
end
