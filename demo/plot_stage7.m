function plot_stage7(cfg, out, method, itype, ecc)
% PLOT_STAGE7  Generate sample GTR images and show the ground-truth regions
%   next to the model's segmentation output.
    fprintf('Generating a sample GTR image and segmenting it for visual output...\n');

    [~, idx] = max(out.nregs5_ave, [], 'all', 'linear');
    [ki, li] = ind2sub(size(out.nregs5_ave), idx);
    mc_opt = out.mc(ki);
    dgc_opt = out.dgc(li);

    szp = cfg.gtr.szp;
    psz = cfg.patch.size / ecc;
    ntexr = cfg.gtr.n_regions;

    feature_list = zeros(1,20); feature_list([1 5 6 7 9 10 11 13 14]) = 1;
    cstat = zeros(1,20); cstat([1 5 6 7 9 10 11 13 14]) = 5;
    [n_bins, bin_bounds] = vislab.nat_stat_bayes.load_bin_bounds(cstat, 1, double(cfg.optics.apply));
    dv = load_dv_handles(cfg, ecc, true);
    [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc);

    figure('Name', 'Stage 7: Segmentation Result', 'Position', [400 200 1200 800]);

    ss_method = struct('nc', 'c_shft', 'ncb', 'bc_noshift').(method);

    n_examples = 3;
    for ex = 1:n_examples
        texs = gtr.sample_texture_ids(nimg, ntexr, 1);
        [~, map3] = gtr.grow_region_masks(szp, ntexr, 1, cfg.gtr.seed_radius, cfg.gtr.coverage);
        map = map3(:, :, 1);
        [pimg, px, py] = make_gtr_image(cfg, imgr, imgg, imgb, texs(1,:), map);

        phiall = segmentation.content_similarity_matrix(pimg, szp, psz, px, py, bin_bounds, n_bins, feature_list, dv.h, dv.e, dv.c, cfg);
        rho = segmentation.mutual_similarity(phiall);

        R = neighbor_far_responses(cfg, pimg, rho, map, bin_bounds, n_bins, dv, feature_list);
        [qbs, qbd] = self_sup_decision(ss_method, R, dv);
        gc_vec = 0:0.8:8; wm_vec = 0:0.8:9.6;
        [~, ~, ~, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec);
        [row_best, col_at] = max(pcnf, [], 2);
        [~, J] = max(row_best);
        gcopt = gc_vec(J); wmopt = wm_vec(col_at(J));

        [phi, dst] = segmentation.neighbor_similarity_matrix(pimg, szp, psz, px, py, psz, bin_bounds, n_bins, feature_list, dv, cfg);
        mu = (phi + wmopt * rho) .* (phi ~= 0);

        cc_opt = 1.1;
        [~, ~, groups2d] = segmentation.group_patches(mu, dst, szp, gcopt + dgc_opt, cc_opt, psz, px, py, phiall, mc_opt);

        % Use mean across channels to ensure a pure grayscale base image
        pimg_gray = mean(double(pimg), 3);
        pimg_norm = pimg_gray - min(pimg_gray(:));
        pimg_norm = pimg_norm / max(pimg_norm(:));
        pimg_rgb = repmat(pimg_norm, [1 1 3]);

        % Upsample maps to image resolution
        map_up = imresize(map, [size(pimg,1), size(pimg,2)], 'nearest');
        groups_up = imresize(groups2d, [size(pimg,1), size(pimg,2)], 'nearest');

        subplot(n_examples, 3, (ex-1)*3 + 1);
        image(pimg_rgb); axis image off;
        if ex == 1, title('Raw GTR Image'); end

        subplot(n_examples, 3, (ex-1)*3 + 2);
        image(pimg_rgb); axis image off; hold on;
        h = imagesc(map_up); colormap(gca, 'jet');
        set(h, 'AlphaData', 0.4);
        if ex == 1, title('Ground Truth Regions'); end

        subplot(n_examples, 3, (ex-1)*3 + 3);
        image(pimg_rgb); axis image off; hold on;
        h2 = imagesc(groups_up); colormap(gca, 'jet');
        set(h2, 'AlphaData', 0.4);
        if ex == 1, title('Segmented Output'); end

        drawnow; % update UI
    end
end
