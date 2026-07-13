function coords = find_nat_patch(img,psz,same_max_dist)
%
% find near and far texture patch pairs (proximity only; no color criterion)
%
% img = input image (used only for its size)
% psz = patch size
% same_max_dist = max neighbor offset (in patches) for the near pair
%
% the far pair must be separated by more than a quarter of the image
% height (dcrit = image_height/4), matching nat_near_far_patches.m
%
% coords: (1,:) = xcoor, ycoor for near reference patch
% coords: (2,:) = xcoor, ycoor for near partner patch
% coords: (3,:) = xcoor, ycoor for far reference patch
% coords: (4,:) = xcoor, ycoor for far partner patch
%
coords = nan(4,2);
sz = size(img);
dcrit = sz(1)/4; % min far-pair separation = quarter of image height

% find near pair: reference + a randomly chosen adjacent (non-overlapping) neighbor
x_a = randi(sz(1)-4*same_max_dist*psz)+2*same_max_dist*psz;
y_a = randi(sz(2)-4*same_max_dist*psz)+2*same_max_dist*psz;
coords(1,:) = [x_a y_a];

% enumerate valid neighbor offsets (excluding the reference itself)
offsets = [];
for i = -same_max_dist:same_max_dist
    for j = -same_max_dist:same_max_dist
        if i==0 && j==0 % not the same as the reference patch
            continue;
        end
        x = i*psz; y = j*psz;
        if (x_a+x < 1) || (x_a+x+psz-1 > sz(1))
            continue;
        end
        if (y_a+y < 1) || (y_a+y+psz-1 > sz(2))
            continue;
        end
        offsets(end+1,:) = [x y]; %#ok<AGROW>
    end
end
sel = offsets(randi(size(offsets,1)),:);
coords(2,:) = [x_a+sel(1) y_a+sel(2)];

% find far pair: reference + random patch beyond dcrit (image_height/4).
% loop until found (no retry cap) so every call returns a valid pair
found = false;
while ~found

    % randomly select the far reference patch
    x_a = randi(sz(1)-4*same_max_dist*psz)+2*same_max_dist*psz;
    y_a = randi(sz(2)-4*same_max_dist*psz)+2*same_max_dist*psz;
    coords(3,:) = [x_a y_a];

    % randomly select a distant patch
    x_b = randi(sz(1)-4*same_max_dist*psz)+2*same_max_dist*psz;
    y_b = randi(sz(2)-4*same_max_dist*psz)+2*same_max_dist*psz;
    dp = sqrt((x_b-x_a)^2 + (y_b-y_a)^2);
    if dp > dcrit
        coords(4,:) = [x_b y_b];
        found = true;
    end
end
