function Y = predictTwin(net,fcParams,X1,X2)
% predictTwin accepts the network and pair of images, and returns a
% prediction of the probability of the pair being similar (closer to 1) or
% dissimilar (closer to 0). Use predictTwin during prediction.

% Pass each image through the twin subnetwork, then pool its feature map to
% raw per-patch texture statistics (mean/std/correlation) via poolStats.
S1 = poolStats(predict(net,X1));
S2 = poolStats(predict(net,X2));

% Build the two-patch comparison (d', std difference, correlation difference).
Y = compareTwin(S1,S2);

% Pass result through a fullyconnect operation.
Y = fullyconnect(Y,fcParams.FcWeights,fcParams.FcBias);

% Convert to probability between 0 and 1.
Y = sigmoid(Y);

end
