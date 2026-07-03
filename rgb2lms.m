function imgout = rgb2lms(img,lms)
%
% convert from camera rgb color space to lms color space
%
% lms = rgb to lms matrix
% sz = image size
%
[sz1,sz2,dim] = size(img);
tmp = reshape(img,[],dim);
tmp = tmp*lms;
imgout = max(reshape(tmp,sz1,sz2,3),0);

