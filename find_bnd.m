function [tbnds, tibnds] = find_bnd(bnds,ibnds,mbin,i,e,N)
%
% find bin bounds to test for same-different accuracy
% bnds = current bin bounds
% i = current bin
% e = cdf x-axis values
% N = cdf y-axis values
%
tbnds = zeros(1,mbin+2); tibnds = zeros(1,mbin+2);
lbnd = ibnds(i);
ubnd = ibnds(i+1);
if mbin == 1
  d = 2;
  N0 = N(lbnd) + (N(ubnd)-N(lbnd))/d;
else
  N0 = N(lbnd) + (N(ubnd)-N(lbnd))/2;    
end
done = 0;
j = 1;
while done == 0
  j = j+1;
  if N(j) <= N0 && N(j+1) >= N0
    done = 1;
  end
end
tbnds(1:i) = bnds(1:i);
tbnds(i+1) = e(j);
tbnds(i+2:mbin+2) = bnds(i+1:mbin+1);
%
tibnds(1:i) = ibnds(1:i);
tibnds(i+1) = j;
tibnds(i+2:mbin+2) = ibnds(i+1:mbin+1);
end