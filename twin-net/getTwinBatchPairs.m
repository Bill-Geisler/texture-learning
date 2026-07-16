function [X1,X2,pairLabels] = getTwinBatchPairs(pos,neg,miniBatchSize)
% getTwinBatchPairs draws a balanced 50/50 batch from two arrays of pre-stored
% patch pairs.
%
% pos, neg: [psz psz 2 N] uint8 patch pairs; dim 3 holds the two patches of a pair.
% Returns X1, X2 (patch 1 and patch 2 of each pair) and pairLabels, with label 1
% for pos pairs and 0 for neg pairs.
%
% Used for both natural-image pairs (pos = near, neg = far) and Brodatz test pairs
% (pos = same texture, neg = different textures).

n_pos = size(pos,4);
n_neg = size(neg,4);

% split the batch into pos (label 1) and neg (label 0) at 50/50 in expectation
choice = rand(1, miniBatchSize) < 0.5;
num_pos = sum(choice);
num_neg = miniBatchSize - num_pos;

k_pos = randi(n_pos, 1, num_pos);
k_neg = randi(n_neg, 1, num_neg);

X1 = cat(4, pos(:,:,1,k_pos), neg(:,:,1,k_neg));
X2 = cat(4, pos(:,:,2,k_pos), neg(:,:,2,k_neg));

pairLabels = [ones(1,num_pos), zeros(1,num_neg)];

end
