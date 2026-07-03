function Rbout = Rb(ptch1,ptch2,psz,dir,sd,nsd,showflag)
%
% boundry: log likelihood ratio of boundry to no-boundary
% assuming normality
%
% ptch1, ptch2 = two patches being compared
% psz = patch width in pixels
% dir = direction of patch2 from ptch1: 1 = down x, 2 = right y
% sd = steerable gaussian kernel sd
% nsd = steerable gaussian kernel width in number of sds
% al = log likeihood ratio parameter
%
Rbout = zeros(1,3);
[khz,kvt] = mk_dg_hv(sd,nsd); % make derivative of gaussians kernels
%
psz2 = 2*psz;
if dir == 1
  ptch = zeros(psz2,psz);
  ptch(1:psz,1:psz) = ptch1;
  ptch(psz+1:psz2,1:psz) = ptch2;
elseif dir == 2
  ptch = zeros(psz,psz2);
  ptch(1:psz,1:psz) = ptch1;
  ptch(1:psz,psz+1:psz2) = ptch2;
  ptch = ptch';
end
sumgh = zeros(1,psz2); sumgv = zeros(1,psz2);
if showflag == 1
  close all;
  imagesc(ptch);
  axis([1 64 1 128],'equal');
  colormap('gray');
end
%
% filter combined patch with steerable filter kernels
gh = conv2(ptch,khz,'same');
gv = conv2(ptch,kvt,'same');
for i = 1:psz2
  for j = 1:psz
     sumgh(i) = sumgh(i) + abs(gh(i,j));
     sumgv(i) = sumgv(i) + abs(gv(i,j));       
  end
end
%
% border energy at possible border
Rbout(1) = log(sum(sumgh(psz:psz+1))/sum(sumgv(psz:psz+1)));
%
% average border energy away from possible border
av1 = mean(log(sumgh(1:psz-1)/sumgv(1:psz-1)));
av2 = mean(log(sumgh(psz+1:psz2)/sumgv(psz+1:psz2)));
Rbout(2) = (av1+av2)/2;   
%
% cross correlation
Rbout(3) = Rcc(ptch1,ptch2,0);
end

