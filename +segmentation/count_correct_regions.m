function n_correct = count_correct_regions(truth_map, n_truth, est_map, n_est)
% COUNT_CORRECT_REGIONS  Count estimated regions that exactly match a ground-truth region.
%   n_correct = segmentation.count_correct_regions(truth_map, n_truth, est_map, n_est)
%
%   Compares each estimated region's patch mask against each ground-truth
%   region's mask and counts exact matches. (Was reg_count.m.)
%
%   Inputs
%     truth_map - [npx x npy] ground-truth region-label map.
%     n_truth   - number of ground-truth regions.
%     est_map   - [npx x npy] estimated region-label map.
%     n_est     - number of estimated regions.
%
%   Output
%     n_correct - number of exactly-correct regions.

    [npx, npy] = size(truth_map);
    truth_masks = false(n_truth, npx, npy);
    for k = 1:n_truth
        truth_masks(k, :, :) = (truth_map == k);
    end
    est_masks = false(n_est, npx, npy);
    for k = 1:n_est
        est_masks(k, :, :) = (est_map == k);
    end

    n_correct = 0;
    for k = 1:n_truth
        for l = 1:n_est
            if all(truth_masks(k, :, :) == est_masks(l, :, :), 'all')
                n_correct = n_correct + 1;
            end
        end
    end
end
