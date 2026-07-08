function s3_make_nearfar_pairs(cfg, ecc)
% S3_MAKE_NEARFAR_PAIRS  Build near/far patch-pair training data from natural images.
%   s3_make_nearfar_pairs(cfg, ecc)
%
%   Pipeline stage 3 (was nat_near_far_patches.m). The proximity proxy: for each
%   natural image (optically filtered, LMS, downsampled to eccentricity
%   ecc) sample reference patches and form, per reference, two NEAR pairs (the
%   reference with its right and lower neighbours) and two FAR pairs (the
%   reference with patches sampled beyond a distance criterion). Saves the
%   combined pairs to data/derived/patch_pairs_<ecc>.mat.
%
%   Run `setup` first. ecc is the downsample factor (1, 2, 4, 8).
%
%   Changes vs original:
%     * one combined output file (ptchn/ptchf/pcnt) instead of three per-set
%       files -- this also removes the Set-12 slice index bug in the original.
%     * per-image image size (szx/szy/dcrit) instead of reusing Set-9's values.
%     * uses cfg.optics.ppd_natural (64) for the OTF, matching stages 1-2; the
%       original used 60 here (likely a stray display value) -- flagged for Geisler.

    psz  = cfg.patch.size / ecc;         % patch size at this eccentricity
    psz2 = 2 * psz;
    n_colr = 3;
    maxval = cfg.natural.max_val;        % patches are stored raw (LMS); normalized in later stages

    files = list_natural_images(cfg);
    nsmp = ceil(cfg.natural.target_nearfar_references / numel(files));
    max_pairs = numel(files) * nsmp * 2;
    ptchn = zeros(psz, psz2, n_colr, max_pairs);
    ptchf = zeros(psz, psz2, n_colr, max_pairs);
    pcnt = 0;

    for f = 1:numel(files)
        img = double(imread(files{f})) * 255 / maxval;
        if cfg.optics.apply
            img = vislab.lib.otf_filter(img, cfg.optics.ppd_natural, cfg.optics.pupil_diameter, cfg.optics.wavelength);
        end
        img = vislab.lib.rgb2lms(img);                % shared lab RGB->LMS calibration
        img = vislab.lib.downsample(img, ecc);
        [szx, szy, ~] = size(img);
        dcrit = szx / 4;                 % far-pair distance criterion

        for k = 1:nsmp
            x = randi(szx - psz2);
            y = randi(szy - psz2);
            ref = img(x:x+psz-1, y:y+psz-1, :);

            % near/far RIGHT pairs (reference alongside a right-hand patch)
            pcnt = pcnt + 1;
            ptchn(:, :, :, pcnt) = cat(2, ref, img(x:x+psz-1, y+psz:y+psz2-1, :));
            [xf, yf] = sample_far(szx, szy, psz2, x, y, dcrit);
            ptchf(:, :, :, pcnt) = cat(2, ref, img(xf:xf+psz-1, yf+psz:yf+psz2-1, :));

            % near/far DOWN pairs (transposed so a vertical pair reads horizontally)
            ref_t = transpose_channels(ref);
            pcnt = pcnt + 1;
            below = transpose_channels(img(x+psz:x+psz2-1, y:y+psz-1, :));
            ptchn(:, :, :, pcnt) = cat(2, ref_t, below);
            [xf, yf] = sample_far(szx, szy, psz2, x, y, dcrit);
            far_below = transpose_channels(img(xf:xf+psz-1, yf+psz:yf+psz2-1, :));
            ptchf(:, :, :, pcnt) = cat(2, ref_t, far_below);
        end
    end

    ptchn = ptchn(:, :, :, 1:pcnt);
    ptchf = ptchf(:, :, :, 1:pcnt);

    if ~isfolder(cfg.paths.derived), mkdir(cfg.paths.derived); end
    out_path = fullfile(cfg.paths.derived, sprintf('patch_pairs_%d.mat', ecc));
    reply = input(sprintf('s3: Save near/far patch pairs to disk and overwrite patch_pairs_%d.mat? (y/n): ', ecc), 's');
    if strcmpi(reply, 'y')
        save(out_path, 'ptchn', 'ptchf', 'pcnt');
        fprintf('s3: saved %d near/far patch pairs (ecc %d) to %s\n', pcnt, ecc, out_path);
    else
        fprintf('s3: skipped saving near/far patch pairs.\n');
    end
end

function [xf, yf] = sample_far(szx, szy, psz2, x, y, dcrit)
% Sample a location farther than dcrit from (x,y) by rejection sampling.
    while true
        xf = randi(szx - psz2);
        yf = randi(szy - psz2);
        if sqrt((xf - x)^2 + (yf - y)^2) > dcrit
            return;
        end
    end
end

function p = transpose_channels(p)
% Transpose each colour channel of a patch.
    for c = 1:size(p, 3)
        p(:, :, c) = p(:, :, c).';
    end
end
