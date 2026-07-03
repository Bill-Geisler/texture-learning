function otf = otf(u,d,w)
  % Waton's descriptive OTF
  % u = frequency c/deg
  % d = diameter mm
  % w = wavelength nm
  u0 = d*pi()*10^6/(w*180);
  uh = u/u0;
  D = (acos(uh) - uh.*sqrt(1-uh.^2))*2/pi();
  u1 = 21.95 - 5.512*d + 0.3922*d^2;
  otf = sqrt(D).*(1 + (u/u1).^2).^-0.62;
end

