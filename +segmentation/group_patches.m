function [groups, ngrps, groups2d] = group_patches(similarity, distance, n_patches, ...
        group_criterion, confidence_criterion, neighbor_distance, patch_x, patch_y, content_sim, merge_criterion)
% GROUP_PATCHES  Segment patches by local-similarity, transitive, isolated, and region grouping.
%   [groups, ngrps, groups2d] = segmentation.group_patches(similarity, distance, ...
%       n_patches, group_criterion, confidence_criterion, neighbor_distance, ...
%       patch_x, patch_y, content_sim, merge_criterion)
%
%   The HBO texture-segmentation grouping pipeline (was mk_groups.m):
%     1. Local-similarity grouping: link confident same neighbouring pairs.
%     2. Transitive grouping: connected components of the link graph.
%     3. Isolated-patch (confidence) grouping (segmentation.assign_isolated_patches).
%     4. Region-similarity grouping (segmentation.merge_similar_regions).
%   Dead code from the original (disabled weak-patch relinking, the never-run
%   `nodes` loop, and the unused `dmincnt`/weak-link bookkeeping) has been removed;
%   the active behaviour is unchanged.
%
%   Inputs
%     similarity           - combined similarity matrix s_ij (content + mutual).
%     distance             - patch-pair distance matrix.
%     n_patches            - grid width in patches.
%     group_criterion      - link threshold (paper: gamma_l).
%     confidence_criterion - min distance from the threshold to link (paper: gamma_c).
%     neighbor_distance    - distance value identifying neighbouring pairs.
%     patch_x, patch_y     - patch-index -> grid-coordinate maps.
%     content_sim          - all-pairs content similarity (for isolated/region steps).
%     merge_criterion      - region-merge threshold (paper: gamma_r).
%
%   Outputs
%     groups   - group membership (row per group, patch indices, 0-padded).
%     ngrps    - number of groups.
%     groups2d - [n_patches x n_patches] region-label map.

    n = n_patches^2;

    % --- 1. local-similarity grouping: link confident "same" neighbour pairs ---
    links = zeros(n, n);
    for i = 1:n
        for j = i+1:n
            if distance(i, j) == neighbor_distance ...
                    && similarity(i, j) > group_criterion ...
                    && abs(similarity(i, j) - group_criterion) > confidence_criterion
                links(i, j) = 1;
                links(j, i) = 1;
            end
        end
    end

    % --- 2. transitive grouping: extract connected components of the link graph ---
    ngrps = 0;
    groups = zeros(n, 2*n);
    done = false;
    while ~done
        % find the first patch that still has a link
        i = 1;
        while max(links(i, :)) == 0 && ~done
            i = i + 1;
            if i == n
                done = true;
            end
        end
        if done
            break;
        end

        % breadth-first expansion over the link graph
        node_list = zeros(2*n, 2);
        node_list(1, :) = [i, i];
        n_nodes = 1;
        ptr = 1;
        while i > 0
            for j = 1:n
                seen = false;
                for m = 1:n_nodes
                    if node_list(m, 2) == j
                        seen = true;
                    end
                end
                if links(i, j) == 1 && ~seen
                    n_nodes = n_nodes + 1;
                    node_list(n_nodes, :) = [i, j];
                end
            end
            ptr = ptr + 1;
            i = node_list(ptr, 2);          % next node (0 terminates)
        end

        ngrps = ngrps + 1;
        groups(ngrps, :) = sort(node_list(:, 2), 'descend');
        for idx = 1:ptr-1                   % remove this component's nodes from the graph
            links(node_list(idx, 2), :) = 0;
            links(:, node_list(idx, 2)) = 0;
        end
    end

    % --- build the initial 2-D map and per-group counts ---
    [groups2d, group_counts] = build_group_map(groups, ngrps, n_patches, patch_x, patch_y);

    % collect still-unlinked patches
    unlinked = zeros(n, 2);
    n_unlinked = 0;
    for i = 1:n_patches
        for j = 1:n_patches
            if groups2d(i, j) == 0
                n_unlinked = n_unlinked + 1;
                unlinked(n_unlinked, :) = [i, j];
            end
        end
    end

    % --- 3. isolated-patch grouping (ngrps update intentionally discarded, as in original) ---
    [groups, groups2d] = segmentation.assign_isolated_patches(groups, groups2d, ngrps, n, n_patches, patch_x, patch_y, content_sim);
    for k = 1:n_unlinked
        gn = groups2d(unlinked(k, 1), unlinked(k, 2));
        loc = (unlinked(k, 1) - 1) * n_patches + unlinked(k, 2);
        if gn <= ngrps
            groups(gn, group_counts(gn)) = loc;
            group_counts(gn) = group_counts(gn) + 1;
        else
            group_counts(gn) = group_counts(gn) + 1;
            groups(gn, 1) = loc;
            ngrps = ngrps + 1;
        end
    end

    % --- 4. region-similarity grouping (single best merge) ---
    [groups, ngrps] = segmentation.merge_similar_regions(groups, ngrps, group_counts, groups2d, n_patches, content_sim, merge_criterion);

    % --- final 2-D map ---
    groups2d = build_group_map(groups, ngrps, n_patches, patch_x, patch_y);
end

function [groups2d, group_counts] = build_group_map(groups, ngrps, n_patches, patch_x, patch_y)
% Build the 2-D region-label map and per-group patch-count (+1) from membership.
    groups2d = zeros(n_patches, n_patches);
    group_counts = zeros(n_patches^2, 1);
    for grp = 1:ngrps
        i = 1;
        while groups(grp, i) > 0
            groups2d(patch_x(groups(grp, i)), patch_y(groups(grp, i))) = grp;
            i = i + 1;
        end
        group_counts(grp) = i;             % count + 1 (matches original gcnt)
    end
end
