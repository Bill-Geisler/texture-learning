function texs = mk_texs(ntex,ntexr,ntrl)
%
% make random list of texture numbers for each trial
%   ntex = number of texture sheets to choose from
%   ntexr = number of texture regions per image
%   ntrl = number of trials
%
texs = zeros(ntrl,ntexr);   % output array
%
% load a random-order array the covers the size of the output array
imx = (floor(ntexr*ntrl/ntex) + 1)*ntex; % size of random texture list
texlist = zeros(imx,1);     % texture list, which may be bigger that texs
for i = 1:ntex:imx
  rindx = randperm(ntex);   % randomize the order texture numbers
  for j = 1:ntex
    texlist(i+j-1) = rindx(j); % load randomly ordered numbers
  end
end
%
% load output array
for i = 1:ntrl
  for j = 1:ntexr
     texs(i,j) = texlist((i-1)*ntexr+j);
  end
end
%
end

