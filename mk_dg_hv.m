function [khz,kvt] = mk_dg_hv(sd,nsd)
%
% make horizontal and vertical derivative of 2D Gaussian kernels
% and uniform kernel
%
% sd = standard deviation in pixels
% nsd = size in number of standard deviations (3 ~= Sobel)
%
sz = nsd*sd; xy0 = (sz+1)/2;
vr = sd^2;
khz = zeros(sz,sz); kvt = khz; 
for x = 1:sz
  for y = 1:sz
     khz(x,y) = -((x-xy0)/vr)*exp(-0.5*((x-xy0)^2 + (y-xy0)^2)/vr);
     kvt(x,y) = -((y-xy0)/vr)*exp(-0.5*((x-xy0)^2 + (y-xy0)^2)/vr);
  end
end
khz = khz/sqrt(sum(sum(khz.^2))); % nomalize to an energy of 1.0
kvt = kvt/sqrt(sum(sum(kvt.^2))); % nomalize to an energy of 1.0
%
end