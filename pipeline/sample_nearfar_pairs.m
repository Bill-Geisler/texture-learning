function [ptchn, ptchf] = sample_nearfar_pairs(img, nsmp, psz, cfg)
% SAMPLE_NEARFAR_PAIRS  Sample nsmp reference patches from one LMS image and build
%   near/far A-channel pairs (Stage 23): per reference, two NEAR pairs (right and
%   lower neighbours) and two FAR pairs (patches beyond a distance criterion). This
%   is the single definition of that per-image sampling, shared by
%   s23_learn_priors_and_pairs and demo/sample_demo_pairs.
%
%   Inputs
%     img  - [H x W x 3] LMS image already at the target eccentricity.
%     nsmp - number of reference patches to sample (each yields 2 near + 2 far).
%     psz  - patch size at that eccentricity (cfg.patch.size / ecc).
%     cfg  - config struct (normalization).
%
%   Outputs
%     ptchn, ptchf - A-channel pair tensors [psz x 2*psz x 1 x (2*nsmp)].
%
%   Each half is normalized then rotated LMS->ABR and A is kept, via the shared
%   vislab.nat_stat_bayes.patch_to_a.
    psz2 = 2 * psz;
    m0 = cfg.norm.target_mean;
    c0 = cfg.norm.target_contrast;
    [szx, szy, ~] = size(img);
    dcrit = szx / 4;                 % far-pair distance criterion

    ptchn = zeros(psz, psz2, 1, 2*nsmp);
    ptchf = zeros(psz, psz2, 1, 2*nsmp);
    pcnt = 0;
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

% ------------------------------------------------------------------------------
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
