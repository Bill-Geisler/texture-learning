function coeff = s1_learn_color_transform(cfg, autosave)
% S1_LEARN_COLOR_TRANSFORM  Learn the LMS->ABR PCA colour rotation from natural images.
%   coeff = s1_learn_color_transform(cfg)
%   coeff = s1_learn_color_transform(cfg, autosave)
%
%   autosave (optional) - true/false to save/skip without asking (used by
%   run_demo, which confirms once up front); omit to be asked interactively.
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

    maxval = cfg.natural.max_val;

    files = list_natural_images(cfg);
    nsmp = ceil(cfg.natural.target_isolated_patches / numel(files));

    % One independent image per iteration -> parfor (runs serially without the
    % Parallel Computing Toolbox). Each iteration returns its pixels into a cell.
    pix_c = cell(1, numel(files));
    parfor f = 1:numel(files)
        [~, fname, fext] = fileparts(files{f});
        fprintf('sampling %s\n', [fname, fext]);
        img_lms = vislab.nat_stat_bayes.source_to_lms(files{f}, cfg, struct('prescale', 255/maxval));
        pix_c{f} = sample_color_pixels(img_lms, nsmp, cfg);
    end
    lms_pixels = cat(1, pix_c{:});
    n = size(lms_pixels, 1);

    coeff = pca(lms_pixels);                          % columns = principal (ABR) axes

    if cfg.optics.apply, xform_file = 'cps_lms2abr_otf.mat'; else, xform_file = 'cps_lms2abr.mat'; end
    out_path = fullfile(cfg.paths.data_root, xform_file);   % lab-global transform lives in the shared store
    if nargin < 2 || isempty(autosave)
        reply = input(sprintf('s1: Save LMS->ABR rotation to disk and overwrite %s? (y/n): ', xform_file), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(out_path, 'coeff');
        fprintf('s1: saved LMS->ABR rotation to %s (%d pixels from %d images)\n', out_path, n, numel(files));
    else
        fprintf('s1: skipped saving LMS->ABR rotation.\n');
    end
end
