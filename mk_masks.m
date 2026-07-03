function [masks,maps] = mk_masks(np,ntr,ntrl,seedr,pixp)
%
% make binary (logical) texture masks for all trials in a session
%   
% np = width in number of patches
% ntr = number of texture regions per image/mask
% nmsks = number of masks = ntr*ntrl
% seedr = fraction of maximum radius for texture seeds 
%
seedb = seedr*np/2;
masks = zeros(np,np,np*ntr); maps = zeros(np,np,ntrl);
for t = 1:ntrl
  map = zeros(np,np); % texture label map
tlst = zeros(ntr,round(3*np^2/ntr) + 1); % list of patches for each region
  %
  % seed the texture label map
  seeds = zeros(ntr,2);
  for i = 1:ntr
    sflg = 1;
    while sflg == 1
      sflg = 0;
      xyflg = 0;
      while xyflg == 0
        x = randi(np);
        y = randi(np);
        if sqrt((x-np/2)^2 + (y-np/2)^2)  < seedb
          xyflg = 1;
        end
      end
      for j = 1:ntr
        if seeds(j,1) == x && seeds(j,2) == y
          sflg = 1;
        end
      end
    end
    seeds(i,1) = x; seeds(i,2) = y;
    map(x,y) = i;  % write first patch label to map
    tlst(i,1) = 1; tlst(i,2) = x; tlst(i,3) = y; % save coorinates of first patch label
  end
  %
  % grow the texture regions
  % while min(min(map)) == 0 % fill the image (no background pixels)
  while sum(tlst(:,1)) < pixp*np^2 % some percentage of background pixels
    iprm = randperm(ntr); % add to regions in a random order on each pass
    for i = 1:ntr
      j = iprm(i);
      n = tlst(j,1);
      nprm = randperm(n); % check patches in region for a free side in random order 
      k = 1; chkflg = 0;
      while n == tlst(j,1) && k <= n
        x = tlst(j,2*nprm(k)); y = tlst(j,2*nprm(k)+1);
        dprm = randperm(4); % check four sides of patch in random order
        l = 0;
        while l < 4 && chkflg == 0
          l = l+1;
          [chkflg,xout,yout] = chktlst(dprm(l),x,y,map,np);
        end
        if chkflg == 1
          tlst(j,1) = tlst(j,1) + 1; % when 1 is added move on to next region
          tlst(j,2*(n+1)) = xout; tlst(j,2*(n+1)+1) = yout;
          map(xout,yout) = j;
        end
        k = k+1; % if k exceeds n then move on to next region
      end
    end
  end
  %
  % figure;
  % image(map*256/ntr-1);
  % axis off;
  % axis square;
  % axis equal;
  %
  % make masks and maps
  for i = 1:ntr
    for j = 1:np
      for k = 1:np
        if map(j,k) == i 
          masks(j,k,(t-1)*ntr+i) = 1;
        end
      end
    end
    % figure;
    % image(masks(:,:,1)*256/ntr-1);
    % axis off;
    % axis square;
    % axis equal;    
  end
  maps(:,:,t) = map;
%
% lmsks = cast(msks,'logical');
%  
end
%
end