function [groups,ngrps,groups2d] = mk_groups(mu,dst,szp,gc,cc,dmin,x,y,phiall,mc)
% mk_groups
%
% uses local similarity, transitivity, isolation, and region similarity
% to form groups of texture patches
%
% mu = similarity measure matrix
% dst = distance matrix
% szp = size width in patches
% gc = grouping criterion
% cc = confidence criterion
% dmin = neighboring patch distance
% x,y = spatial coordinates for any given patch index
% phiall = content similarity of all patch pairs
%
% routines called
%   iso_patch.m
%   merge_groups.m
%
sz = szp^2;
%
% find weak same and weak different neighboring pairs
% link groups that exceed same-different and confidence criteria
groupsws = zeros(sz,2); groupswd = zeros(sz,2);
nodes = 0; nws = 0; nwd = 0;
groups = zeros(sz,2*sz);
groups2 = zeros(sz,sz);
nodelist = zeros(2*sz,2);
dmincnt = 0;
for i = 1:sz
  for j = i+1:sz
    if dst(i,j) == dmin
      dmincnt = dmincnt + 1;
      if mu(i,j) > gc % above same-different criterion
        if abs(mu(i,j)-gc) > cc % check if confidence is above criterion
          groups2(i,j) = 1;
          groups2(j,i) = 1;
        else                    % if not then save weak-link locations
          nws = nws + 1;
          groupsws(nws,1) = i;
          groupsws(nws,2) = j;
        end
      end
      if mu(i,j) < gc % below same-different criterion
        if abs(mu(i,j)-gc) > cc % check if confidence is above criterion
        else                    % if not then save weak-link locations
          nwd = nwd + 1;
          groupswd(nwd,1) = i;
          groupswd(nwd,2) = j;
        end
      end
    end
  end
end
ngrps = 0;
for i = 1:nodes  % if low confidence pairs make them group 1 and set to 0
  groups2(nodelist(i,2),:) = 0;
  groups2(:,nodelist(i,2)) = 0;
  ngrps = 1;
end
%
% use transitive grouping to create initial groups
gflg = 0;
while gflg == 0
  nodelist = zeros(2*sz,2);
  k = 0;  % node list pointer
  % find first node
  i = 1; nodecnt = 1;
  while max(groups2(i,:)) == 0 && gflg == 0
    i = i + 1;
    if i == sz
      gflg = 1;
    end
  end
  if gflg == 0
    nodelist(1,1) = i;
    nodelist(1,2) = i;
    k = 1;
  end
  while i > 0
    jcnt = 0;
    for j = 1:sz
      jflg = 0;
      for n = 1:k
        if nodelist(n,2) == j
          jflg = 1;
        end    
      end
      if (groups2(i,j) == 1) && (jflg == 0)
        k = k + 1;
        jcnt = jcnt + 1;
        nodelist(k,1) = i; nodelist(k,2) = j;
      end
    end
    nodecnt = nodecnt + 1;
    i = nodelist(nodecnt,2);
  end
  if gflg == 0
    ngrps = ngrps + 1;
    groups(ngrps,:) = sort(nodelist(:,2),'descend');
    for i = 1:nodecnt-1
      groups2(nodelist(i,2),:) = 0;
      groups2(:,nodelist(i,2)) = 0;   
    end
  end
end
%
% make 2D map of groups
groups2d = zeros(szp,szp); gcnt = zeros(sz,1);
for n = 1:ngrps
  i = 1;
  while groups(n,i) > 0
    x0 = x(groups(n,i)); y0 = y(groups(n,i));
    groups2d(x0,y0) = n;
    i = i+1;
  end
  gcnt(n) = i;
end
%
% collect unlinked locations
zloc = zeros(sz,2); zcnt = 0;
for i = 1:szp
  for j = 1:szp
    if groups2d(i,j) == 0
      zcnt = zcnt + 1;
      zloc(zcnt,1) = i; zloc(zcnt,2) = j;
    end
  end
end
%
% isolated-patch processing
[groups,groups2d] = iso_patch(groups,groups2d,ngrps,sz,szp,x,y,phiall);
for k = 1:zcnt
  gn = groups2d(zloc(k,1),zloc(k,2));
  loc = (zloc(k,1)-1)*szp + zloc(k,2);
  if gn <= ngrps
    groups(gn,gcnt(gn)) = loc;
    gcnt(gn) = gcnt(gn) + 1;
  else
    gcnt(gn) = gcnt(gn) + 1;
    groups(gn,1) = loc;
    ngrps = ngrps + 1;
  end
end
% %
% % weak-patch-link processing
% %
% % identify weak links to patches in different groups
% grpsw = zeros(sz,4);
% nwdg = 0;
% for k = 1:nws
%   i0 = groupsws(k,1);
%   j0 = groupsws(k,2);
%   for n = 1:ngrps
%     for j = 1:gcnt(n)
%       if groups(n,j) == i0
%         gi0 = n;
%       end
%       if groups(n,j) == j0
%         gj0 = n;
%       end
%     end
%   end
%   if gi0 ~= gj0
%     nwdg = nwdg + 1;
%     grpsw(nwdg,1) = i0; grpsw(nwdg,2) = j0;
%     grpsw(nwdg,3) = gi0; grpsw(nwdg,4) = gj0;   
%   end
% end
% for k = 1:nwd
%   i0 = groupswd(k,1);
%   j0 = groupswd(k,2);
%   for n = 1:ngrps
%     for j = 1:gcnt(n)
%       if groups(n,j) == i0
%         gi0 = n;
%       end
%       if groups(n,j) == j0
%         gj0 = n;
%       end
%     end
%   end
%   if gi0 ~= gj0
%     nwdg = nwdg + 1;
%     grpsw(nwdg,1) = i0; grpsw(nwdg,2) = j0;
%     grpsw(nwdg,3) = gi0; grpsw(nwdg,4) = gj0;
%   end
% end
%
% use content-similarity to determine whether the weak-link groups should
% be merged
% groups = weak_patch(groups,grpsw,gcnt,nwdg,phiall);
%
% make 2D map of groups
% groups2d = zeros(szp,szp); gcnt = zeros(sz,1);
% for n = 1:ngrps
%   i = 1;
%   while groups(n,i) > 0
%     x0 = x(groups(n,i)); y0 = y(groups(n,i));
%     groups2d(x0,y0) = n;
%     i = i+1;
%   end
%   gcnt(n) = i;
% end
%
% figure; image(groups2d,'CDataMapping','scaled'); axis image; axis off;
%
[groups,ngrps] = merge_groups(groups,ngrps,gcnt,groups2d,szp,phiall,mc);
%
% make 2D map of groups
groups2d = zeros(szp,szp); gcnt = zeros(sz,1);
for n = 1:ngrps
  i = 1;
  while groups(n,i) > 0
    x0 = x(groups(n,i)); y0 = y(groups(n,i));
    groups2d(x0,y0) = n;
    i = i+1;
  end
  gcnt(n) = i;
end
% figure; image(groups2d,'CDataMapping','scaled'); axis image; axis off;
end