function emb = poolStats(F)
% poolStats  Order-invariant texture statistics of a CNN feature map.
%   emb = poolStats(F) takes a feature map F in "SSCB" format ([H W C B])
%   and returns a per-patch embedding that pools over the spatial
%   dimensions: the channel-wise mean and standard deviation, concatenated
%   ([1 1 2C B]), then L2-normalized over the channel dimension.
%
%   Pooling over space discards feature *position* and keeps only feature
%   *statistics*, mimicking the position-agnostic histogram/power features
%   of the Bayesian proximity model. The std term carries the spread
%   (contrast) of each feature that a mean-only global average pool would
%   throw away. The L2 normalization replaces the old saturating sigmoid on
%   the embedding (pooled ReLU outputs are all >= 0, so a sigmoid there only
%   uses its upper half and can saturate).

    m = mean(F, [1 2]);                        % channel means      [1 1 C B]
    v = mean(F.^2, [1 2]) - m.^2;              % channel variance   [1 1 C B]
    s = sqrt(max(v, 0) + 1e-6);                % channel std (clamped, differentiable)
    emb = cat(3, m, s);                        % [1 1 2C B]
    emb = emb ./ sqrt(sum(emb.^2, 3) + 1e-6);  % L2-normalize over channels
end
