function imgout = adobe_expand(img)
%
% Convert gamma-compressed image to linear image
% using the Adobe gamma
%
ag = 2.19921875; % gamma for Adobe gamma expansion
scl = 255^(1-ag);
imgout(:,:,1) = (img(:,:,1).^ag)*scl;
imgout(:,:,2) = (img(:,:,2).^ag)*scl;
imgout(:,:,3) = (img(:,:,3).^ag)*scl;
end