function plot_stage5_intermediate(cfg, ecc, R_near, R_far)
% PLOT_STAGE5_INTERMEDIATE  Show construction of the spot, edge and border
%   decision variables. One figure, one row per DV (spot, edge, border):
%     col 1  response cloud with the trained quadratic boundary (grid, no ticks)
%     col 2  each feature's proportional contribution to classification d'
%            (classify_normals d_con; see plot_dcon_bar)
%     col 3  resulting 1D DV distributions for near vs. far pairs
%   The response-cloud axis labels are coloured to match the contribution-bar
%   sections, tying each feature to its share of d'.
    if isempty(R_near), return; end
    tag = num2str(ecc);

    try
        S = load(fullfile(cfg.paths.models, ['decision_bounds_ecc' tag '.mat']), 'dbnd');
        dbndh = S.dbnd.h;
        dbnde = S.dbnd.e;
        dbndb = S.dbnd.b;
    catch
        return;
    end
    dvh = quad2fun(dbndh, 0);
    dve = quad2fun(dbnde, 0);
    dvb = quad2fun(dbndb, 0);

    figure('Name', 'Stage 5A: Spot, Edge & Border DV Construction', 'Position', [120 60 1300 950]);

    % ==========================================
    % ROW 1: SPOT DV  (features [1 13 14])
    % ==========================================
    near_h = R_near(:, 1:3);  far_h = R_far(:, 1:3);
    subplot(3, 3, 1);
    local_scatter3_bd(dvh, near_h, far_h, {'Achromatic', 'CS-Small', 'CS-Large'});
    title('Constructing Spot DV');

    subplot(3, 3, 2);
    plot_dcon_bar(near_h, far_h, {'A', 'CS-small', 'CS-large'});

    subplot(3, 3, 3);
    local_dv_hist(dvh, near_h, far_h, 'Spot DV');
    legend('Far Pairs', 'Near Pairs', 'Location', 'best');

    % ==========================================
    % ROW 2: EDGE DV  (features [5 9 10])
    % ==========================================
    near_e = R_near(:, 4:6);  far_e = R_far(:, 4:6);
    subplot(3, 3, 4);
    local_scatter3_bd(dve, near_e, far_e, {'Edge Mag', 'Bar Mag', 'Bar Ori'});
    title('Constructing Edge DV');

    subplot(3, 3, 5);
    plot_dcon_bar(near_e, far_e, {'edge mag', 'bar mag', 'bar ori'});

    subplot(3, 3, 6);
    local_dv_hist(dve, near_e, far_e, 'Edge DV');

    % ==========================================
    % ROW 3: BORDER DV  (features [rb1 rb2])
    % ==========================================
    near_b = R_near(:, 8:9);  far_b = R_far(:, 8:9);
    subplot(3, 3, 7);
    local_scatter2_bd(dvb, near_b, far_b, {'Border Edge Mag', 'Border Bar Mag'});
    title('Constructing Border DV');

    subplot(3, 3, 8);
    plot_dcon_bar(near_b, far_b, {'border edge', 'border bar'});

    subplot(3, 3, 9);
    local_dv_hist(dvb, near_b, far_b, 'Border DV');
end

% ------------------------------------------------------------------------------
function local_scatter3_bd(dv, near_pts, far_pts, labels)
% 3D response cloud (near = blue, far = red) with the quadratic decision
% boundary as a grey, grey-meshed dv = 0 isosurface. Ticks off, grid on, and
% axis labels coloured to match the d'-contribution bar sections (lines(dim)).
    dcol = lines(numel(labels));
    hold on;
    scatter3(far_pts(:,1),  far_pts(:,2),  far_pts(:,3),  15, 'r', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    scatter3(near_pts(:,1), near_pts(:,2), near_pts(:,3), 15, 'b', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);

    x_min = min([near_pts(:,1); far_pts(:,1)]) - 1; x_max = max([near_pts(:,1); far_pts(:,1)]) + 1;
    y_min = min([near_pts(:,2); far_pts(:,2)]) - 1; y_max = max([near_pts(:,2); far_pts(:,2)]) + 1;
    z_min = min([near_pts(:,3); far_pts(:,3)]) - 1; z_max = max([near_pts(:,3); far_pts(:,3)]) + 1;

    [Xg, Yg, Zg] = meshgrid(linspace(x_min, x_max, 40), linspace(y_min, y_max, 40), linspace(z_min, z_max, 40));
    V = reshape(apply_dv(dv, [Xg(:), Yg(:), Zg(:)]), size(Xg));
    fv = isosurface(Xg, Yg, Zg, V, 0);
    if ~isempty(fv.vertices)
        local_draw_surface(fv);
    end
    view(3); grid on;
    set(gca, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);   % no ticks, keep grid
    xlabel(labels{1}, 'Color', dcol(1,:));
    ylabel(labels{2}, 'Color', dcol(2,:));
    zlabel(labels{3}, 'Color', dcol(3,:));
end

% ------------------------------------------------------------------------------
function local_scatter2_bd(dv, near_pts, far_pts, labels)
% 2D response cloud with the quadratic decision boundary as the dv = 0 contour.
% Ticks off, grid on, axis labels coloured to match the contribution bar.
    dcol = lines(numel(labels));
    hold on;
    scatter(far_pts(:,1),  far_pts(:,2),  15, 'r', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    scatter(near_pts(:,1), near_pts(:,2), 15, 'b', 'filled', 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);

    x_min = min([near_pts(:,1); far_pts(:,1)]) - 1; x_max = max([near_pts(:,1); far_pts(:,1)]) + 1;
    y_min = min([near_pts(:,2); far_pts(:,2)]) - 1; y_max = max([near_pts(:,2); far_pts(:,2)]) + 1;
    [Xg, Yg] = meshgrid(linspace(x_min, x_max, 200), linspace(y_min, y_max, 200));
    Zg = reshape(apply_dv(dv, [Xg(:), Yg(:)]), size(Xg));
    contour(Xg, Yg, Zg, [0 0], 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    grid on;
    set(gca, 'XTickLabel', [], 'YTickLabel', []);                     % no ticks, keep grid
    xlabel(labels{1}, 'Color', dcol(1,:));
    ylabel(labels{2}, 'Color', dcol(2,:));
end

% ------------------------------------------------------------------------------
function local_draw_surface(fv)
% Draw a decision-boundary isosurface as a grey face with a grey mesh.
    fv = reducepatch(fv, 0.15);        % coarser mesh so the grey wireframe reads
    p = patch(fv);
    p.FaceColor = [0.7 0.7 0.7]; p.FaceAlpha = 0.35;
    p.EdgeColor = [0.5 0.5 0.5]; p.EdgeAlpha = 0.6;
    camlight; lighting gouraud;
end

% ------------------------------------------------------------------------------
function local_dv_hist(dv, near_pts, far_pts, xlab)
% Overlaid near/far histograms of the scalar decision variable, current axes.
    hold on;
    histogram(apply_dv(dv, far_pts),  'FaceColor', 'r', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    histogram(apply_dv(dv, near_pts), 'FaceColor', 'b', 'Normalization', 'pdf', 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    set(gca, 'YTick', []);
    xlabel(xlab);
end
