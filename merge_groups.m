function [grpout,ngrps] = merge_groups(groups,ngrps,gcnt,groups2d,szp,phiall,mc)
%
% for each group find groups that touch it
tchgrp = zeros(ngrps,ngrps); meansim = zeros(ngrps,ngrps);
for k = 1:ngrps
  for i = 1:szp
    for j = 1:szp
      if groups2d(i,j) == k
        if j < szp  
          if groups2d(i,j+1) ~= k
            tchgrp(k,groups2d(i,j+1)) = 1;
          end
        end
        if j > 1  
          if groups2d(i,j-1) ~= k
            tchgrp(k,groups2d(i,j-1)) = 1;
          end
        end
        if i < szp 
          if groups2d(i+1,j) ~= k
            tchgrp(k,groups2d(i+1,j)) = 1;
          end
        end        
        if i > 1 
          if groups2d(i-1,j) ~= k
            tchgrp(k,groups2d(i-1,j)) = 1;
          end
        end        
      end
    end
  end
end
% tchgrp = ones(ngrps,ngrps);
for k = 1:ngrps
  for l = k+1:ngrps
    if tchgrp(k,l) == 1
      cnt = 0;
      for i = 1:gcnt(k)
         for j = 1:gcnt(l)
           p1 = groups(k,i);
           p2 = groups(l,j);
           if p1 > 0 && p2 > 0
             cnt = cnt + 1;
             meansim(k,l) = meansim(k,l) + phiall(p1,p2);
           end
         end
      end
      meansim(k,l) = meansim(k,l)/cnt;
    end
  end
end
%
% find largest mean similarity
mxsim = -inf;
for k = 1:ngrps
  for l = k+1:ngrps
    if meansim(k,l) > mxsim
      kmx = k;
      lmx = l;
      mxsim = meansim(k,l);
    end
  end
end
if mxsim > mc
  groups(kmx,gcnt(kmx)+1:gcnt(kmx)+gcnt(lmx)) = groups(lmx,1:gcnt(lmx));
  groups(lmx,1:gcnt(lmx)) = 0;
  groups(kmx,:) = sort(groups(kmx,:),'descend');
  for k = lmx+1:ngrps
    groups(k-1,:) = groups(k,:);
  end
  groups(ngrps,:) = 0;
  ngrps = ngrps-1;
end
grpout = groups;
%
end
