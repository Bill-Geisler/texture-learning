%
% Find optimal histogram bins for natural images given the a feature CDF
% using the proximity proxy for ground truth (near-far discrimination)
%
clearvars;
close all;
%
% routines called:
%   find_bnd.m
%   test_bnds_nat.m
%   plotbnds.m
%
% output notation
%
% initial letters:
% HE = simple histogram equalization, AHE = adaptive histogram equalization
% HE & AHE = no OTF
% HEO & AHEO = with OTF
%
% final three numbers ijk:
% i = set of training images
% j = feature dimensions
% k = level of downsampling (eccentricity)
%
%   *dim = 1 color a
%   dim = 2 color b
%   dim = 3 color r
%   dim = 4 edge cnt
%   *dim = 5 edge gradient magnitude 
%   *dim = 6 edge gradient orientation
%   *dim = 7 edge gradient product
%   dim = 8 bar cnt 
%   *dim = 9 bar response magnitude 
%   *dim = 10 bar response orientation
%   *dim = 11 bar response product
%   *dim = 12 center-surround ratio small
%   *dim = 13 center-surround linear small
%   *dim = 14 center-surround linear large
%
% load spot and edge cdfs
filter = 1; % OTF flag
if filter == 0
  load("cdfs_abr_mo13_mo23_cs33.mat");
elseif filter == 1
  load("cdfs_abr_mo13_mo23_cs33_otf.mat");
end
%
btype = 5; % bound type: natural images = 5, Brodatz & Fabric = 4
%
lev = 8; % resolution scale-down level (1,2,4,8) **************************
dim = 1; % ****************************************************************
%
if dim == 1
  e = ea; N = Na;
elseif dim == 2
  e = eb; N = Nb;
elseif dim == 3
  e = er; N = Nr;
%
elseif dim == 5
  e = em; N = Nm;
elseif dim == 6
  e = eo; N = No;
elseif dim == 7
  e = emo; N = Nmo;  % mag x orien
%  
elseif dim == 9
  e = em2; N = Nm2;
elseif dim == 10
  e = eo2; N = No2;
elseif dim == 11
  e = emo2; N = Nmo2;  % mag x orien
%
elseif dim == 12
  e = ecs1; N = Ncs1;  % center surround
elseif dim == 13
  e = ecs2; N = Ncs2;  % center surround
elseif dim == 14
  e = ecs4; N = Ncs4;  % center surround
end
%
% types of optimization
heflg = 0;          % flag for simple histogram equalization***************
nbinl = 10; nbinh = 10; dnbin = 1; % bin steps for he
aheflg = 1;         % flag for adaptive histogram equalization*************
seed = 0;           % random number generator seed*************************
saveflg = 0;        % save opt bnds flag***********************************
%
sz1 = 640;       % level 1 image size
psz1 = 64;       % level 1 patch size
sz = sz1/lev;    % image size given level
psz = psz1/lev;  % patch size given level
psz2 = 2*psz;
%
% load natural image patch pairs
num = num2str(lev);
name = append('patch_pairs_9',num,'.mat');
load(name);
name = append('patch_pairs_10',num,'.mat');
load(name);
name = append('patch_pairs_12',num,'.mat');
load(name);
pcnt = pcnt9+pcnt10+pcnt12;
ptchf = zeros(psz,psz2,3,pcnt); ptchn = zeros(psz,psz2,3,pcnt);
ptchf(:,:,:,1:pcnt9) = ptchf9; ptchf(:,:,:,pcnt9+1:pcnt9+pcnt10) = ptchf10;
ptchf(:,:,:,pcnt9+pcnt10+1:pcnt) = ptchf12;
ptchn(:,:,:,1:pcnt9) = ptchn9; ptchn(:,:,:,pcnt9+1:pcnt9+pcnt10) = ptchn10;
ptchn(:,:,:,pcnt9+pcnt10+1:pcnt) = ptchn12;
%
[~,ne] = size (N);
%
if aheflg == 1
  nbin = 2; mbin = nbin;
  [bnds,ibnds] = mk_bins(e,N,nbin);
  bnds(1) = e(1); bnds(nbin+1) = e(ne);
  nbmx = 100;
  bins = zeros(nbmx,1);
  err0 = 1.0; ecr = .002; %.001
  done = 0;
  derr = zeros(nbmx,1);
  tcnt = 0;
  while done == 0  
    nbin = mbin;
    di = 0;
    for i = 1:nbin
      if bins(i) == 0
        [tbnds,tibnds] = find_bnd(bnds,ibnds,mbin,i+di,e,N);
        err = test_bnds_nat(dim,tbnds,ptchn,ptchf,pcnt,psz,seed,coeff);
        tcnt = tcnt + 1;
        derr(tcnt) = (err0-err)/err0;
        if derr(tcnt) > ecr
          bnds = tbnds;
          ibnds = tibnds;
          err0 = err;
          mbin = mbin+1;
          di = di+1;
          for j = mbin:-1:i
            if bins(j) == 1
              bins(j) = 0; bins(j+1) = 1;
            end
          end
        else
          bins(i) = 1;
        end
      end
    end
    if nbin == mbin
      done = 1;
    end
  end
  nbnds = nbin+1;
  nfirst = 2; nlast = nbnds-1;
  del = 2;
  plotbnds(bnds,nbnds,nfirst,nlast,del);
  %
  % save bounds
  num1 = num2str(btype); num2 = num2str(dim); num3 = num2str(lev);
  if filter == 0
    name = append('AHE',num1,num2,num3,'.mat');
  elseif filter == 1
    name = append('AHEO',num1,num2,num3,'.mat');
  end    
  bnds = bnds';
  if saveflg == 1
    save(name,"bnds","nbnds");
  end
  %
end
%
% compute performance of efficient coding bins
if heflg == 1
  erropt = 1.0;
  for  nbin = nbinl:dnbin:nbinh
    tbnds = mk_bins(e,N,nbin);
    err = test_bnds_nat(dim,tbnds,ptchn,ptchf,pcnt,psz,seed,coeff);
    if err < erropt
       erropt = err;
       bnds = tbnds;
    end
  end
  [~,nbnds] = size(bnds);
  nfirst = 2; nlast = nbnds-1;
  del = 2;
  bnds(1) = e(1); bnds(nbnds) = e(ne);
  plotbnds(bnds,nbnds,nfirst,nlast,del);
  if saveflg == 1
    num1 = num2str(btype); num2 = num2str(dim); num3 = num2str(lev);
    if filter == 0
      name = append('HE',num1,num2,num3,'.mat');
    elseif filter == 1
      name = append('HEO',num1,num2,num3,'.mat');
    end 
    bnds = bnds';
    save(name,"bnds","nbnds");
  end
end












