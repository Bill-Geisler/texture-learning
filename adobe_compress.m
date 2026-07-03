function imgout = adobe_compress(img)
%
% Convert linear image to gamma-compressed image
% using the Adobe gamma
%
ag = 2.19921875; % gamma for Adobe gamma compression
scl = 1/(255^(1-ag)); 
imgout(:,:,1) = (img(:,:,1)*scl).^(1/ag);
imgout(:,:,2) = (img(:,:,2)*scl).^(1/ag);
imgout(:,:,3) = (img(:,:,3)*scl).^(1/ag);
end