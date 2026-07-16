function s3_make_nearfar_pairs(cfg, ecc)
% S3_MAKE_NEARFAR_PAIRS  Build near/far patch-pair training data from natural images.
%   s3_make_nearfar_pairs(cfg, ecc)
%
%   Pipeline stage 3 (was nat_near_far_patches.m). The proximity proxy: for each
%   natural image (optically filtered, LMS, downsampled to eccentricity
%   ecc) sample reference patches and form, per reference, two NEAR pairs (the
%   reference with its right and lower neighbours) and two FAR pairs (the
%   reference with patches sampled beyond a distance criterion). Saves the
%   combined pairs to data/stimuli/patch_pairs_ecc<ecc>.mat.
%
%   Run `setup` first. ecc is the downsample factor (1, 2, 4, 8).
%
%   Changes vs original:
%     * one combined output file (ptchn/ptchf/pcnt) instead of three per-set
%       files -- this also removes the Set-12 slice index bug in the original.
%     * per-image image size (szx/szy/dcrit) instead of reusing Set-9's values.
%     * uses cfg.optics.ppd (60) for the OTF, matching stages 1-2 and the texture
%       test path -- 60 is the human psychophysics display resolution, unified across
%       all images (was briefly 64 for natural images; reverted to 60).

    psz  = cfg.patch.size / ecc;         % patch size at this eccentricity
    psz2 = 2 * psz;
    maxval = cfg.natural.max_val;
    m0 = cfg.norm.target_mean;           % per-patch normalize (before rotate) via patch_to_a
    c0 = cfg.norm.target_contrast;

    files = list_natural_images(cfg);
    nsmp = ceil(cfg.natural.target_nearfar_references / numel(files));
    max_pairs = numel(files) * nsmp * 2;
    % Patches are stored as the ACHROMATIC (A) channel only (1-channel). Each half is
    % normalized (ptch_norm type 3) then rotated LMS->ABR and A is kept, via the shared
    % vislab.nat_stat_bayes.patch_to_a -- the same order the downstream DV code used, so
    % results are unchanged; downstream just reads A directly. See twin-net/net_plan.md.
    ptchn = zeros(psz, psz2, 1, max_pairs);
    ptchf = zeros(psz, psz2, 1, max_pairs);
    pcnt = 0;

    for f = 1:numel(files)
        [~, fname, fext] = fileparts(files{f});
        fprintf('sampling %s\n', [fname, fext]);
        img = vislab.nat_stat_bayes.source_to_lms(files{f}, cfg, struct('prescale', 255/maxval, 'ecc', ecc));
        [szx, szy, ~] = size(img);
        dcrit = szx / 4;                 % far-pair distance criterion

        for k = 1:nsmp
            x = randi(szx - psz2);
            y = randi(szy - psz2);
            a_ref = vislab.nat_stat_bayes.patch_to_a(img(x:x+psz-1, y:y+psz-1, :), m0, c0);

            % near/far RIGHT pairs (reference alongside a right-hand patch)
            pcnt = pcnt + 1;
            a_right = vislab.nat_stat_bayes.patch_to_a(img(x:x+psz-1, y+psz:y+psz2-1, :), m0, c0);
            ptchn(:, :, 1, pcnt) = cat(2, a_ref, a_right);
            [xf, yf] = sample_far(szx, szy, psz2, x, y, dcrit);
            a_far = vislab.nat_stat_bayes.patch_to_a(img(xf:xf+psz-1, yf+psz:yf+psz2-1, :), m0, c0);
            ptchf(:, :, 1, pcnt) = cat(2, a_ref, a_far);

            % near/far DOWN pairs (transposed so a vertical pair reads horizontally).
            % Transpose commutes with normalize+rotate, so transpose the A directly.
            a_ref_t = a_ref.';
            pcnt = pcnt + 1;
            a_below = vislab.nat_stat_bayes.patch_to_a(img(x+psz:x+psz2-1, y:y+psz-1, :), m0, c0).';
            ptchn(:, :, 1, pcnt) = cat(2, a_ref_t, a_below);
            [xf, yf] = sample_far(szx, szy, psz2, x, y, dcrit);
            a_far_below = vislab.nat_stat_bayes.patch_to_a(img(xf:xf+psz-1, yf+psz:yf+psz2-1, :), m0, c0).';
            ptchf(:, :, 1, pcnt) = cat(2, a_ref_t, a_far_below);
        end
    end

    ptchn = ptchn(:, :, :, 1:pcnt);
    ptchf = ptchf(:, :, :, 1:pcnt);

    if ~isfolder(cfg.paths.stimuli), mkdir(cfg.paths.stimuli); end
    out_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));
    reply = input(sprintf('s3: Save near/far patch pairs to disk and overwrite patch_pairs_ecc%d.mat? (y/n): ', ecc), 's');
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
