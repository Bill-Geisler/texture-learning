function [qbs, qbd] = self_sup_decision(method, R, dv)
% SELF_SUP_DECISION  Per-image self-supervised combined decision variable.
%   [qbs, qbd] = self_sup_decision(method, R, dv)
%
%   Returns the combined border+content decision variable for the near (qbs) and
%   far (qbd) patch pairs in R (from neighbor_far_responses), after the per-image
%   self-supervised step. Shared by pipeline stages s6 and s7.
%
%   method:
%     'bc'         - refit the border+content bound on THIS image (classify_normals),
%                    treating near pairs as "same" and far pairs as "different".
%     'bc_shft'    - load the trained bc bound; learn a scalar shift of the bc DV.
%     'bc_noshift' - load the trained bc bound; apply it with no shift.
%     'c_shft'     - load the trained bc bound; learn a scalar shift of the content DV.
%
%   'bc' requires the IntClassNorm add-on (classify_normals); the others require
%   the trained bc bound handle dv.bc (see load_dv_handles with load_bc=true).

    n = R.ncnt;
    qbs = zeros(1, n);  qbd = zeros(1, n);
    switch method
        case 'bc'                                   % refit the bc bound on this image
            bd = classify_normals([R.rcn', R.rbn'], [R.rcf', R.rbf'], 'input_type', 'samp', 'plotmode', 0);
            dvbc = quad2fun(bd.samp_opt_bd, 0);
            for i = 1:n
                qbs(i) = dvbc([R.rcn(i), R.rbn(i)]');
                qbd(i) = dvbc([R.rcf(i), R.rbf(i)]');
            end
        case 'bc_shft'                              % shift the pre-trained bc DV
            rbcn = apply_bc(dv.bc, R.rbn, R.rcn);
            rbcf = apply_bc(dv.bc, R.rbf, R.rcf);
            copt = best_criterion(rbcn, rbcf, 5);
            qbs = rbcn - copt;
            qbd = rbcf - copt;
        case 'bc_noshift'                           % pre-trained bc DV, no shift
            qbs = apply_bc(dv.bc, R.rbn, R.rcn);
            qbd = apply_bc(dv.bc, R.rbf, R.rcf);
        case 'c_shft'                               % shift the content DV, then bc bound
            rcn = nan_to_zero(R.rcn);  rcf = nan_to_zero(R.rcf);
            rbn = nan_to_zero(R.rbn);  rbf = nan_to_zero(R.rbf);
            copt = best_criterion(rcn, rcf, 1);
            for i = 1:n
                qbs(i) = dv.bc([rcn(i) - copt, rbn(i)]');
                qbd(i) = dv.bc([rcf(i) - copt, rbf(i)]');
            end
        otherwise
            error('self_sup_decision:badMethod', 'unknown method "%s"', method);
    end
end

function v = apply_bc(dvbc, rb, rc)
    v = zeros(1, numel(rb));
    for i = 1:numel(rb)
        v(i) = dvbc([rc(i), rb(i)]');           % [content, border] ordering (Geisler-confirmed; matches s5 dbndbc training)
    end
    v(isnan(v)) = 0;
end

function x = nan_to_zero(x), x(isnan(x)) = 0; end

function copt = best_criterion(near_vals, far_vals, hi_fallback)
% Criterion maximizing same/different accuracy (near = same, far = different).
    lo = mean(far_vals);  hi = mean(near_vals);
    if isnan(hi), hi = lo + hi_fallback; end
    step = (hi - lo) / 100;
    if step <= 0, copt = lo; return; end
    copt = lo;  best = 0;
    for crit = lo:step:hi
        pc = (sum(near_vals >= crit) + sum(far_vals < crit)) / (numel(near_vals) + numel(far_vals));
        if pc > best, best = pc; copt = crit; end
    end
end
