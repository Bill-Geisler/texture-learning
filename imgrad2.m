function [gm2out,go2out] = imgrad2(ptch,sd,nsd)
%
% compute response magnitudes and orientations of a patch using 
% steerable second derivative kernels
%
% ptch = image patch
% sd = standard deviation of Gaussian in pixels
% nsd = kernel width in number of standard deviations
%
% gm2 = response magnitude map
% go2 = first-root and final response orientation map (see math)
% go2b = second-root oriention response
%
% routines called:
%    mk_2dg_sf.m makes three kernels
%
[sz,~] = size(ptch); dsz = floor(sd*nsd/2 + 1);
[k0,k45,k90] = mk_2dg_sf(sd,nsd); % make kernels
r0 = conv2(ptch,k0,'same');
r45 = conv2(ptch,k45,'same');
r90 = conv2(ptch,k90,'same');
b = (r0-r90)./(2*r45);
go2 = atand(b+sqrt(b.^2+1));
go2b = atand(b-sqrt(b.^2+1));
gm2 = r0.*cosd(go2).^2. + r90.*sind(go2).^2. - 2*sind(go2).*cosd(go2).*r45;
gm2b = r0.*cosd(go2b).^2. + r90.*sind(go2b).^2. - 2*sind(go2b).*cosd(go2b).*r45;
sgngm = sign(abs(gm2)-abs(gm2b));
mapg2 = max(sgngm,0); mapg2b = max(-sgngm,0);
go2 = mapg2.*go2 + mapg2b.*go2b;
gm2 = r0.*cosd(go2).^2. + r90.*sind(go2).^2. - 2*sind(go2).*cosd(go2).*r45;
%
% gm2out = gm2(dsz:sz-dsz-1,dsz:sz-dsz-1);
gm2out = abs(gm2(dsz:sz-dsz+1,dsz:sz-dsz+1));
go2out = go2(dsz:sz-dsz+1,dsz:sz-dsz+1);
end
