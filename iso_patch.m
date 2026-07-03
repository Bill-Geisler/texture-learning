function [groups,groups2d,ngrps] = iso_patch(groups,groups2d,ngrps,sz,szp,x,y,phiall)
%
% make list of isolated patches and neighboring groups
%
grps0 = zeros(sz,6); % list of isolated patches and neighboring groups
n = 0;
for i = 1:szp
  for j = 1:szp
    if groups2d(i,j) == 0
      n = n + 1; 
      grps0(n,1) = i; grps0(n,2) = j;
      if i == 1 
        grps0(n,3) = 0;
      else
        grps0(n,3) = groups2d(i-1,j);
      end
      if j == 1
        grps0(n,4) = 0;
      else
        grps0(n,4) = groups2d(i,j-1);       
      end
      if i == szp 
        grps0(n,5) = 0;
      else
        grps0(n,5) = groups2d(i+1,j);
      end
      if j == szp
        grps0(n,6) = 0;
      else
        grps0(n,6) = groups2d(i,j+1);       
      end     
    end
  end
end
%
% assign isolated patch to best neighboring matching group,
% if the content similarity is greater than zero
for ptch0 = 1:n
  mxsim = -100;
  i = grps0(ptch0,1); j = grps0(ptch0,2);
  i0 = (i-1)*szp + j;
  for k = 3:6
    gnum = grps0(ptch0,k);
    if gnum ~= 0
      for i = 1:szp
        for j = 1:szp
          if groups2d(i,j) == gnum && i~=j
            i1 = (i-1)*szp + j;
            sim = phiall(i0,i1);
            if sim > mxsim
              mxsim = sim;
              % imx = i; jmx = j;
              gmx = gnum;
            end
          end
        end
      end
    end
  end
  if mxsim > 0
    groups2d(x(i0),y(i0)) = gmx;
  else
    ngrps = ngrps + 1;
    groups2d(x(i0),y(i0)) = ngrps;
    groups(ngrps,1) = ngrps;
  end
end
%
end