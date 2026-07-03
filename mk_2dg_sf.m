function [k0,k45,k90] = mk_2dg_sf(sd,nsd)
%
% make horizontal and vertical derivative of 2D Gaussian kernels
%
% sd = standard deviation in pixels
% nsd = size in number of standard deviations
%
% k0 = normalized horizontal kernel
% k45 = normalized 45 deg kernel
% k90 = normalized vertical kernel
%
scl = 0.22;
sz = nsd*sd;
xy0 = (sz+1)/2;
vr = sd^2;
k0 = zeros(sz,sz); k45 = k0; k90 = k0;
for x = 1:sz
  for y = 1:sz
     x0 = x-xy0; y0 = y-xy0;
     g = exp(-0.5*(x0^2 + y0^2)/vr);
     k0(x,y) = -(x0^2/(4*vr) - 1/(2*vr))*g;
     k90(x,y) = -(y0^2/(4*vr) - 1/(2*vr))*g;
     k45(x,y) = -(x0*y0/(4*vr))*g;
   end
end
k0 = k0 - mean(mean(k0));
k0 = k0/sqrt(sum(sum(k0.^2))); % nomalize to an energy of 1.0
k90 = k90 - mean(mean(k90));
k90 = k90/sqrt(sum(sum(k90.^2))); % nomalize to an energy of 1.0
k45 = k45 - mean(mean(k45));
k45 = scl*k45/sqrt(sum(sum(k45.^2))); % nomalize to an energy of 1.0
end