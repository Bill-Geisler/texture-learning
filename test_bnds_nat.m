function err = test_bnds_nat(dim,tbnds,ptchn,ptchf,pcnt,psz,seed,coeff)
%
% test performance of histogram bounds for a particular feature dimension
%
% possible dimension to test
%   *dim = 1 color a
%   dim = 2 color b
%   dim = 3 color r
%   dim = 4 edge count
%   *dim = 5 edge gradient magnitude 
%   dim = 6 edge gradient orientation
%   dim = 7 edge gradient product
%   dim = 8 bar count 
%   *dim = 9 bar response magnitude 
%   *dim = 10 bar response orientation
%   dim = 11 bar response product
%   dim = 12 center-surround ratio small
%   *dim = 13 center-surround linear small
%   *dim = 14 center-surround linear large
%
% tbnds = bounds to test
% err = output error rate from the performance test
%
rng(seed); % rng(0) rng('shuffle')
mxdim = 20;
%
m0 = 128;    % normalization mean
c0 = 0.25;   % normalization contrast
ntype = 3;
ncolr = 3;
cnorm = 1;
psz2 = 2*psz;
%
% Edge parameters
thresh = 0;             % gradient threshold
sdg = 1;                % derivative of gaussians sd in pixels
nsdg = 3;               % kernel width in gaussian sds (~= sobal)
sdg2 = 1;               % 2nd derivative of gaussians sd in pixels
nsdg2 = 3;              % kernel width in gaussian sds
%
hflg = 0; eflg = 0;
flist = zeros(1,mxdim); % feature indicator list 
% 
if dim > 3 && dim <= 11
  flist(dim) = 1;   % note that dimension must be greater than three
  eflg = 1;
end
%
% Color pixel and center-surround histogram parameters
if dim <= 3 || dim >11
  flist(dim) = 1;
  hflg = 1;
end
%
% trial storage (separate for same and different trials)
rd = zeros(pcnt,1);
rs = zeros(pcnt,1);
vrd = zeros(pcnt,1);
vrs = zeros(pcnt,1);
%
nb = zeros(1,mxdim);
[~,nb(dim)] = size(tbnds); % number of bounds in current bound list
bb = zeros(mxdim,nb(dim));
bb(dim,1:nb(dim)) = tbnds;  
%
% far trials
nd = 1; i0d = 0;
for i = 1:pcnt 
  ptch1 = ptchf(1:psz,1:psz,1:ncolr,i);
  [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means     
  ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
  ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge,spot
  %  
  ptch2 = ptchf(1:psz,psz+1:psz2,1:ncolr,i);  
  [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means     
  ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates 
  ptch2a = ptch2(:,:,1); % grayscale patches for border,power,edge,spot
%
% compute responses
  if hflg == 1
    Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
    rd(i) = log(Rhout(dim));
  elseif eflg == 1
    if cnorm == 1     % contrast normalization
       ptch1a = cntrst_norm(ptch1a,c0,psz);
       ptch2a = cntrst_norm(ptch2a,c0,psz);
    end          
    Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist); 
    rd(i) = log(Reout(dim));    
  end
  vrd(nd,1) = rd(i); 
  if vrd(nd,1) >= -25          
    nd = nd+1;
  else
    i0d = i0d+1;  
  end
end
%
% near trials
ns = 1; i0s = 0;
for i = 1:pcnt 
  ptch1 = ptchn(1:psz,1:psz,1:ncolr,i);
  [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means     
  ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
  ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge,spot
  %  
  ptch2 = ptchn(1:psz,psz+1:psz2,1:ncolr,i);  
  [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means     
  ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates 
  ptch2a = ptch2(:,:,1); % grayscale patches for border,power,edge,spot
%
% compute responses
  if hflg == 1
    Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
    rs(i) = log(Rhout(dim));
  elseif eflg == 1
    if cnorm == 1     % contrast normalization
       ptch1a = cntrst_norm(ptch1a,c0,psz);
       ptch2a = cntrst_norm(ptch2a,c0,psz);
    end          
    Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist); 
    rs(i) = log(Reout(dim));    
  end
  vrs(ns,1) = rs(i); 
  if vrs(ns,1) >= -25          
    ns = ns+1;
  else
    i0s = i0s+1;  
  end
end
nd = nd-1; ns = ns-1;
%
% texture discrimination performance
results_p =  classify_normals(vrs(1:ns),vrd(1:nd),'input_type','samp','plotmode',0);
err = results_p.samp_opt_err;
end





