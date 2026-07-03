function [egout,iout] = mk_bins(e,N,nbin)
%
% make bin edges from cdf
%
[~,ncdf] = size(e);
ne = 1;
eg = zeros(1,nbin+1); iout = zeros(1,nbin+1);
pstp = 1/nbin;
p = pstp;
for i = 1:ncdf-2
  if (N(i) < p) && (N(i+1) > p)
    ne = ne + 1;
    eg(ne) = e(i);
    iout(ne) = i+1;
    p = p + pstp;
    while N(i+1) > p
      p = p+pstp;
      nbin = nbin - 1;
    end 
  end
end
eg(nbin+1) = inf;
eg(1) = -inf; iout(1) = 1;
egout = eg(1:nbin+1);
iout(nbin+1) = ncdf-1;
%
end