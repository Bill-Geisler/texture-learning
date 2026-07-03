function plotbnds(bnds,nbnds,nfirst,nlast,del)
%
% plot histogram bin bounds
%
% bnds = vector of bin bounds
% nbnds = number of bin bounds
% nfirst = first bound to show in the plots
% nlast = last bound to show in the plots
% del = extra axis width
%
% close all;
figure;
plot(bnds(1:nbnds),ones(nbnds,1),"k-o","markerfacecolor",'k');
xlim([bnds(nfirst)-del bnds(nlast)+del]);
set(gca,'YTick', [])
xlabel('Bin Bounds');
%
figure;
stem(bnds(1:nbnds),ones(nbnds,1),"k-o","markerfacecolor",'k');
xlim([bnds(nfirst)-del bnds(nlast)+del]); ylim([0 2]);
set(gca,'YTick', [])
xlabel('Bin Bounds');
%
figure;
bcen = zeros(nbnds-1,1);
bwid = zeros(nbnds-1,1);
for i = 1:nbnds-1
  bcen(i) = (bnds(i) + bnds(i+1))/2; % bin centers
  bwid(i) = bnds(i+1) - bnds(i);     % bin widths
end
plot(bcen(1:nbnds-1),bwid(1:nbnds-1),"k-o","markerfacecolor",'k')
xlim([bnds(nfirst)-del bnds(nlast)+del]);
xlabel('Bin Centers'); ylabel('Bin Width');
end