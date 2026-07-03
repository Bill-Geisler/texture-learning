% texture stimulus parameters
%
% (1) create a GTR image and the map
% (2) grab near and far patches
% (3) learn the optimal shift (offset) of the content decision bound
% (4) apply the decision bound to the all joined patches and compare with
%     ground truth
% (5) can turn off shift to get performance with pre-trained DVs and bounds
%
close all; clearvars;
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Brodatz')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Fabric')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Pertex')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Vistex')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Mcgill')
%
%   dim = 1 color a
%   dim = 2 color b
%   dim = 3 color r
%   dim = 4 edge cnt
%   dim = 5 edge gradient magnitude 
%   dim = 6 edge gradient orientation
%   dim = 7 edge gradient product
%   dim = 8 bar cnt 
%   dim = 9 bar response magnitude 
%   dim = 10 bar response orientation
%   dim = 11 bar response product
%   dim = 12 center-surround ratio small
%   dim = 13 center-surround linear small
%   dim = 14 center-surround linear large
%
rng(0);
% rng('shuffle')
%
itype = 1; %***************************************************************
%
% optical filter
filter = 1;  % 1 = apply optical filter, 0 = no filter*********************
pd = 8;      % pupil diameter
w = 550;     % wavelength
%
lev = 1;         % resolution scale-down level (1,2,4,8) ******************
%
sz1 = 640;       % level 1 image size
psz1 = 64;       % level 1 patch size
sz = sz1/lev;    % image size given level
psz = psz1/lev;  % patch size given level
ppd = 60;        % pixels per degree
lms = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
ncolr = 3;       % number of color channels
showflag = 0;    % showflag for Rb.m
pltbnd = 0;      % plot flag for QDA bound*********************************
plotflg = 0;     % plot flag GTR image*************************************
bordflg = 1;     % use border cues
shftflg = 1;     % use opt c shift
%
% load color and edge histograms
if filter == 0
  load("cdfs_abr_mo13_mo23_cs33.mat"); % natural image cdfs
elseif filter == 1
  load("cdfs_abr_mo13_mo23_cs33_otf.mat"); % natural image cdfs
end
%
% load images
if itype == 4
  nimg = 120; ntrl = 6;
  hnimg = nimg/2;
  % hntrl = ntrl/2;
  hntrl = ntrl;
else
  nimg = 60; ntrl = 20;
  hnimg = nimg;
  hntrl = ntrl;
end
cimg = double(zeros(sz1,sz1,3));
imgr = zeros(sz,sz,nimg);
imgg = zeros(sz,sz,nimg);
imgb = zeros(sz,sz,nimg);
for k = 1:nimg
  if itype == 1
    del = 30;
    num = num2str(k+del);
    name = append('P',num,'.mat');
    load(name);
    cimg(:,:,1) = dimg;
    cimg(:,:,2) = dimg;
    cimg(:,:,3) = dimg;
    if filter == 1
      cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
    end   
    cimg = rgb2lms(cimg,lms);     % convert to lms space
    dimg = dsmp(cimg,lev,ncolr);  % downsample
    imgr(:,:,k) = dimg(:,:,1);
    imgg(:,:,k) = dimg(:,:,2);
    imgb(:,:,k) = dimg(:,:,3);
  end
  if itype == 2
    num = num2str(k);
    name = append('FC',num,'.png');
    cimg = double(imread(name));
    cimg = adobe_expand(cimg);    
    if filter == 1
      cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
    end   
    cimg = rgb2lms(cimg,lms);     % convert to lms space
    dimg = dsmp(cimg,lev,ncolr);  % downsample    
    imgr(:,:,k) = dimg(:,:,1);
    imgg(:,:,k) = dimg(:,:,2);
    imgb(:,:,k) = dimg(:,:,3);
  end
  if itype == 3
    num = num2str(k);
    name = append('B',num,'.gif');
    cimg(:,:,1) = double(imread(name));
    cimg(:,:,2) = cimg(:,:,1);
    cimg(:,:,3) = cimg(:,:,1);
    if filter == 1
      cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
    end   
    cimg = rgb2lms(cimg,lms);     % convert to lms space
    dimg = dsmp(cimg,lev,ncolr);  % downsample
    imgr(:,:,k) = dimg(:,:,1);
    imgg(:,:,k) = dimg(:,:,2);
    imgb(:,:,k) = dimg(:,:,3);
  end
  if itype == 4
    if k <= hnimg
      num = num2str(k);        
      name = append('B',num,'.gif');
      cimg(:,:,1) = double(imread(name));
      cimg(:,:,2) = cimg(:,:,1);
      cimg(:,:,3) = cimg(:,:,1);
      if filter == 1
        cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
      end   
      cimg = rgb2lms(cimg,lms);     % convert to lms space
      dimg = dsmp(cimg,lev,ncolr);  % downsample
      imgr(:,:,k) = dimg(:,:,1);
      imgg(:,:,k) = dimg(:,:,2);
      imgb(:,:,k) = dimg(:,:,3);
    else
      num = num2str(k-hnimg);
      name = append('FC',num,'.png');
      cimg = double(imread(name));
      cimg = adobe_expand(cimg);    
      if filter == 1
        cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
      end   
      cimg = rgb2lms(cimg,lms);     % convert to lms space
      dimg = dsmp(cimg,lev,ncolr);  % downsample
      imgr(:,:,k) = dimg(:,:,1);
      imgg(:,:,k) = dimg(:,:,2);
      imgb(:,:,k) = dimg(:,:,3);
    end
  end
  if itype == 5  
    vindx = [1;3;5;9;10;14;18;19;36;39;42;43;46;48;50;52;53;56;58;60;...
    63;64;66;68;69;73;77;79;80;81;82;83;84;85;87;88;89;90;91;92;93;...
    95;97;98;100;103;104;105;120;124;127;128;129;130;143;144;153;...
    158;163;166];    
    num = num2str(vindx(k));
    name = append('VS',num,'.png');
    cimg = double(imread(name));
    cimg = adobe_expand(cimg);    
    if filter == 1
      cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
    end   
    cimg = rgb2lms(cimg,lms);     % convert to lms space
    dimg = dsmp(cimg,lev,ncolr);  % downsample    
    imgr(:,:,k) = dimg(:,:,1);
    imgg(:,:,k) = dimg(:,:,2);
    imgb(:,:,k) = dimg(:,:,3);
  end
  if itype == 6  
    mindx = [1;6;12;14;15;16;20;22;24;25;26;31;32;34;35;37;40;41;42;...
    43;44;45;46;48;49;52;53;55;57;58;61;62;63;64;66;68;69;73;74;75;...
    77;78;80;81;82;84;85;86;88;90;97;100;105;...
    107;110;111;114;117;120;125];
    num = num2str(mindx(k));
    name = append('M',num,'.png');
    cimg = double(imread(name));
    cimg = adobe_expand(cimg);    
    if filter == 1
      cimg = aply_otf(cimg,ppd,pd,w);  % apply otf
    end   
    cimg = rgb2lms(cimg,lms);     % convert to lms space
    dimg = dsmp(cimg,lev,ncolr);  % downsample    
    imgr(:,:,k) = dimg(:,:,1);
    imgg(:,:,k) = dimg(:,:,2);
    imgb(:,:,k) = dimg(:,:,3);
  end    
end
imk = zeros(sz,sz,3); imj = zeros(sz,sz,3);
nimgk = nimg; nimgj = nimg;
%
% norm: 0 = none 1 = mean, 2 = mean and contrast, 3 = average mean
ntype = 3;   % type of normalization in patch_norm ************************
cnorm = 1;   % contrast normalization 1 = yes *****************************
m0 = 128;    % normalization mean
c0 = 0.25;   % normalization contrast
%
% power spectrum
b0 = 16;                 % weak Fourier power suppression parameter 
% load bin bounds, 0=HE, 2=AHE-F, 3=AHE-B, 4=AHE-B&F
b = 5; % bin type: 4 = Brodatz & Fabric, 5 = natural image*****************
cstat = [b,0,0,0,b,b,b,0,b,b,b,0,b,b,0,0,0,0,0,0]; 
[nb,bb] = mk_bb(cstat,lev,filter);
flist = [1,0,0,0,1,1,1,0,1,1,1,0,1,1,0,0,0,0,0,0];
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
% load decision coeffs edge features
num = num2str(lev);
if filter == 0
  name = append('dbndeBF',num,'.mat');   % trained on separated
elseif filter == 1
  % name = append('dbndeBFO',num,'.mat');   % trained on separated
  name = append('dbndeNO',num,'.mat');   % trained on natural images 
end
load(name);
fun_level = 0;
dvefun=quad2fun(dbnde,fun_level); % decision-variable function from coeffs
%
% load decision coeffs h features
if filter == 0
  name = append('dbndhBF',num,'.mat');   % trained on separated
elseif filter == 1
  % name = append('dbndhBFO',num,'.mat');   % trained on separated
  name = append('dbndhNO',num,'.mat');   % trained on natural images  
end
load(name);
fun_level = 0;
dvhfun=quad2fun(dbndh,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for content features
if filter == 0
  name = append('dbndcBF',num,'.mat');   % trained on separated
elseif filter == 1
  % name = append('dbndcBFO',num,'.mat');   % trained on separated
  name = append('dbndcNO',num,'.mat');      % trained on natural images  
end
load(name);
fun_level = 0;
dvcfun=quad2fun(dbndc,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for border features
if filter == 0
  name = append('dbndbBF',num,'.mat');   % trained on joined
elseif filter == 1
  % name = append('dbndbBFO',num,'.mat');   % trained on joined
  name = append('dbndbNO',num,'.mat');   % trained on natural images  
end
load(name);
fun_level = 0;
dvbfun=quad2fun(dbndb,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for content and border features
if filter == 0
  name = append('dbndbcBF',num,'.mat');   % trained on joined and separated
elseif filter == 1
  % name = append('dbndbcBFO',num,'.mat');   % trained on joined and separated
  name = append('dbndbcNO',num,'.mat'); % trained on natural images
end
load(name);
fun_level = 0;
dvbcfun=quad2fun(dbndbc,fun_level); % decision-variable function from coeffs
%
% count same and different for near and far patches************************
ntexr = 5;      % number of texture regions
szp = 10;       % image size in patches
seedr = 1.0;    % texture seed radius as fraction of max
pixp = 1.0;     % proportion of pixels taken up by texture regions
ntrl = 1;       % number of trials
sz2 = szp^2;
imw = psz*szp;
if imw ~= sz    % if imw not equal to sz then resize
  rszflg = 1;
else
  rszflg = 0;
end
%
%
iscl = 0.0;  % 0.1 illumination scalar offset
%
smcnt = 0; cnt = 0; dcnt = 0; dcrit = 7.0; %******************************* 
nmaps = 1000;
ncnt = 2*(szp-1)^2;
for k = 1:nmaps
  [~,maps] = mk_masks(szp,ntexr,ntrl,seedr,pixp);
  for i = 1:szp-1
    for j = 1:szp-1
%        
% neighboring patches
      cnt = cnt + 2;
      if maps(i,j+1) == maps(i,j)
        smcnt = smcnt + 1;
      end
      if maps(i+1,j) == maps(i,j)
        smcnt = smcnt + 1;
      end
%
% distant patches      
      dist = 0;
      while dist == 0
        x2 = randi(szp); y2 = randi(szp);
        d = sqrt((i-x2)^2 + (j-y2)^2);
        if d > dcrit
          dist = d;
          if maps(i,j) ~= maps(x2,y2)
            dcnt = dcnt + 1;
          end
        end
      end
%      
      dist = 0;
      while dist == 0
        x2 = randi(szp); y2 = randi(szp);
        d = sqrt((i-x2)^2 + (j-y2)^2);
        if d > dcrit
          dist = d;
          if maps(i,j) ~= maps(x2,y2)
            dcnt = dcnt + 1;
          end
        end
      end            
    end
  end
end
propsm = smcnt/cnt;
propdf = dcnt/cnt;
% 
% self-supervised training and testing*************************************
dmin = 64;      % minimum distance between patches in pixels
ntrl = 40; %***************************************************************
%
% generate random texture numbers for all trials in a session
texs = mk_texs(nimg,ntexr,ntrl); % texs(1:ntrl,1:ntexr)
%
% generate masks and maps for all trials in a session
[masks,maps] = mk_masks(szp,ntexr,ntrl,seedr,pixp);
%
% local similarity grouping criterion
gcmn = 0; dgc = 0.8; gcmx = 8; ngc = (gcmx-gcmn)/dgc + 1;
%
% mutual similarity weight
msmn = 0; dms = 0.8; msmx = 8; nms = (msmx-msmn)/dms + 1;
%
% storage
pc = zeros(ngc,nms,ntrl); pcs = zeros(ngc,nms,ntrl);
pcd = zeros(ngc,nms,ntrl); pcnf = zeros(ngc,nms,ntrl); tscnt = 0; tdcnt = 0;
pcav = zeros(ngc,nms); pcsav = zeros(ngc,nms); pcdav = zeros(ngc,nms);
pcnfav = zeros(ngc,nms); pcm = zeros(ngc,ntrl); pcnfm = zeros(ngc,ntrl);
pcmav = zeros(ngc,1); pcnfmav = zeros(ngc,1); pcmgav = 0;
nancnt = 0;
%
% trial loop***************************************************************
for trl = 1:ntrl
  close all;
  %  
  % make masks for a trial
  msks = zeros(imw,imw,ntexr);
  for i = 1:ntexr
    for j = 1:szp
      x = (j-1)*psz+1; 
      for k = 1:szp
        if maps(j,k,trl) == i
          y = (k-1)*psz+1; 
          msks(x:x+psz-1,y:y+psz-1,i) = 1;
        end
      end
    end
  end
  %
  % create map from patch number to x,y coordinates 
  x = zeros(sz2,1);
  y = zeros(sz2,1);
  k = 0;
  for i = 1:szp:sz2
    k = k+1;
    l = 0;
    for j = i:i+szp-1
      l = l+1;
      x(j) = k;
      y(j) = l;
    end
  end
  for i = 1:sz2
    mp1 = mod(i,szp);
    if mp1 == 0
      mp1 = szp;
    end 
    for j = 1:sz2
      mp2 = mod(j,szp);
      if mp2 == 0
        mp2 = szp;
      end 
    end
  end
  %
  % make GTR image
  pimg = zeros(imw,imw,3); limg = zeros(imw,imw,3);
  img = zeros(imw,imw,3);
  for i = 1:ntexr
    k = texs(trl,i);
    img(:,:,1) = imgr(:,:,k); img(:,:,2) = imgg(:,:,k);
    img(:,:,3) = imgb(:,:,k);
    %
    % apply mask and add to stimulus image
    pimg(:,:,1) = pimg(:,:,1) + img(:,:,1).*msks(:,:,i);
    pimg(:,:,2) = pimg(:,:,2) + img(:,:,2).*msks(:,:,i);
    pimg(:,:,3) = pimg(:,:,3) + img(:,:,3).*msks(:,:,i);
  end
  %
  % create combined mask
  msk = zeros(imw,imw);
  for i = 1:ntexr
    msk(:,:) = msk(:,:) + msks(:,:,i);
  end
  %
  % set region outside combined mask to mean
  for i = 1:imw
    if i < imw/2
      scl = 1-iscl;
    else
      scl = 1+iscl;
    end    
    for j = 1:imw
      if msk(i,j) == 0
        pimg(i,j,1) = m0;
        pimg(i,j,2) = m0;
        pimg(i,j,3) = m0;
      end
        pimg(i,j,1) = pimg(i,j,1)*scl;
        pimg(i,j,2) = pimg(i,j,2)*scl;
        pimg(i,j,3) = pimg(i,j,3)*scl;     
    end
  end
  %
  % patch luminance image
  for i = 1:psz:imw
    for j = 1:psz:imw
      limg(i:i+psz-1,j:j+psz-1,1) = mean(mean(pimg(i:i+psz-1,j:j+psz-1,1)));
      limg(i:i+psz-1,j:j+psz-1,2) = mean(mean(pimg(i:i+psz-1,j:j+psz-1,2)));
      limg(i:i+psz-1,j:j+psz-1,3) = mean(mean(pimg(i:i+psz-1,j:j+psz-1,3)));     
    end
  end
  %
  if plotflg == 1
    img(:,:,1) = pimg(:,:,1); % limg(:,:,1)
    img(:,:,2) = pimg(:,:,1); % limg(:,:,2)
    img(:,:,3) = pimg(:,:,1); % limg(:,:,3)    
    nexttile;
    % img = rescale(img);
    img = adobe_compress(img);
    img = rescale(img);
    % img = (img - 0.5)*0.5 + 0.5;
    % img = adobe_compress(img);
    image(img); axis image; axis off; %title([num2str(ntexr)]);
    title([num2str(ntexr)]);
  end
  %
  % compute
  % similarities***************************************************** 
  %
  % compute all content similarities
  phiall = mk_phi(pimg,szp,psz,cstat,flist,filter,x,y,coeff,...
      dvhfun,dvefun,dvcfun);
  %
  % compute mutual similarity
  rho = zeros(sz2,sz2);
  vi = zeros(sz2-2,1); vj = zeros(sz2-2,1);
  for i = 1:sz2
    for j = 1:sz2
      l = 0;
      for k = 1:sz2
        if (k ~= i) && (k ~= j)
          l = l+1;
          vi(l) = phiall(k,j);
        end
      end
      l = 0;
      for k = 1:sz2
        if (k ~= i) && (k ~= j)
          l = l+1;
          vj(l) = phiall(i,k);
        end
      end
      % rho(i,j) = corr(vi,vj); % correlation      
      rho(i,j) = sum(vi.*vj)/sqrt(sum(vi.^2)*sum(vj.^2)); % vector angle
    end
  end
  %
  % compute neighboring and distant pairwise feature responses
  rbf = zeros(1,ncnt); rcf = zeros(1,ncnt); rbcf = zeros(1,ncnt);
  rbn = zeros(1,ncnt); rcn = zeros(1,ncnt); rbcn = zeros(1,ncnt);
  rmf = zeros(1,ncnt); rmn = zeros(1,ncnt); 
  scnt = 0; dcnt = 0; same_near = zeros(1,ncnt); same_far = zeros(1,ncnt);
  for i = 1:szp-1
    for j = 1:szp-1
      %  
      % neighboring patches************************************************
      im = (i-1)*szp + j;
      x = (i-1)*psz+1; y = (j-1)*psz+1;
      ptch1 = pimg(x:x+psz-1,y:y+psz-1,:);
      [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means     
      ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
      ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge
    %
    % first pair direction down x
      dir = 1;
      x = i*psz+1; y = (j-1)*psz+1;
      ptch2 = pimg(x:x+psz-1,y:y+psz-1,:);
      [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means
      ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates
      ptch2a = ptch2(:,:,1);
      scnt = scnt +1;
      if maps(i,j,trl) == maps(i+1,j,trl)
        same_near(scnt) = 1; 
      end
      % power
      Rpout = Rp(ptch1a,ptch2a,b0,psz);
      rps = log(Rpout);
      % spot      
      Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
      rhs = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2))),...
          log(Rhout(nh(3)))]');  
      % edge      
      if cnorm == 1 
        ptch1a = cntrst_norm(ptch1a,c0,psz);
        ptch2a = cntrst_norm(ptch2a,c0,psz);
      end
      Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
      res = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),...
          log(Reout(ne(4)))]');
      % border
      Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
      rbn(scnt) = dvbfun(Rbout(1:2)');
      % content
      Rcout = [rps,rhs,res];
      rcn(scnt) = dvcfun(Rcout');
      % border & content
      rbcn(scnt) = dvbcfun([rcn(scnt),rbn(scnt)]');      
      % mutual similarity
      jm = i*szp + j;
      rmn(scnt) = rho(im,jm);      
    %      
    % second pair direction right y      
      dir = 2;
      x = (i-1)*psz+1; y = j*psz+1;
      ptch2 = pimg(x:x+psz-1,y:y+psz-1,:);
      [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means
      ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates
      ptch2a = ptch2(:,:,1);
      scnt = scnt +1;
      if maps(i,j,trl) == maps(i,j+1,trl)
        same_near(scnt) = 1; 
      end
      % power
      Rpout = Rp(ptch1a,ptch2a,b0,psz);
      rps = log(Rpout);
      % spot      
      Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
      rhs = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2))),...
          log(Rhout(nh(3)))]');  
      % edge      
      if cnorm == 1 
        ptch1a = cntrst_norm(ptch1a,c0,psz);
        ptch2a = cntrst_norm(ptch2a,c0,psz);
      end
      Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
      res = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),...
          log(Reout(ne(4)))]');
      % border
      Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
      rbn(scnt) = dvbfun(Rbout(1:2)');
      % content
      Rcout = [rps,rhs,res];
      rcn(scnt) = dvcfun(Rcout');
      % border & content
      rbcn(scnt) = dvbcfun([rcn(scnt),rbn(scnt)]');        
      % mutual similarity
      jm = (i-1)*szp + j+1;
      rmn(scnt) = rho(im,jm);          
      %
      % distant patches****************************************************
    %
    % first pair
      dist = 0;
      while dist == 0
        x2 = randi(szp); y2 = randi(szp);
        d = sqrt((i-x2)^2 + (j-y2)^2);
        if d > dcrit
          dist = d; % distance in patches
          x = (x2-1)*psz + 1; y = (y2-1)*psz + 1; 
        end
      end
      dcnt = dcnt + 1;
      if maps(i,j,trl) == maps(x2,y2,trl)
        same_far(dcnt) = 1; 
      end
      ptch2 = pimg(x:x+psz-1,y:y+psz-1,:);
      [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means
      ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates
      ptch2a = ptch2(:,:,1);    
      % power
      Rpout = Rp(ptch1a,ptch2a,b0,psz);
      rps = log(Rpout);
      % spot      
      Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
      rhs = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2))),...
          log(Rhout(nh(3)))]');  
      % edge      
      if cnorm == 1 
        ptch1a = cntrst_norm(ptch1a,c0,psz);
        ptch2a = cntrst_norm(ptch2a,c0,psz);
      end
      Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
      res = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),...
          log(Reout(ne(4)))]');
      % border
      Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
      rbf(dcnt) = dvbfun(Rbout(1:2)');
      % content
      Rcout = [rps,rhs,res];
      rcf(dcnt) = dvcfun(Rcout');
      % border & content
      rbcf(dcnt) = dvbcfun([rcf(dcnt),rbf(dcnt)]');
      % mutual similarity
      jm = (x2-1)*szp + y2; 
      rmf(dcnt) = rho(im,jm);         
    %
    % second pair
      dist = 0;
      while dist == 0
        x2 = randi(szp); y2 = randi(szp);
        d = sqrt((i-x2)^2 + (j-y2)^2);
        if d > dcrit
          dist = d; % distance in patches
          x = (x2-1)*psz + 1; y = (y2-1)*psz + 1; 
        end
      end
      dcnt = dcnt + 1;
      if maps(i,j,trl) == maps(x2,y2,trl)
        same_far(dcnt) = 1; 
      end
      ptch2 = pimg(x:x+psz-1,y:y+psz-1,:);
      [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means
      ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates
      ptch2a = ptch2(:,:,1);    
      % power
      Rpout = Rp(ptch1a,ptch2a,b0,psz);
      rps = log(Rpout);
      % spot      
      Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
      rhs = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2))),...
          log(Rhout(nh(3)))]');  
      % edge      
      if cnorm == 1 
        ptch1a = cntrst_norm(ptch1a,c0,psz);
        ptch2a = cntrst_norm(ptch2a,c0,psz);
      end
      Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
      res = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),...
          log(Reout(ne(4)))]');
      % border
      Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
      rbf(dcnt) = dvbfun(Rbout(1:2)');
      % content
      Rcout = [rps,rhs,res];
      rcf(dcnt) = dvcfun(Rcout');
      % border & content
      rbcf(dcnt) = dvbcfun([rcf(dcnt),rbf(dcnt)]');
      % mutual similarity
      jm = (x2-1)*szp + y2; 
      rmf(dcnt) = rho(im,jm);      
    end
  end
  for i = 1:ncnt
    if isnan(rcf(i)) == true
      rcf(i) = 0;
      nancnt = nancnt + 1;
    end
    if isnan(rcn(i)) == true 
      rcn(i) = 0;
      nancnt = nancnt + 1;      
    end
    if isnan(rbn(i)) == true 
      rbn(i) = 0;
      nancnt = nancnt + 1;      
    end
    if isnan(rbf(i)) == true 
      rbf(i) = 0;
      nancnt = nancnt + 1;      
    end
  end    
  %  
  resp = zeros(2*ncnt,2);
  resp(1:ncnt,1) = rcn(1:ncnt);
  resp(1:ncnt,2) = rbn(1:ncnt);
  resp(ncnt+1:2*ncnt,1) = rcf(1:ncnt);
  resp(ncnt+1:2*ncnt,2) = rbf(1:ncnt);
  category = cell(2*ncnt,1);
  category(1:ncnt) = {'same'};
  category(ncnt+1:2*ncnt) = {'diff'};
  %
  bcmn = mean(rbcf); % mean response for diff
  bcmx = mean(rbcn); % mean response for diff
  cmn = mean(rcf); % mean response for diff
  cmx = mean(rcn);
  dc = (cmx-cmn)/100;
  if isnan(cmx) == true
    cmx = cmn + 1;
  end
  optpc = 0;
  for crit = cmn:dc:cmx
    ncorr = 0;
    for i = 1:ncnt
      if rcn(i) >= crit
        ncorr = ncorr + 1;
      end
      if rcf(i) < crit
        ncorr = ncorr + 1;
      end
    end
    pcorr = ncorr/(2*ncnt);
    if pcorr > optpc
     copt = crit;
     optpc = pcorr;
    end
  end
  if pltbnd == 1
    figure; hold on;
    histogram(rcn,'BinWidth',2);
    histogram(rcf,'BinWidth',2);
  end
  %
  % test decision bound
  for j = 1:ngc
    gc = gcmn + (j-1)*dgc;   
    for k = 1:nms
      wm = msmn + (k-1)*dms;
      ncs = 0; ncd = 0; scnt = 0; dcnt = 0; ncn = 0; ncf = 0;
      for i = 1:ncnt
        if shftflg == 0 && bordflg == 0
          qbs = rcn(i); % c only, no opt c shift
          qbd = rcf(i);
        elseif shftflg == 0 && bordflg == 1
          qbs = dvbcfun([rbn(i),rcn(i)]');   % b & c, without opt c shift
          qbd = dvbcfun([rbf(i),rcf(i)]');
        else
          qbs = dvbcfun([rbn(i),rcn(i)-copt]'); % b & c, with opt c shift
          qbd = dvbcfun([rbf(i),rcf(i)-copt]');
        end     
        if same_near(i) == 1
          scnt = scnt + 1;
          if qbs + wm*rmn(i) >= gc
            ncs = ncs + 1;
            ncn = ncn + 1;
          end
        end
        if same_far(i) == 1
          scnt = scnt + 1;
          if qbd + wm*rmf(i) >= gc
            ncs = ncs + 1;
          else
            ncf = ncf + 1;
          end
        end  
        if same_near(i) == 0
          dcnt = dcnt + 1;
          if qbs + wm*rmn(i) < gc
            ncd = ncd + 1;
          else
            ncn = ncn + 1;
          end
        end
        if same_far(i) == 0
          dcnt = dcnt + 1;
          if qbd + wm*rmf(i) < gc
            ncd = ncd + 1;
            ncf = ncf + 1;
          end
        end  
      end  
      pc(j,k,trl) = (ncd+ncs)/(2*ncnt); pcs(j,k,trl) = ncs/scnt;
      pcd(j,k,trl) = ncd/dcnt; pcnf(j,k,trl) = (ncn+ncf)/(2*ncnt);
      tscnt = tscnt + scnt; tdcnt = tdcnt + dcnt;
    end
    [pcnfm(j,trl),I] = max(pcnf(j,:,trl));
    pcm(j,trl) = pc(j,I,trl); 
  end
  pcav = pcav + pc(:,:,trl); pcsav = pcsav + pcs(:,:,trl);
  pcdav = pcdav + pcd(:,:,trl); pcnfav = pcnfav + pcnf(:,:,trl);
  pcmav = pcmav + pcm(:,trl); pcnfmav = pcnfmav + pcnfm(:,trl);
  [mxJ,J] = max(pcnfm(:,trl));
  pcmgav = pcmgav + pcm(J,trl);
end
pcav = pcav/ntrl; pcsav = pcsav/ntrl; pcdav = pcdav/ntrl;
pcnfav = pcnfav/ntrl;
pcmav = pcmav/ntrl; pcnfmav = pcnfmav/ntrl;
pcmgav = pcmgav/ntrl;
[x,y] = meshgrid(msmn:dms:msmn + (nms-1)*dms,gcmn:dgc:gcmn + (ngc-1)*dgc);
figure;
surface(x,y,pcav);
xlabel('mutual similarity weight');
ylabel('criterion');
title('Average PC c-shft');
colorbar
clim([0.5 1]);
figure;
surface(x,y,pcnfav);
xlabel('mutual similarity weight');
ylabel('criterion');
title('Average PC c-shft');
colorbar
clim([0.5 1]);
done = 1;