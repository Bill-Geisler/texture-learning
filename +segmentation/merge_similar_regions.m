function [groups, ngrps] = merge_similar_regions(groups, ngrps, group_counts, groups2d, content_sim, merge_criterion)
% MERGE_SIMILAR_REGIONS  Merge the single most-similar pair of touching regions.
%   [groups, ngrps] = segmentation.merge_similar_regions(groups, ngrps, ...
%       group_counts, groups2d, content_sim, merge_criterion)
%
%   Region-similarity grouping step: finds spatially touching region pairs,
%   computes their mean content similarity, and merges the most-similar pair if
%   it exceeds merge_criterion. One merge per call. (Was merge_groups.m.)
%
%   Inputs
%     groups          - group membership (row per group, patch indices).
%     ngrps           - number of groups.
%     group_counts    - per-group patch-count + 1 (as produced by group_patches).
%     groups2d        - 2-D region-label map ([npx x npy]).
%     content_sim     - all-pairs content-similarity matrix.
%     merge_criterion - merge if mean similarity exceeds this (paper: gamma_r).
%
%   Outputs
%     groups, ngrps - updated membership and group count.

    [npx, npy] = size(groups2d);        % grid rows x cols

    % adjacency: which regions touch which (4-neighbour)
    touching = zeros(ngrps, ngrps);
    for k = 1:ngrps
        for i = 1:npx
            for j = 1:npy
                if groups2d(i, j) == k
                    if j < npy && groups2d(i, j+1) ~= k, touching(k, groups2d(i, j+1)) = 1; end
                    if j > 1   && groups2d(i, j-1) ~= k, touching(k, groups2d(i, j-1)) = 1; end
                    if i < npx && groups2d(i+1, j) ~= k, touching(k, groups2d(i+1, j)) = 1; end
                    if i > 1   && groups2d(i-1, j) ~= k, touching(k, groups2d(i-1, j)) = 1; end
                end
            end
        end
    end

    % mean content similarity between each touching pair
    mean_sim = zeros(ngrps, ngrps);
    for k = 1:ngrps
        for l = k+1:ngrps
            if touching(k, l) == 1
                count = 0;
                for a = 1:group_counts(k)
                    for b = 1:group_counts(l)
                        p1 = groups(k, a);
                        p2 = groups(l, b);
                        if p1 > 0 && p2 > 0
                            count = count + 1;
                            mean_sim(k, l) = mean_sim(k, l) + content_sim(p1, p2);
                        end
                    end
                end
                mean_sim(k, l) = mean_sim(k, l) / count;
            end
        end
    end

    % merge the most-similar pair if above criterion
    max_sim = -inf; km = 0; lm = 0;
    for k = 1:ngrps
        for l = k+1:ngrps
            if mean_sim(k, l) > max_sim
                max_sim = mean_sim(k, l);
                km = k; lm = l;
            end
        end
    end
    if max_sim > merge_criterion
        groups(km, group_counts(km)+1 : group_counts(km)+group_counts(lm)) = groups(lm, 1:group_counts(lm));
        groups(lm, 1:group_counts(lm)) = 0;
        groups(km, :) = sort(groups(km, :), 'descend');
        for k = lm+1:ngrps
            groups(k-1, :) = groups(k, :);
        end
        groups(ngrps, :) = 0;
        ngrps = ngrps - 1;
    end
end
