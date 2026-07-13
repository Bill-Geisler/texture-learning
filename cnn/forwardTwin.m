function Y = forwardTwin(net,fcParams,X1,X2)
% forwardTwin accepts the network and pair of training images, and
% returns a prediction of the probability of the pair being similar (closer
% to 1) or dissimilar (closer to 0). Use forwardTwin during training.

% Pass each image through the twin subnetwork, then pool its feature map to
% mean+std texture statistics (L2-normalized) via poolStats.
Y1 = poolStats(forward(net,X1));
Y2 = poolStats(forward(net,X2));

% Subtract the feature vectors
Y = abs(Y1 - Y2);

% Pass the result through a fullyconnect operation
Y = fullyconnect(Y,fcParams.FcWeights,fcParams.FcBias);

% Convert to probability between 0 and 1.
Y = sigmoid(Y);

end