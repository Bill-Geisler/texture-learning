%
% tex_grp_s_p_ms_SS_ncbm
% texture grouping with local similarity, mutual similarity,
% transitive grouping, confidence grouping, region similarity
% with local and mutual similarity trained on proximity
%
% routines called:
%   mk_texs.m
%   mk_masks.m
%   cntrst_norm.m
%   patch_norm.m
%   fil_dsmp.m
%   rgb2lms.m
%   rot.m
%   rp.m
%   rh.m
%   rb.m
%   re.m
%   mk_phi.m
%   mk_groups.m
%   reg_count.m
%
clearvars; close all;
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Brodatz')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Fabric')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Pertex')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Vistex')
addpath('C:\Users\Bill Geisler\Documents\Projects\Texture\Images\Mcgill')
%
rng(0);    % random number seed
itype = 1; %***************************************************************
saveflg = 0; % 1 = save results (e.g., resultsF.mat)
shftflg = 0;
%
% optical filter
filter = 1;  % 1 = apply optical filter, 0 = no filter*********************
pd = 4;      % pupil diameter
w = 550;     % wavelength
%
sz1 = 640;       % level 1 image size
psz1 = 64;       % level 1 patch size
lev = 1;         % resolution scale-down level (1,2,4,8) ******************
levb = 1;        % level for bin bounds (1,2,4,8) *************************
sz = sz1/lev;    % image size given level
psz = psz1/lev;  % patch size given level
ppd = 60;        % pixels per degree
lms = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
ncolr = 3;       % number of color channels
%
% texture stimulus parameters
ntexr = 5;      % 5 number of texture regions
szp = 10;       % image size in patches
seedr = 1.0;    % texture seed radius as fraction of max
pixp = 1.0;     % proportion of pixels taken up by texture regions
ntrl = 1;       % number of trials
trl = 1;        % current trial (here it is fixed at 1)
sz2 = szp^2;    % number of image patches in GTR image
imw = psz*szp; % GTR image width in patches
ncnt = 2*(szp-1)^2; % number of near and far patch pairs in the GTR image 
%
% norm: 0 = none 1 = mean, 2 = mean and contrast, 3 = average mean
ntype = 3;   % type of normalization in patch_norm ************************
cnorm = 1;   % contrast normalization 1 = yes *****************************
m0 = 128;    % normalization mean
c0 = 0.25;   % normalization contrast
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
  nimg = 120;
  hnimg = nimg/2;
else
  nimg = 60;
  hnimg = nimg;
end
cimg = double(zeros(sz1,sz1,3));
imgr = zeros(sz,sz,nimg);
imgg = zeros(sz,sz,nimg);
imgb = zeros(sz,sz,nimg);
for k = 1:nimg
  if itype == 1
    del = 270;
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
%
% border detection parameters
showflag = 0;
%
% power spectrum
b0 = 16;                 % weak Fourier power suppression parameter 
%
% load bin bounds, 0=HE, 2=AHE-F, 3=AHE-B, 4=AHE-B&F
% load bin bounds, 0=HE, 2=AHE-F, 3=AHE-B, 4=AHE-B&F
b = 5; % bin type: 4 = Brodatz & Fabric, 5 = natural image*****************
cstat = [b,0,0,0,b,b,b,0,b,b,b,0,b,b,0,0,0,0,0,0]; 
[nb,bb] = mk_bb(cstat,levb,filter);
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
fun_level = 0;
%
% load decision coeffs edge features
num = num2str(lev);
if filter == 0
  name = append('dbndeBF',num,'.mat');   % trained on separated
elseif filter == 1
  name = append('dbndeNO',num,'.mat');  % trained on separated
end
load(name);
dvefun=quad2fun(dbnde,fun_level); % decision-variable function from coeffs
%
% load decision coeffs h features
if filter == 0
  name = append('dbndhBF',num,'.mat');   % trained on separated
elseif filter == 1
  name = append('dbndhNO',num,'.mat');  % trained on separated
end
load(name);
dvhfun=quad2fun(dbndh,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for content features
if filter == 0
  name = append('dbndcBF',num,'.mat');   % trained on separated
elseif filter == 1
  name = append('dbndcNO',num,'.mat');  % trained on natural images
end
load(name);
dvcfun=quad2fun(dbndc,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for border features
if filter == 0
  name = append('dbndbBF',num,'.mat');   % trained on separated
elseif filter == 1
  name = append('dbndbNO',num,'.mat');  % trained on natural images
end
load(name);
dvbfun=quad2fun(dbndb,fun_level); % decision-variable function from coeffs
%
% load decision coeffs for border & content features
if filter == 0
  name = append('dbndbcBF',num,'.mat');   % trained on separated
elseif filter == 1
  name = append('dbndbcNO',num,'.mat');  % trained on natural images
end
load(name);
dvbcfun=quad2fun(dbndbc,fun_level); % decision-variable function from coeffs
%
%*******************************
% create and process GTR images
%*******************************
%
pltbnd = 0;
plotflg = 0; % 0 = no plot, 1 = texture images, 2 = estimated regions
if plotflg ~= 0
  figure;
  tiledlayout(3,4);
end
%
% global parameters
% mu = phi + u0*rho is local similarity plus mutual similarity
% if |mu-gc| < cc then don't decide until after trans grouping  
%
% local similarity grouping criterion
% gcmn = 2.4; dgc = 0.1; gcmx = 2.4; ngc = (gcmx-gcmn)/dgc + 1;
gcmn = 0; dgc = 0.8; gcmx = 8; ngc = (gcmx-gcmn)/dgc + 1;
%
% mutual similarity weight
msmn = 0; dms = 0.8; msmx = 9.6; nms = round((msmx-msmn)/dms + 1);
%
% merge criterion
mcmn = 0; dmc= 0.2; mcmx = 1; nmc = (mcmx-mcmn)/dmc + 1;
%
% confidence criterion
dcc = 0.1; ccmn = 1.1; ccmx = 1.1; ncc = round((ccmx-ccmn)/dcc + 1);
%
% del gcopt
dgcmn = 0; deldgc = 0.25; dgcmx = 2; ndgc = round((dgcmx-dgcmn)/deldgc + 1);
%
results = zeros(10000,9); rescnt = 0;
ngtrimg = 12; nseed = 10;
ngtr = ngtrimg*nseed;
nregs = zeros(nmc,ndgc,ngtr); % main result array
dvbs = zeros(ncnt,ngtr); dvcs = zeros(ncnt,ngtr); % distributions same
dvbd = zeros(ncnt,ngtr); dvcd = zeros(ncnt,ngtr); % distributions diff
%
% Seed loop
for seed = 1:nseed %
rng(seed-1);
%
% GTR image loop***********************************************************
for gtrimg = 1:ngtrimg
  imgnum = (seed-1)*ngtrimg + gtrimg;
  % rng((gtrimg-1)*10); % 0, 10, 20, 30, 40, 50, 60, 70 ,80, 90, 100, 110
  %
  iscl = 0.0;  % 0.1 illumination scalar offset ***************************
  %
  % grouping parameters
  ph0 = 0;        % -lnlnL offset
  g = 0;          % max proximity offset
  b = 1;          % proximity exponent
  dmin = 64;      % minimum distance between patches in pixels
  %
  % generate random texture numbers for ntrl images (here ntrl = 1)
  texs = mk_texs(nimg,ntexr,ntrl);
  %
  % generate ntrl masks and maps (here ntrl = 1)
  [masks,maps] = mk_masks(szp,ntexr,ntrl,seedr,pixp);
  %  
  % make masks for the trial
  msks = zeros(imw,imw,ntexr);
  for i = 1:ntexr
    for j = 1:szp
      x = (j-1)*psz+1; 
      for k = 1:szp
        if maps(j,k,1) == i
          y = (k-1)*psz+1; 
          msks(x:x+psz-1,y:y+psz-1,i) = 1;
        end
      end
    end
  end
  %
  % create map from patch number to x,y coordinates 
  xx = zeros(sz2,1);
  yy = zeros(sz2,1);
  k = 0;
  for i = 1:szp:sz2
    k = k+1;
    l = 0;
    for j = i:i+szp-1
      l = l+1;
      xx(j) = k;
      yy(j) = l;
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
  pimg = zeros(imw,imw,3); limg = zeros(imw,imw,3); img = zeros(imw,imw,3);
  for i = 1:ntexr
    k = texs(1,i);
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
    img = adobe_compress(img);
    img = rescale(img);
    image(img); axis image; axis off; %title([num2str(ntexr)]);
    title([num2str(ntexr)]);  
  end
  %
  %************* estimate content and boundary & content*******************
  % *************decision variable from proximity**************************
  %
  % compute all content similarities
  phiall = mk_phi(pimg,szp,psz,cstat,flist,filter,xx,yy,coeff,...
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
      rho(i,j) = sum(vi.*vj)/sqrt(sum(vi.^2)*sum(vj.^2)); % vector angle
    end
  end
  rho(isnan(rho)) = 0;
  %
  % storage
  pc = zeros(ngc,nms,ntrl); pcs = zeros(ngc,nms,ntrl);
  pcd = zeros(ngc,nms,ntrl); pcnf = zeros(ngc,nms,ntrl); tscnt = 0; tdcnt = 0;
  pcav = zeros(ngc,nms); pcsav = zeros(ngc,nms); pcdav = zeros(ngc,nms);
  pcnfav = zeros(ngc,nms); pcm = zeros(ngc,ntrl); pcnfm = zeros(ngc,ntrl);
  pcmav = zeros(ngc,1); pcnfmav = zeros(ngc,1); nancnt = 0;
  %
  % compute neighboring and distant pairwise feature responses
  rbf = zeros(1,ncnt); rcf = zeros(1,ncnt); rbcf = zeros(1,ncnt);
  rbn = zeros(1,ncnt); rcn = zeros(1,ncnt); rbcn = zeros(1,ncnt);
  rmf = zeros(1,ncnt); rmn = zeros(1,ncnt); same_near = zeros(1,ncnt);
  same_far = zeros(1,ncnt); scnt = 0; dcnt = 0;  
  dcrit = 7.0; % far patch criterion***********************************
  %
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
      rbcn(scnt) = dvbcfun([rbn(scnt),rcn(scnt)]');      
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
      rbcn(scnt) = dvbcfun([rbn(scnt),rcn(scnt)]');        
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
      rbcf(dcnt) = dvbcfun([rbf(dcnt),rcf(dcnt)]');
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
      rbcf(dcnt) = dvbcfun([rbf(dcnt),rcf(dcnt)]');
      % mutual similarity
      jm = (x2-1)*szp + y2; 
      rmf(dcnt) = rho(im,jm);      
    end
  end
  %
  % self-supervised learning
  %
  bcmn = mean(rbcf); % mean response for far
  bcmx = mean(rbcn);
  dbc = (bcmx-bcmn)/100;
  if isnan(bcmx) == true
      bcmx = bcmn + 5;
  end
  optpc = 0;
  for crit = bcmn:dbc:bcmx
      ncorr = 0;
      for i = 1:ncnt
          if rbcn(i) >= crit
              ncorr = ncorr + 1;
          end
          if rbcf(i) < crit
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
      histogram(rbcn,'BinWidth',2);
      histogram(rbcf,'BinWidth',2);
  end
  %
  % test decision bound
  for j = 1:ngc
      gc = gcmn + (j-1)*dgc;   
      for k = 1:nms
          wm = msmn + (k-1)*dms;   
          ncs = 0; ncd = 0; scnt = 0; dcnt = 0; ncn = 0; ncf = 0;
          for i = 1:ncnt
              if shftflg == 0
                  qbs = rbcn(i); % b & c only, no opt bc shift
                  qbd = rbcf(i);
              else
                  qbs = rbcn(i)-copt; % b & c, with opt bc shift
                  qbd = rbcf(i)-copt;
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
  [pcnfmx,J] = max(pcnfm(:,trl));
  pcmx = pcmav(J);
  [~,I] = max(pcnf(J,:,trl));
  wmopt = msmn + (I-1)*dms;
  gcopt = gcmn + (J-1)*dgc;
  %
  %******apply learned decision parameters to segment the GTR image********
  %
  % compute similarities
  phi = zeros(sz2,sz2); dst = zeros(sz2,sz2);
  dvcnt = 0;
  vi = zeros(sz2-2,1); vj = zeros(sz2-2,1);
  %
  % compute neighboring pairwise feature responses
  for i = 1:sz2
    for j = i+1:sz2
      x1 = (xx(i)-1)*psz + 1; y1 = (yy(i)-1)*psz + 1;
      x2 = (xx(j)-1)*psz + 1; y2 = (yy(j)-1)*psz + 1;
      dij = sqrt((x1-x2)^2 + (y1-y2)^2);
      dst(i,j) = dij;
      %
      if dij == dmin
        dvcnt = dvcnt + 1;
        %
        % calculate direction from ptch1
        % dir: 1 = x up, 2 = y up
        if y1 == y2 && x2 > x1
          dir = 1;
        elseif x1 == x2 && y2 > y1
          dir = 2;
        end          
        ptch1 = pimg(x1:x1+psz-1,y1:y1+psz-1,:);
        [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means
        ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
        %  
        ptch2 = pimg(x2:x2+psz-1,y2:y2+psz-1,:);
        [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch
        ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates 
        %
        % compute responses
        ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge
        ptch2a = ptch2(:,:,1); 
      % power
        Rpout = Rp(ptch1a,ptch2a,b0,psz);
        rp = log(Rpout);
      % color      
        Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
        rh = dvhfun([log(Rhout(nh(1))),log(Rhout(nh(2)))...
          log(Rhout(nh(3)))]'); 
      % contrast normalize     
        if cnorm == 1 
          ptch1a = cntrst_norm(ptch1a,c0,psz);
          ptch2a = cntrst_norm(ptch2a,c0,psz);
        end
      % border
        Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
        rb = dvbfun(Rbout(1:2)'); 
      % edge
        Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
        re = dvefun([log(Reout(ne(1))),log(Reout(ne(3))),...
          log(Reout(ne(4)))]');
      % content
        Rcout = [rp,rh,re];
        rc = dvcfun(Rcout');
      % mutual similarity
        im = (xx(i)-1)*szp + yy(i);
        jm = (xx(j)-1)*szp + yy(j);
      % 
      % self-supervised border & content decision variable
        dv = [rb,rc];
        phi0 = dvbcfun(dv');
      %
      % load phi matrix****************************************************
        phi(i,j) = phi0;   % exclude mutual similarity
        phi(j,i) = phi(i,j);
      end  
    end
  end
  %
  % combine similarity and mutual similarity
  mu = zeros(sz2,sz2); 
  mrho = 0; rhocnt = 0;
  for i = 1:sz2
    for j = 1:sz2
      if phi(i,j) ~= 0
        mu(i,j) = phi(i,j) + wmopt*rho(i,j);
        mrho = mrho + rho(i,j);
        rhocnt = rhocnt + 1;     
      else
        rho(i,j) = 0;
      end
    end
  end
  mrho = mrho/rhocnt;
  %
  % make groups
  nreg5 = 0;
  for l = 1:ndgc
    dgc = dgcmn + (l-1)*deldgc;  
  for k = 1:nmc
    rescnt = rescnt + 1;  
    mc = mcmn + (k-1)*dmc;
    nregmx = 0; nreg5mx = 0;
    for j = 1:ncc
     cc = ccmn + (j-1)*dcc;
     [groups,ngrps,groups2d] = mk_groups(mu,dst,szp,gcopt+dgc,cc,dmin,...
        xx,yy,phiall,mc);
     nreg = reg_count(maps,ntexr,groups2d,ngrps,szp);
     nregs(k,l,imgnum) = nreg;
     if nreg >= nregmx
       nregmx = nreg;  
       copt = cc;
     end
      if nregmx == ntexr
        nreg5 = 1;
      end   
    end
    if plotflg == 2
      nexttile
      image(groups2d,'CDataMapping','scaled'); axis image; axis off;
      title([num2str(nreg)]);  
    end
%
    results(rescnt,1) = copt; results(rescnt,2) = mc; 
    results(rescnt,3) = gcopt; results(rescnt,4) = wmopt;
    results(rescnt,5) = nreg; results(rescnt,6) = nreg5; 
    results(rescnt,7) = ngrps; results(rescnt,8) = pcorr;
    results(rescnt,9) = dgc;
  end % end of mc loop
  end % end of dgc loop
  %
end % end of gtrimg loop
end % end of seed loop
%
% compute average results
nregs_ave = zeros(nmc,ndgc); nregs5_ave = zeros(nmc,ndgc);
nregs_sd = zeros(nmc,ndgc); nregs5_sd = zeros(nmc,ndgc);
nregs5 = zeros(nmc,ndgc,ngtr);
for i = 1:nmc
  for j = 1:ndgc
    for k = 1:ngtr
      if nregs(i,j,k) == 5
        nregs5(i,j,k) = 1;
      end
    end
  end
end
for i = 1:ngtr
  nregs_ave = nregs_ave + nregs(:,:,i);
  nregs5_ave = nregs5_ave + nregs5(:,:,i);
  nregs_sd = nregs_sd + nregs(:,:,i).^2;
  nregs5_sd = nregs5_sd + nregs5(:,:,i).^2;
end
nregs_ave = nregs_ave/ngtr;   % average number of regions exact
nregs5_ave = nregs5_ave/ngtr; % average number of images exact
nregs_sd = (nregs_sd/ngtr - nregs_ave.^2).^0.5;
nregs5_sd = (nregs5_sd/ngtr - nregs5_ave.^2).^0.5;
nregs_sd = nregs_sd/sqrt(ngtr);   % std err of regions exact 
nregs5_sd = nregs5_sd/sqrt(ngtr); % std err of images exact
if saveflg == 1
  if itype == 1
    save('resultsP',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")   
  elseif itype == 2
    save('resultsF',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")    
  elseif itype == 3
    save('resultsB',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")          
  elseif itype == 4 
    save('resultsBF',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")          
  elseif itype == 5 
    save('resultsV',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")          
  elseif itype == 6
    save('resultsM',"nregs","dvbs","dvcs","dvbd","dvcd","ccmn","dcc",...
        "mcmn","dmc")       
  end
end