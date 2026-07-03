function nreg = reg_count(maps,ngrps0,groups2d,ngrps,szp)
%
% count number of correct regions
%
% maps = ground truth regions
% groups2d = estimated regions
%
maps0 = zeros(ngrps0,szp,szp); grps0 = zeros(ngrps,szp,szp);
for k = 1:ngrps0
  test = zeros(szp,szp);
  for i = 1:szp
    for j = 1:szp
      if maps(i,j) == k
        maps0(k,i,j) = 1;
        test(i,j) = 1;
      end
    end
  end
end
%
for k = 1:ngrps
  test = zeros(szp,szp);
  for i = 1:szp
    for j = 1:szp
      if groups2d(i,j) == k
        grps0(k,i,j) = 1;
        test(i,j) = 1;
      end
    end
  end
end
%
nreg = 0;
for k = 1:ngrps0
  for l = 1:ngrps
    diff = abs(maps0(k,:,:) - grps0(l,:,:));
    if sum(sum(diff)) == 0
       nreg = nreg + 1;
    end
  end
end
%
end