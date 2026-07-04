function [pc, pcs, pcd, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec)
% NEARFAR_SCORE_GRID  Discrimination accuracy over a grouping-criterion x weight grid.
%   [pc, pcs, pcd, pcnf] = nearfar_score_grid(qbs, qbd, R, gc_vec, wm_vec)
%
%   For each grouping criterion gc (rows) and mutual-similarity weight wm (cols),
%   scores the combined decision variable (qbs/qbd + wm*mutual) against the
%   near/far and same/different ground truth in R. Shared by pipeline stages
%   s6 (averages the surfaces over trials) and s7 (picks the peak-accuracy cell
%   to set the per-image gcopt/wmopt).
%
%   Outputs (each ngc x nms):
%     pc   - overall same/different proportion correct.
%     pcs  - proportion of "same" pairs called same.
%     pcd  - proportion of "different" pairs called different.
%     pcnf - overall near/far proportion correct.

    ngc = numel(gc_vec);  nms = numel(wm_vec);
    [pc, pcs, pcd, pcnf] = deal(zeros(ngc, nms));
    for j = 1:ngc
        for k = 1:nms
            [pc(j,k), pcs(j,k), pcd(j,k), pcnf(j,k)] = ...
                score(qbs, qbd, R.rmn, R.rmf, R.same_near, R.same_far, gc_vec(j), wm_vec(k));
        end
    end
end

function [pc, pcs, pcd, pcnf] = score(qbs, qbd, rmn, rmf, same_near, same_far, gc, wm)
% Near-far and same-different accuracy for one (gc, wm) cell.
    ncnt = numel(qbs);
    ncs = 0; ncd = 0; sc = 0; dc = 0; ncn = 0; ncf = 0;
    for i = 1:ncnt
        near_dv = qbs(i) + wm*rmn(i);
        far_dv  = qbd(i) + wm*rmf(i);
        if same_near(i) == 1
            sc = sc + 1;
            if near_dv >= gc, ncs = ncs + 1; ncn = ncn + 1; end
        else
            dc = dc + 1;
            if near_dv <  gc, ncd = ncd + 1; else, ncn = ncn + 1; end
        end
        if same_far(i) == 1
            sc = sc + 1;
            if far_dv >= gc, ncs = ncs + 1; else, ncf = ncf + 1; end
        else
            dc = dc + 1;
            if far_dv <  gc, ncd = ncd + 1; ncf = ncf + 1; end
        end
    end
    pc   = (ncd + ncs) / (2*ncnt);
    pcs  = ncs / sc;
    pcd  = ncd / dc;
    pcnf = (ncn + ncf) / (2*ncnt);
end
