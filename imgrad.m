function [gmout,goout] = imgrad(ptch,sd,nsd)
%
% compute edge gradients and magnitude and local mean for a patch
%
% ptch = image patch
% sd = standard deviation of Gaussian in pixels
% nsd = kernel width in number of standard deviations
%
[sz,~] = size(ptch); dsz = floor(sd*nsd/2 + 1);
[khz,kvt] = mk_dg_hv(sd,nsd);
gh = conv2(ptch,khz,'same');
gv = conv2(ptch,kvt,'same');
go = atan2d(gh,gv);
gm = (sind(go).*gh + cosd(go).*gv);
gmout = gm(dsz:sz-dsz+1,dsz:sz-dsz+1);
goout = go(dsz:sz-dsz+1,dsz:sz-dsz+1);
end