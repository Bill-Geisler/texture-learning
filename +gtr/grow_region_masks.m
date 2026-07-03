function [masks, maps] = grow_region_masks(n_patches, n_regions, n_trials, seed_radius_frac, coverage)
% GROW_REGION_MASKS  Grow random contiguous texture-region masks for GTR images.
%   [masks, maps] = gtr.grow_region_masks(n_patches, n_regions, n_trials, ...
%                       seed_radius_frac, coverage)
%
%   For each trial, seeds n_regions region labels near the image center and
%   grows them by a random Markov process (adding a free 4-neighbor patch at a
%   time) until the given fraction of the patch grid is filled. Produces the
%   per-region binary masks and the integer region-label map per trial.
%   (Was mk_masks.m; masks preallocation size fixed to n_trials*n_regions.)
%
%   Inputs
%     n_patches        - grid width in patches (image is n_patches x n_patches).
%     n_regions        - number of texture regions per image.
%     n_trials         - number of trials (images).
%     seed_radius_frac - seed placement radius as a fraction of the max radius.
%     coverage         - fraction of the patch grid to fill (0..1).
%
%   Outputs
%     masks - [n_patches x n_patches x (n_trials*n_regions)] binary region masks.
%     maps  - [n_patches x n_patches x n_trials] integer region-label maps.

    seed_radius = seed_radius_frac * n_patches / 2;
    masks = zeros(n_patches, n_patches, n_trials * n_regions);   % (fix: was n_patches*n_regions)
    maps  = zeros(n_patches, n_patches, n_trials);

    for t = 1:n_trials
        map = zeros(n_patches, n_patches);                      % region-label map
        % region(r): patch list, column 1 = count, then interleaved (x,y) coords
        region = zeros(n_regions, round(3 * n_patches^2 / n_regions) + 1);

        % --- seed the regions near the center, no two on the same patch ---
        seeds = zeros(n_regions, 2);
        for r = 1:n_regions
            placed = false;
            while ~placed
                in_radius = false;
                while ~in_radius
                    x = randi(n_patches);
                    y = randi(n_patches);
                    if sqrt((x - n_patches/2)^2 + (y - n_patches/2)^2) < seed_radius
                        in_radius = true;
                    end
                end
                placed = ~any(seeds(:,1) == x & seeds(:,2) == y);
            end
            seeds(r,:) = [x, y];
            map(x, y) = r;
            region(r,1) = 1; region(r,2) = x; region(r,3) = y;  % first patch of region r
        end

        % --- grow the regions until 'coverage' of the grid is filled ---
        while sum(region(:,1)) < coverage * n_patches^2
            for r = randperm(n_regions)                          % random region order each pass
                count = region(r,1);
                k = 1;
                order = randperm(count);                         % scan patches in random order
                while count == region(r,1) && k <= count        % stop once one patch is added
                    x = region(r, 2*order(k));
                    y = region(r, 2*order(k) + 1);
                    for side = randperm(4)                       % check 4 sides in random order
                        [free, xn, yn] = neighbor_free(side, x, y, map, n_patches);
                        if free
                            region(r,1) = region(r,1) + 1;
                            region(r, 2*(count+1))     = xn;
                            region(r, 2*(count+1) + 1) = yn;
                            map(xn, yn) = r;
                            break;
                        end
                    end
                    k = k + 1;
                end
            end
        end

        % --- per-region binary masks and the label map ---
        for r = 1:n_regions
            masks(:, :, (t-1)*n_regions + r) = (map == r);
        end
        maps(:, :, t) = map;
    end
end

function [free, xout, yout] = neighbor_free(side, x, y, map, n_patches)
% Is the 4-neighbor on the given side (1=+x, 2=+y, 3=-x, 4=-y) in-bounds and free?
    xout = x; yout = y; free = false;
    switch side
        case 1
            if x < n_patches && map(x+1, y) == 0, xout = x+1; free = true; end
        case 2
            if y < n_patches && map(x, y+1) == 0, yout = y+1; free = true; end
        case 3
            if x > 1 && map(x-1, y) == 0, xout = x-1; free = true; end
        case 4
            if y > 1 && map(x, y-1) == 0, yout = y-1; free = true; end
    end
end
