function plot_stage3(cfg, ecc)
% PLOT_STAGE3  Show example near ("same") and far ("different") patch pairs.
    out_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));

    n_show = 5;
    near_pairs = cell(n_show, 2);
    far_pairs = cell(n_show, 2);

    if ~isfile(out_path)
        % patch_pairs_1.mat is missing. Synthesize from natural image.
        img_path = fullfile(cfg.paths.data_root, 'CPS natural images', 'Set10_16_1.png');
        if ~isfile(img_path)
            fprintf('True CPS natural image not found. Skipping Stage 3.\n');
            return;
        end
        img = double(rgb2gray(imread(img_path)));

        psz = cfg.patch.size / ecc;
        for i = 1:n_show
            r1 = randi(size(img,1) - psz); c1 = randi(size(img,2) - 2*psz);
            near_pairs{i, 1} = img(r1:r1+psz-1, c1:c1+psz-1);
            near_pairs{i, 2} = img(r1:r1+psz-1, c1+psz:c1+2*psz-1);

            r2 = randi(size(img,1) - psz); c2a = randi(size(img,2) - psz); c2b = randi(size(img,2) - psz);
            far_pairs{i, 1} = img(r2:r2+psz-1, c2a:c2a+psz-1);
            far_pairs{i, 2} = img(r2:r2+psz-1, c2b:c2b+psz-1);
        end
    else
        pp = load(out_path, 'ptchn', 'ptchf');
        n_show = min(5, size(pp.ptchn, 4));
        psz = size(pp.ptchn, 1);
        for i = 1:n_show
            near_pairs{i, 1} = pp.ptchn(:, 1:psz, 1, i);
            near_pairs{i, 2} = pp.ptchn(:, psz+1:2*psz, 1, i);
            far_pairs{i, 1}  = pp.ptchf(:, 1:psz, 1, i);
            far_pairs{i, 2}  = pp.ptchf(:, psz+1:2*psz, 1, i);
        end
    end

    figure('Name', 'Stage 3: Near/Far Pairs', 'Position', [200 200 400 800]);

    for i = 1:n_show
        % Near pair (column 1)
        subplot(n_show, 2, (i-1)*2 + 1);
        pair_n = double([near_pairs{i, 1}, zeros(size(near_pairs{i,1},1), 2), near_pairs{i, 2}]);
        pair_n = pair_n - min(pair_n(:)); pair_n = pair_n / max(eps, max(pair_n(:)));
        imagesc(pair_n.^(1/2.2)); colormap gray; axis image off;
        if i == 1, title('Near Pairs'); end

        % Far pair (column 2)
        subplot(n_show, 2, (i-1)*2 + 2);
        pair_f = double([far_pairs{i, 1}, zeros(size(far_pairs{i,1},1), 2), far_pairs{i, 2}]);
        pair_f = pair_f - min(pair_f(:)); pair_f = pair_f / max(eps, max(pair_f(:)));
        imagesc(pair_f.^(1/2.2)); colormap gray; axis image off;
        if i == 1, title('Far Pairs'); end
    end
end
