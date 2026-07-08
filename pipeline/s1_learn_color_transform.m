function coeff = s1_learn_color_transform(cfg)
% S1_LEARN_COLOR_TRANSFORM  Learn the LMS->ABR PCA colour rotation from natural images.
%   coeff = s1_learn_color_transform(cfg)
%
%   Pipeline stage 1 (was mk_rot_mtrx.m). For every calibrated natural image:
%   scale to 0..255, apply eye optics, convert to LMS cone space, sample random
%   1-deg patches, mean-normalize, and accumulate the LMS pixel values. Then run
%   PCA to obtain the rotation into the opponent "ABR" axes (achromatic,
%   blue-yellow, red-green) and save the 3x3 matrix. This LMS->ABR transform is
%   lab-global, so it is written to the shared vislab-common/data store (as
%   cps_lms2abr_otf.mat) where the other lab projects also read it from.
%
%   Run `setup` first. Requires natural images in cfg.paths.natural_images and
%   the Statistics Toolbox (pca).
%
%   NOTE: uses the corrected vislab.lib.otf_filter, so the recomputed matrix differs
%   slightly from the preprint version (see the reorganization plan / CHANGELOG);
%   re-running this stage overwrites the shared cps_lms2abr_otf.mat that all lab
%   projects consume. Diagnostic histograms from the original are omitted.
%
%   Output / side effect
%     coeff - 3x3 LMS->ABR rotation matrix; also saved to vislab-common/data as
%             cps_lms2abr[_otf].mat (var `coeff`), shared across the lab.

    psz    = cfg.patch.size;
    maxval = cfg.natural.max_val;
    m0     = cfg.norm.target_mean;
    c0     = cfg.norm.target_contrast;
    n_colr = 3;
    norm_type = 3;                                   % average-mean normalization

    files = list_natural_images(cfg);
    nsmp = ceil(cfg.natural.target_isolated_patches / numel(files));

    lms_pixels = zeros(numel(files) * nsmp * psz^2, 3);
    n = 0;

    for f = 1:numel(files)
        img = double(imread(files{f})) * 255 / maxval;      % scale 14-bit -> 0..255
        if cfg.optics.apply
            img = vislab.lib.otf_filter(img, cfg.optics.ppd_natural, cfg.optics.pupil_diameter, cfg.optics.wavelength);
        end
        img_lms = vislab.lib.rgb2lms(img);            % shared lab RGB->LMS calibration
        [n_rows, n_cols, ~] = size(img_lms);
        for s = 1:nsmp
            x = randi(n_rows - psz);
            y = randi(n_cols - psz);
            patch = img_lms(x:x+psz-1, y:y+psz-1, :);
            patch = vislab.lib.ptch_norm(patch, m0, c0, norm_type, n_colr);
            lms_pixels(n+1 : n+psz^2, :) = reshape(patch, [], 3);
            n = n + psz^2;
        end
    end
    lms_pixels = lms_pixels(1:n, :);

    coeff = pca(lms_pixels);                          % columns = principal (ABR) axes

    if cfg.optics.apply, fname = 'cps_lms2abr_otf.mat'; else, fname = 'cps_lms2abr.mat'; end
    out_path = fullfile(cfg.paths.data_root, fname);   % lab-global transform lives in the shared store
    save(out_path, 'coeff');
    fprintf('s1: saved LMS->ABR rotation to %s (%d pixels from %d images)\n', out_path, n, numel(files));
end
