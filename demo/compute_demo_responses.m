function [near, far] = compute_demo_responses(cfg, ecc)
% COMPUTE_DEMO_RESPONSES  Compute the per-pair power/spot/edge/border responses
%   for a small subset of near and far patch pairs, for the Stage 5 demo plots.
%   Falls back to synthesizing patches from a natural image if the built stimuli
%   are not present.
    % Extract variables needed for pair_responses
    btype  = 5;
    b0     = 16;
    thresh = cfg.dv.edge_thresh;
    psz    = cfg.patch.size / ecc;
    nh     = cfg.features.spot_dims;
    ne     = cfg.features.edge_dv_dims;

    feature_list = zeros(1, 20);  feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat        = zeros(1, 20);  cstat([1 5 6 7 9 10 11 13 14]) = btype;
    eccb = 1;

    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, eccb, double(cfg.optics.apply));

    pp_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));
    if ~isfile(pp_path)
        % Fallback: Synthesize patches if stimuli data isn't built yet
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if ~isfile(img_path)
            fprintf('True CPS natural image not found. Skipping Stage 5 true evaluation.\n');
            near = []; far = []; return;
        end
        img = double(imread(img_path));
        if size(img, 3) == 1
            img = repmat(img, [1 1 3]);
        end

        n_sample = 150;
        ptchn_sub = zeros(psz, 2*psz, 3, n_sample);
        ptchf_sub = zeros(psz, 2*psz, 3, n_sample);

        rng(42);
        for i = 1:n_sample
            r1 = randi(size(img,1) - psz); c1 = randi(size(img,2) - 2*psz);
            ptchn_sub(:,:,:,i) = img(r1:r1+psz-1, c1:c1+2*psz-1, :);

            r2 = randi(size(img,1) - psz); c2a = randi(size(img,2) - psz); c2b = randi(size(img,2) - psz);
            ptchf_sub(:,:,:,i) = cat(2, img(r2:r2+psz-1, c2a:c2a+psz-1, :), img(r2:r2+psz-1, c2b:c2b+psz-1, :));
        end
    else
        pp = load(pp_path, 'ptchn', 'ptchf');
        n_sample = min(150, size(pp.ptchn, 4));
        ptchn_sub = pp.ptchn(:,:,:,1:n_sample);
        ptchf_sub = pp.ptchf(:,:,:,1:n_sample);
    end

    near = pair_responses(ptchn_sub, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);
    far  = pair_responses(ptchf_sub, bin_bounds, n_bins, feature_list, nh, ne, b0, thresh, psz, cfg);
end
