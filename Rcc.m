function [Rccout,I] = Rcc(ptch1,ptch2,crits)
% circular cross correlation
%
% ptch1 & ptch2 = two patches to be cross correlated
% crits = structuredness criterion (if low in structure return 0)
% if crits = 0 always return cc
%
bw = 8;  % bin width for estimating level of periodicity
%
% ptch1
ptch1 = ptch1 - mean(mean(ptch1));
ftim = fftshift(fft2(fftshift(ptch1)));      % fourier transform patch
p1 = sum(sum(abs(ftim).^2));
ftim1 = ftim/sqrt(p1);
if crits > 0
  ps1 = abs(ftim1).^2;    
  per1 = fstruc(ps1,bw);
else
  per1 = 1;
end
%
%   ptch2
ptch2 = ptch2 - mean(mean(ptch2));
ftim = fftshift(fft2(fftshift(ptch2)));       % fourier transform image
p2 = sum(sum(abs(ftim).^2));
ftim2 = ftim/sqrt(p2);
if crits > 0
  ps2 = abs(ftim2).^2;    
  per2 = fstruc(ps2,bw);
else
  per2 = 1;
end
%
% cross correlation
ptim = ftim1.*ftim2;
ccimg = ifftshift(ifft2(ifftshift(ptim)));   % inverse fourier transform
[rmax,I] = max(ccimg,[],'all');
%
% apply structuredness criterion
if (per1 > crits) || (per2 > crits)
  Rccout = rmax*10^4;
else
  Rccout = 0;
end
%
end

