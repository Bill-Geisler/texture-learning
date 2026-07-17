function pix = sample_color_pixels(img_lms, nsmp, cfg)
% SAMPLE_COLOR_PIXELS  Sample nsmp isolated patches from one LMS image and return
%   their normalized LMS pixel values [nsmp*psz^2 x 3], for the Stage 1 colour PCA.
%   The single definition of that per-image sampling (used by s1_learn_color_transform).
    psz       = cfg.patch.size;
    m0        = cfg.norm.target_mean;
    c0        = cfg.norm.target_contrast;
    n_colr    = 3;
    norm_type = 3;                                   % average-mean normalization

    [n_rows, n_cols, ~] = size(img_lms);
    pix = zeros(nsmp * psz^2, 3);
    n = 0;
    for k = 1:nsmp
        x = randi(n_rows - psz);
        y = randi(n_cols - psz);
        patch = vislab.lib.ptch_norm(img_lms(x:x+psz-1, y:y+psz-1, :), m0, c0, norm_type, n_colr);
        pix(n+1 : n+psz^2, :) = reshape(patch, [], 3);
        n = n + psz^2;
    end
end
