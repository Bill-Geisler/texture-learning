 %
% nat_near_far_patches.m
%
% create near and far patch pairs from natural images
%
%
clearvars; close all;
%
addpath(['C:\Users\Bill Geisler\Documents\Projects\Texture\Images' ...
    '\CPS Set-9-10-12_16-bit linear']);
%
rng(0); % random number generator seed
% rng('shuffle');
%
% normalization parameters
cnorm = 1;
m0 = 128; c0 = 0.25; ntype = 3;
%
% optical filter
filter = 1;  % 1 = apply optical filter, 0 = no filter*********************
pd = 4;      % pupil diameter
w = 550;     % wavelength
%
%
sz1 = 64;
psz1 = 64;       % level 1 patch size
lev = 2;         % resolution scale-down level (1,2,4,8) ******************
sz = sz1/lev;    % image size given level
psz = psz1/lev;  % patch size given level
psz2 = 2*psz;
ppd = 60;        % pixels per degree
lms = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
ncolr = 3;       % number of color channels
%
% load color and edge histograms
if filter == 0
  load("cdfs_abr_mo13_mo23_cs33.mat"); % natural image cdfs
elseif filter == 1
  load("cdfs_abr_mo13_mo23_cs33_otf.mat"); % natural image cdfs
end
%
% number and size of natural images
nimg9 = 104; nimg10 = 90; nimg12 = 197;
showimg = 0;
mxval = 2^14-1; % maximum pixel value
%
% number of patch pairs and storage
nsmp = 10; % number of reference patches per image
nptch = (nimg9+nimg10+nimg12)*nsmp*2;
ptchn = zeros(psz,psz2,ncolr,nptch); ptchf = zeros(psz,psz2,ncolr,nptch);
pcnt = 0;
%
% image set 9
for inum = 1:nimg9
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set9_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);  % apply otf
  end   
  imglms = rgb2lms(imgrgb,lms);
  imglms = dsmp(imglms,lev,ncolr);  % downsample
  [szx,szy] = size(imglms(:,:,1)); dcrit = szx/4;
%  
% get samples from current image
  for k = 1:nsmp
    x = randi(szx-psz2); y = randi(szy-psz2);
    ptchr = imglms(x:x+psz-1,y:y+psz-1,:); % reference patch
% near patch right
    pcnt = pcnt+1;    
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchr;   % first patch
    ptch = imglms(x:x+psz-1,y+psz:y+psz2-1,:); % second patch 
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch; 
% far patch right
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchr;       % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% transpose reference patch    
    ptchrt = ptchr;
    ptchrt(:,:,1) = ptchrt(:,:,1).';
    ptchrt(:,:,2) = ptchrt(:,:,2).';
    ptchrt(:,:,3) = ptchrt(:,:,3).';    
% near patch down
    pcnt = pcnt + 1;
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(x+psz:x+psz2-1,y:y+psz-1,:);     % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';    
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% far patch down
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';        
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;        
  end
end
ptchn9 = ptchn(1:psz,1:psz2,1:ncolr,1:pcnt);
ptchf9 = ptchf(1:psz,1:psz2,1:ncolr,1:pcnt);
pcnt9 = pcnt;
num = num2str(lev);
name = append('patch_pairs_9',num,'.mat');
save(name,"ptchn9","ptchf9","pcnt9");
%
% image set 10
for inum = 1:nimg10
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set10_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);  % apply otf
  end   
  imglms = rgb2lms(imgrgb,lms);
  imglms = dsmp(imglms,lev,ncolr);  % downsample
%  
% get samples from current image
  for k = 1:nsmp
    x = randi(szx-psz2); y = randi(szy-psz2);
    ptchr = imglms(x:x+psz-1,y:y+psz-1,:); % reference patch
% near patch right
    pcnt = pcnt+1;    
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchr;   % first patch
    ptch = imglms(x:x+psz-1,y+psz:y+psz2-1,:); % second patch 
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch; 
% far patch right
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchr;       % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% transpose reference patch    
    ptchrt = ptchr;
    ptchrt(:,:,1) = ptchrt(:,:,1).';
    ptchrt(:,:,2) = ptchrt(:,:,2).';
    ptchrt(:,:,3) = ptchrt(:,:,3).';    
% near patch down
    pcnt = pcnt + 1;
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(x+psz:x+psz2-1,y:y+psz-1,:);     % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';    
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% far patch down
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';        
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;        
  end
end
ptchn10 = ptchn(1:psz,1:psz2,1:ncolr,pcnt9+1:pcnt);
ptchf10 = ptchf(1:psz,1:psz2,1:ncolr,pcnt9+1:pcnt);
pcnt10 = pcnt-pcnt9;
num = num2str(lev);
name = append('patch_pairs_10',num,'.mat');
save(name,"ptchn10","ptchf10","pcnt10");
%
% image set 12
for inum = 1:nimg12
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set12_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);  % apply otf
  end   
  imglms = rgb2lms(imgrgb,lms);
  imglms = dsmp(imglms,lev,ncolr);  % downsample  
%  
% get samples from current image
  for k = 1:nsmp
    x = randi(szx-psz2); y = randi(szy-psz2);
    ptchr = imglms(x:x+psz-1,y:y+psz-1,:); % reference patch
% near patch right
    pcnt = pcnt+1;    
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchr;   % first patch
    ptch = imglms(x:x+psz-1,y+psz:y+psz2-1,:); % second patch 
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch; 
% far patch right
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchr;       % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% transpose reference patch    
    ptchrt = ptchr;
    ptchrt(:,:,1) = ptchrt(:,:,1).';
    ptchrt(:,:,2) = ptchrt(:,:,2).';
    ptchrt(:,:,3) = ptchrt(:,:,3).';    
% near patch down
    pcnt = pcnt + 1;
    ptchn(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(x+psz:x+psz2-1,y:y+psz-1,:);     % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';    
    ptchn(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;
% far patch down
    dflg = 0;
    while dflg == 0
       xf = randi(szx-psz2); yf = randi(szy-psz2);
       dnf = sqrt((xf-x)^2 + (yf-y)^2);
       if dnf > dcrit
         dflg = 1;
       end
    end
    ptchf(1:psz,1:psz,1:ncolr,pcnt) = ptchrt;      % first patch
    ptch = imglms(xf:xf+psz-1,yf+psz:yf+psz2-1,:); % second patch
    ptch(:,:,1) = ptch(:,:,1).';
    ptch(:,:,2) = ptch(:,:,2).';
    ptch(:,:,3) = ptch(:,:,3).';        
    ptchf(1:psz,psz+1:psz2,1:ncolr,pcnt) = ptch;        
  end
end
ptchn12 = ptchn(1:psz,1:psz2,1:ncolr,pcnt10+1:pcnt);
ptchf12 = ptchf(1:psz,1:psz2,1:ncolr,pcnt10+1:pcnt);
pcnt12 = pcnt-pcnt10;
num = num2str(lev);
name = append('patch_pairs_12',num,'.mat');
save(name,"ptchn12","ptchf12","pcnt12");
