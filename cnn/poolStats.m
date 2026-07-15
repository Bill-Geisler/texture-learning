function stats = poolStats(F)
% poolStats  Order-invariant texture statistics of a CNN feature map.
%   stats = poolStats(F) takes a feature map F in "SSCB" format ([H W C B]) and
%   returns the per-patch statistics that pool over the spatial positions, so
%   feature *position* is discarded and only feature *statistics* are kept
%   (mimicking the position-agnostic features of the Bayesian proximity model).
%
%   Returns a struct of "SSCB" dlarrays, one row of features per channel/pair:
%     stats.m    [1 1 C B]          channel means over the patch
%     stats.s    [1 1 C B]          channel standard deviations over the patch
%     stats.corr [1 1 C(C-1)/2 B]   strict upper triangle of the C-by-C channel
%                                    correlation matrix (feature co-occurrence)
%
%   These are the RAW per-patch statistics. The two-patch comparison (d', std
%   difference, correlation difference) is built by compareTwin from a pair of
%   these structs -- it cannot live here because d' couples both patches' stds.
%   The correlation is used in place of the raw covariance so it is dimensionless
%   (units-consistent across patches); its diagonal is identically 1, so only the
%   strict upper triangle is kept.

    F = stripdims(F);                          % work unformatted, keep autodiff
    [H, W, C, B] = size(F, 1:4);
    HW = H * W;

    X = reshape(F, HW, C, B);                  % [HW C B] collapse spatial positions
    m = mean(X, 1);                            % [1 C B] channel means
    Xc = X - m;                                % [HW C B] centered
    v = mean(Xc.^2, 1);                        % [1 C B] channel variance
    s = sqrt(v + 1e-6);                        % [1 C B] channel std (clamped, differentiable)

    % Channel correlation, pooled over the HW spatial positions:
    % corr(i,j) = cov(i,j)/(s_i s_j), with cov = Xc' * Xc / HW batched over B.
    % pagemtimes is autodiff-safe on unformatted dlarrays.
    Cov = pagemtimes(Xc, 'transpose', Xc, 'none') / HW;   % [C C B]
    si = reshape(s, C, 1, B);                  % [C 1 B]
    sj = reshape(s, 1, C, B);                  % [1 C B]
    Corr = Cov ./ (si .* sj);                  % [C C B] dimensionless

    % Strict upper triangle only (matrix is symmetric; diagonal is identically 1).
    mask = triu(true(C), 1);                   % C-by-C strict-upper selector
    corrHalf = reshape(Corr, C*C, B);          % [C*C B]
    corrHalf = corrHalf(mask(:), :);           % [C(C-1)/2 B]
    nCorr = C*(C-1)/2;

    stats.m    = dlarray(reshape(m, 1, 1, C, B), 'SSCB');
    stats.s    = dlarray(reshape(s, 1, 1, C, B), 'SSCB');
    stats.corr = dlarray(reshape(corrHalf, 1, 1, nCorr, B), 'SSCB');
end
