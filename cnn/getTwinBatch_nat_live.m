function [X1,X2,pairLabels] = getTwinBatch_nat_live(A_pool,miniBatchSize,psz,same_max_dist)
% getTwinBatch_nat_live cuts a balanced batch of FRESH near/far patch pairs from
% the pool of achromatic (A) source images. Each pair is cut at random
% coordinates from a randomly chosen image, so pairs effectively never repeat
% across training -- there is nothing for the network to memorize. This is the
% on-the-fly replacement for slicing a fixed, pre-stored pair array (as
% getTwinBatchPairs does for the Brodatz test set).
%
% A_pool:        1xN cell array of uint8 A images (from load_nat_A_pool)
% miniBatchSize: number of pairs in the batch
% psz:           patch size (e.g. 64; matches the [64 64 1] network input)
% same_max_dist: max neighbor offset (in patches) for the near pair
%
% Returns X1,X2 as [psz psz 1 miniBatchSize] uint8 (patch 1 and patch 2 of each
% pair) and pairLabels as a 1 x miniBatchSize row vector (1 = near/positive,
% 0 = far/negative). Patches are cut on the CPU; train_cnn moves the finished
% batch to the GPU.
%
% Note: this must NOT reseed the RNG. The offline generator reseeds per image with
% rng(k) for reproducibility, but here we want every batch to be genuinely new, so
% we let the global RNG run freely.

n_img = numel(A_pool);

% decide near vs far per slot -- 50/50 in expectation
choice = rand(1,miniBatchSize) < 0.5;   % true -> near
num_near = sum(choice);
num_far  = miniBatchSize - num_near;

X1 = zeros(psz,psz,1,miniBatchSize,'uint8');
X2 = zeros(psz,psz,1,miniBatchSize,'uint8');

% near pairs first, then far pairs. A single
% find_nat_patch call returns both a near pair (rows 1-2) and a far pair
% (rows 3-4); we keep only the one we need for this slot. find_nat_patch is cheap
% (random coordinates + a small offset enumeration), so discarding the other half
% is not a meaningful cost next to the GPU forward/backward pass.
for i = 1:num_near
    A = A_pool{randi(n_img)};
    coords = find_nat_patch(A,psz,same_max_dist);
    x_a = coords(1,1); y_a = coords(1,2);
    x_b = coords(2,1); y_b = coords(2,2);
    X1(:,:,1,i) = A(x_a:x_a+psz-1, y_a:y_a+psz-1);
    X2(:,:,1,i) = A(x_b:x_b+psz-1, y_b:y_b+psz-1);
end
for j = 1:num_far
    A = A_pool{randi(n_img)};
    coords = find_nat_patch(A,psz,same_max_dist);
    x_a = coords(3,1); y_a = coords(3,2);
    x_b = coords(4,1); y_b = coords(4,2);
    X1(:,:,1,num_near+j) = A(x_a:x_a+psz-1, y_a:y_a+psz-1);
    X2(:,:,1,num_near+j) = A(x_b:x_b+psz-1, y_b:y_b+psz-1);
end

pairLabels = [ones(1,num_near) zeros(1,num_far)];
end
