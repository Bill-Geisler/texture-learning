function plot_stage3(cfg, ecc)
% PLOT_STAGE3  Show example near ("same") and far ("different") patch pairs.
%   Full mode shows the built pairs (patch_pairs_ecc<ecc>.mat); quick mode has none,
%   so it samples a few via sample_demo_pairs (same optics/domain/distance rules as
%   Stage 3). Both branches yield A-channel pair tensors, displayed identically.
    out_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));
    n_show = 5;

    if isfile(out_path)
        pp = load(out_path, 'ptchn', 'ptchf');
        ptchn = pp.ptchn;  ptchf = pp.ptchf;
    else
        [ptchn, ptchf] = sample_demo_pairs(cfg, ecc);
        if isempty(ptchn)
            fprintf('No natural images found; skipping Stage 3.\n');
            return;
        end
    end

    n_show = min(n_show, size(ptchn, 4));
    psz = size(ptchn, 1);

    figure('Name', 'Stage 3: Near/Far Pairs', 'Position', [200 200 400 800]);
    for i = 1:n_show
        subplot(n_show, 2, (i-1)*2 + 1);
        local_show_pair(ptchn(:, 1:psz, 1, i), ptchn(:, psz+1:2*psz, 1, i));
        if i == 1, title('Near Pairs'); end

        subplot(n_show, 2, (i-1)*2 + 2);
        local_show_pair(ptchf(:, 1:psz, 1, i), ptchf(:, psz+1:2*psz, 1, i));
        if i == 1, title('Far Pairs'); end
    end
end

% ------------------------------------------------------------------------------
function local_show_pair(a, b)
% Display a patch pair side by side (2-px gap), min-max normalized + gamma.
    pair = double([a, zeros(size(a, 1), 2), b]);
    pair = pair - min(pair(:));
    pair = pair / max(eps, max(pair(:)));
    imagesc(pair.^(1/2.2)); colormap gray; axis image off;
end
