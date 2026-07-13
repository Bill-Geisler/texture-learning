function [loss,gradientsSubnet,gradientsParams] = modelLoss(net,fcParams,X1,X2,pairLabels)

% Pass the image pair through the network.
Y = forwardTwin(net,fcParams,X1,X2);

% Calculate binary cross-entropy loss.
loss = crossentropy(Y,pairLabels,ClassificationMode="multilabel");

% Calculate gradients of the loss with respect to the network learnable
% parameters.
[gradientsSubnet,gradientsParams] = dlgradient(loss,net.Learnables,fcParams);

end