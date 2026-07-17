function [ptchn, ptchf] = sample_demo_pairs(cfg, ecc)
% SAMPLE_DEMO_PAIRS  Near/far A-channel patch pairs from a SINGLE natural image, for
%   the Stage 5 plots in QUICK mode (which has no trained points to reuse). Loads one
%   image the same way the pipeline does (source_to_lms optics + RGB->LMS) and draws
%   the full constant-volume reference budget (cfg.natural.target_nearfar_references)
%   from it via the shared sample_nearfar_pairs -- so the points are real
%   training-style points, just from one image. (Full mode instead reuses the exact
%   pairs s5 trained on.)
%
%   Returns A-channel pair tensors [psz x 2*psz x 1 x N] (ptchn near, ptchf far),
%   or [] if no natural images are available.
    try
        files = list_natural_images(cfg);
    catch
        fprintf('No natural images found; skipping Stage 5 response plots.\n');
        ptchn = []; ptchf = []; return;
    end
    psz = cfg.patch.size / ecc;
    img = vislab.nat_stat_bayes.source_to_lms(files{1}, cfg, ...
          struct('prescale', 255/cfg.natural.max_val, 'ecc', ecc));
    [ptchn, ptchf] = sample_nearfar_pairs(img, cfg.natural.target_nearfar_references, psz, cfg);
end
