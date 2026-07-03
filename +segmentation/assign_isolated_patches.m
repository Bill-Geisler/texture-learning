function [groups, groups2d, ngrps] = assign_isolated_patches(groups, groups2d, ngrps, sz, n_patches, patch_x, patch_y, content_sim)
% ASSIGN_ISOLATED_PATCHES  Attach unlinked patches to their best neighbouring group.
%   [groups, groups2d, ngrps] = segmentation.assign_isolated_patches(groups, ...
%       groups2d, ngrps, sz, n_patches, patch_x, patch_y, content_sim)
%
%   Confidence-grouping step: each patch left unlinked after transitive grouping
%   is assigned to the 4-neighbour group with the highest content similarity (if
%   positive); otherwise it starts a new group. (Was iso_patch.m.)
%
%   NOTE: the inner scan keeps the original `r ~= c` guard (was `i ~= j`), which
%   skips grid cells on the row==col diagonal. This looks unintended (probably
%   meant to exclude the patch itself); PRESERVED as-is and flagged for Geisler.
%
%   Inputs
%     groups, groups2d - current group membership and 2-D label map.
%     ngrps            - current number of groups.
%     sz               - total number of patches (n_patches^2).
%     n_patches        - grid width in patches.
%     patch_x, patch_y - patch-index -> grid-coordinate maps.
%     content_sim      - all-pairs content-similarity matrix.
%
%   Outputs
%     groups, groups2d, ngrps - updated membership, map, and group count.

    % list isolated patches (label 0) with their 4-neighbour group labels
    isolated = zeros(sz, 6);   % [row, col, up, left, down, right]
    n_iso = 0;
    for i = 1:n_patches
        for j = 1:n_patches
            if groups2d(i, j) == 0
                n_iso = n_iso + 1;
                isolated(n_iso, 1) = i;
                isolated(n_iso, 2) = j;
                if i > 1,         isolated(n_iso, 3) = groups2d(i-1, j); end
                if j > 1,         isolated(n_iso, 4) = groups2d(i, j-1); end
                if i < n_patches, isolated(n_iso, 5) = groups2d(i+1, j); end
                if j < n_patches, isolated(n_iso, 6) = groups2d(i, j+1); end
            end
        end
    end

    % assign each isolated patch to its best-matching neighbouring group
    for p = 1:n_iso
        max_sim = -100;
        best_group = 0;
        patch_row = isolated(p, 1);
        patch_col = isolated(p, 2);
        patch_idx = (patch_row - 1) * n_patches + patch_col;
        for side = 3:6
            gnum = isolated(p, side);
            if gnum ~= 0
                for r = 1:n_patches
                    for c = 1:n_patches
                        if groups2d(r, c) == gnum && r ~= c   % 'r~=c' preserved; see NOTE
                            other_idx = (r - 1) * n_patches + c;
                            sim = content_sim(patch_idx, other_idx);
                            if sim > max_sim
                                max_sim = sim;
                                best_group = gnum;
                            end
                        end
                    end
                end
            end
        end
        if max_sim > 0
            groups2d(patch_x(patch_idx), patch_y(patch_idx)) = best_group;
        else
            ngrps = ngrps + 1;
            groups2d(patch_x(patch_idx), patch_y(patch_idx)) = ngrps;
            groups(ngrps, 1) = ngrps;
        end
    end
end
