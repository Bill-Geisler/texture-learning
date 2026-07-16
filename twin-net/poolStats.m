function emb = poolStats(F)
% poolStats  Order-invariant texture statistics of a network feature map.
%   emb = poolStats(F) takes a feature map F in "SSCB" format ([H W C B]) and
%   returns a per-patch embedding that pools over the spatial positions, so
%   feature *position* is discarded and only feature *statistics* are kept
%   (mimicking the position-agnostic features of the Bayesian proximity model).
%
%   The embedding is each channel's mean and standard deviation over the patch
%   (2C numbers: how much of each feature is present, and its spread), then
%   L2-normalized and returned as an "SSCB" dlarray [1 1 2C B]. L2 normalization
%   replaces a saturating sigmoid on the embedding (pooled ReLU outputs are >= 0).
%   With C = 32 in architecture C, D = 2C = 64.

    F = stripdims(F);                          % work unformatted, keep autodiff

    m = mean(F, [1 2]);                        % [1 1 C B]
    v = mean(F.^2, [1 2]) - m.^2;              % [1 1 C B]
    s = sqrt(max(v, 0) + 1e-6);                % [1 1 C B]
    emb = cat(3, m, s);                        % [1 1 2C B]
    emb = emb ./ sqrt(sum(emb.^2, 3) + 1e-6);
    emb = dlarray(emb, 'SSCB');
end
