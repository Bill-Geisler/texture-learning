function imgout = rot(img,rmtx,psz)
%
% apply rotation matrix to color image
%
tmp = reshape(img,[],3);
tmp = tmp*rmtx;
imgout = reshape(tmp,psz,psz,3);
