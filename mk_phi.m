function phi = mk_phi(pimg,szp,psz,cstat,flist,filter,x,y,coeff,...
    dvhfun,dvefun,dvcfun)
%
% Compute all pairwise similarities using content only
%
% pimg = input texture-region image
% szp = width of image in patches
% psz = patch width in pixels
% cstat = type of bounds for each feature
% flist = indicator list of features computed
% filter = OTF flag
% x,y = mapping from patch number to x,y coordinates
% coeff = abr rotation matrix
% dvhfun = histogram decision variable function
% dvcfun = content decision varible function
%
sz2 = szp^2; % phi width in patches
%
ntype = 3;   % type of normalization in patch_norm ************************
cnorm = 1;   % contrast normalization 1 = yes *****************************
m0 = 128;    % normalization mean
c0 = 0.25;   % normalization contrast
ncolr = 3;
lev = 1;
%
% power spectrum
b0 = 10;                 % weak Fourier power suppression parameter
%
[nb,bb] = mk_bb(cstat,lev,filter); % bin bounds
ne = [5,7,9,10]; % edge features to use************************************
nh = [1,13,14];  % spot features to use************************************
% 
% edge parameters
thresh = 50;            % gradient threshold
sdg = 1;                % derivative of gaussians sd in pixels
nsdg = 3;               % kernel width in gaussian sds (~= sobal)
sdg2 = 1;               % 2nd derivative of gaussians sd in pixels
nsdg2 = 3;              % kernel width in gaussian sds
%
% compute neighboring pairwise feature responses
phi = zeros(sz2,sz2);
for i = 1:sz2
  for j = i+1:sz2
    x1 = (x(i)-1)*psz + 1; y1 = (y(i)-1)*psz + 1;
    x2 = (x(j)-1)*psz + 1; y2 = (y(j)-1)*psz + 1;
    ptch1 = pimg(x1:x1+psz-1,y1:y1+psz-1,:);
    [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means
    ptch1 = rot(ptch1,coeff,psz); % apply rotation to PCA coordinates 
    ptch2 = pimg(x2:x2+psz-1,y2:y2+psz-1,:);
    [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch
    ptch2 = rot(ptch2,coeff,psz); % apply rotation to PCA coordinates
  %
  % compute responses
    ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge
    ptch2a = ptch2(:,:,1); 
  % power
    Rpout = Rp(ptch1a,ptch2a,b0,psz);
    rp = log(Rpout);
  % color      
    Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
    rh = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2))),log(Rhout(nh(3)))]'); 
  % edge      
    if cnorm == 1 
      ptch1a = cntrst_norm(ptch1a,c0,psz);
      ptch2a = cntrst_norm(ptch2a,c0,psz);
    end          
    Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
    re = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),log(Reout(ne(4)))]');
  % content
    Rcout = [rp,rh,re];
    rc = dvcfun(Rcout');
  % 
    phi(i,j) = rc;
    phi(j,i) = phi(i,j);
  end  
end
%
end