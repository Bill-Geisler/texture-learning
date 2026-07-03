function [nb,bb] = mk_bb(cstat,lev,filter)
%
% cstat = type of training images for each feature (e.g., 2,3,4)
% if cstat(i) = 0 then do not load feature bounds
%
% lev = resolution scale-down level (1,2,4,8)
%
% nb = number of bin bounds for each features
% bb = bin bounds for for each features
% 
mxbins = 100;
[~,ndim] = size(cstat); bb = zeros(ndim,mxbins); nb = zeros(1,ndim);
for i = 1:ndim
  if cstat(i) > 0
    num1 = num2str(cstat(i));  
    num2 = num2str(i);  
    num3 = num2str(lev);
    if filter == 0
      name = append('AHE',num1,num2,num3,'.mat');
    elseif filter == 1
      name = append('AHEO',num1,num2,num3,'.mat');
    end
    load(name,"bnds","nbnds");
    nb(i) = nbnds;
    bb(i,1:nbnds) = bnds; 
  end
end  
%
end