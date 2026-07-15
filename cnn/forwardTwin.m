function Y = forwardTwin(net,fcParams,X1,X2)
% forwardTwin accepts the network and pair of training images, and
% returns a prediction of the probability of the pair being similar (closer
% to 1) or dissimilar (closer to 0). Use forwardTwin during training.

% Pass each image through the twin subnetwork, then pool its feature map to
% raw per-patch texture statistics (mean/std/correlation) via poolStats.
S1 = poolStats(forward(net,X1));
S2 = poolStats(forward(net,X2));

% Build the two-patch comparison (d', std difference, correlation difference).
Y = compareTwin(S1,S2);

% Pass the result through a fullyconnect operation.
Y = fullyconnect(Y,fcParams.FcWeights,fcParams.FcBias);

% Convert to probability between 0 and 1.
Y = sigmoid(Y);

end
