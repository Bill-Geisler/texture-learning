%
% cdfs_of_features.m
%
% For natural images:
%
% 1. convert 16-bit linear rgb to orthogonal color channel responses
% and determine the marginal cdfs of channel responses
%
% 2. compute cdfs of edge gradient magnitudes, orientations and
% magnitude-orientation products at several scales
%
% 3. compute cdfs for center-surround filters
%
% Note that because of patch normalization, the results may depend
% on patch size.
%
clearvars; close all;
%
addpath(['C:\Users\Bill Geisler\Documents\Projects\Texture\Images' ...
        '\CPS Set-9-10-12_16-bit linear']);
%
rng(0); % random number generator seed
% rng('shuffle');
%
% parameters
cnorm = 1; % cnorm, edge features, and lms flag
m0 = 128; c0 = 0.25; ntype = 3; ncolr = 3;
%
% optical filter
filter = 1;  % 1 = apply optical filter, 0 = no filter*********************
pd = 4;      % pupil diameter
w = 550;     % wavelength
ppd = 64;    % pixels per degree
%
% edge
nbins = 16000; mxval = 2^14-1; thresh = 0;
sd1 = 1; nsd1 = 3; sd2 = 1; nsd2 = 3;
dsz1 = floor(sd1*nsd1/2 + 1);
dsz2 = floor(sd2*nsd2/2 + 1);
% color
lmsmtrx = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
swid1 = 3; swid2 = 3; % filter  width in pixels
if filter == 0
  load("PCA_matrix_3.mat"); % lms to abr for ntype = 3 and no otf
elseif filter == 1
  load("PCA_matrix_3_OTF.mat"); % lms to abr for ntype = 3 and otf
end
%
nimg9 = 104; nimg10 = 90; nimg12 = 197;
nsmp = 20;
showimg = 0;
psz = 64;
szx = 2844; szy = 4284;
n = 0; ng = 0; ng2 = 0; ncs1 = 0; ncs2 = 0; ncs4 = 0;
%
nrgb = (nimg9+nimg10+nimg12)*nsmp*psz^2;
lms = zeros(nrgb,3); abr = zeros(nrgb,3);
csl1 = zeros(nrgb,1);
csl2 = zeros(nrgb,1);
csl4 = zeros(nrgb,1);
%
gml1 = zeros(nrgb,1);
gol1 = zeros(nrgb,1);
gmol1 = zeros(nrgb,1);
%
gm2l1 = zeros(nrgb,1);
go2l1 = zeros(nrgb,1);
gmo2l1 = zeros(nrgb,1);
%
plotflag = 1;   % 1 = read previous results and plot, 0 = do everything
%
if plotflag == 1 % read previous results and plot**************************
  load("cdfs_abr_mo13_mo23_cs33_otf.mat"); % natural image cdfs
  %
  %  channel cdfs
  n0a = 1;
  for i = 1:nbins-1
    if Nb(i) < 0.5 && Nb(i+1) > 0.5
      n0b = i;
    end    
    if Nr(i) < 0.5 && Nr(i+1) > 0.5
      n0r = i;
    end    
  end  
  dna = 2500;
  dnb = 1000;
  dnr = 1000;
  figure;
  tiledlayout(3,3);
  nexttile
  plot(ea(n0a:n0a+dna),Na(n0a:n0a+dna),"black",LineWidth=1.5);
  xlabel('a'); ylabel('pr');
  nexttile
  plot(eb(n0b-dnb:n0b+dnb),Nb(n0b-dnb:n0b+dnb),"blue",LineWidth=1.5);
  xlabel('b'); ylabel('pr');
  nexttile
  plot(er(n0r-dnr:n0r+dnr),Nr(n0r-dnr:n0r+dnr),"red",LineWidth=1.5);
  xlabel('r'); ylabel('pr');
  fontsize(12,'points');
%
  dngm = 1000;
  dngo = 7500;
  dngmo = 400;
  dncs = 400;
  n0m = 1;
  for i = 1:nbins-1
    if No(i) < 0.5 && No(i+1) > 0.5
      n0o = i;
    end    
    if Nmo(i) < 0.5 && Nmo(i+1) > 0.5
      n0mo = i;
    end    
    if Ncs1(i) < 0.5 && Ncs1(i+1) > 0.5
      n0cs1 = i;
    end
    if Ncs2(i) < 0.5 && Ncs2(i+1) > 0.5
      n0cs2 = i;
    end
    if Ncs4(i) < 0.5 && Ncs4(i+1) > 0.5
      n0cs4 = i;
    end        
  end
  figure;
  tiledlayout(3,3);
%
% gradient magnitude histogram 1st
  nexttile
  % histogram(gml1(1:ng),8000,FaceColor='black',EdgeColor='black');
  % axis([0 200 0 inf]);
  plot(em(n0m:n0m+dngm-1),Nm(n0m:n0m+dngm-1),"black",LineWidth=1.5);
  xlabel('m'); ylabel('pr');
%
% gradient orientation histogram
  nexttile
  % histogram(gol1(1:ng),8000,FaceColor='black',EdgeColor='black');
  % axis([-180 180 0 15000]);
  plot(eo(n0o-dngo:n0o+dngo),No(n0o-dngo:n0o+dngo),"black",LineWidth=1.5);
  xlabel('o'); ylabel('pr');
  %
% gradient product histogram
  nexttile
  % histogram(gmol1(1:ng),8000,FaceColor='black',EdgeColor='black');
  % axis([-18000 18000 0 inf]);
  plot(emo(n0mo-dngmo:n0mo+dngmo),Nmo(n0mo-dngmo:n0mo+dngmo),"black",LineWidth=1.5);
  xlabel('m x o'); ylabel('pr');
%
  dngm = 230;
  dngo = 7500;
  dngmo = 200;
  n0m = 1;
  for i = 1:nbins-1
    if Nm2(i) < 0.5 && Nm2(i+1) > 0.5
      n0m = i;
    end    
    if No2(i) < 0.5 && No2(i+1) > 0.5
      n0o = i;
    end    
    if Nmo2(i) < 0.5 && Nmo2(i+1) > 0.5
      n0mo = i;
    end    
  end
% response magnitude histogram 2nd derivative
  nexttile
  % histogram(gm2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
  % axis([0 120 0 inf]);
  plot(em2(1:900),Nm2(1:900),"black",LineWidth=1.5);
  xlabel('m'); ylabel('pr');
%
% response orientation histogram 2nd derrivative
  nexttile
  % histogram(go2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
  % axis([-90 90 0 15000]);
  plot(eo2(n0o-dngo:n0o+dngo),No2(n0o-dngo:n0o+dngo),"black",LineWidth=1.5);
  xlabel('o'); ylabel('pr');
%
% response product histogram 2nd derivative
  nexttile
  % histogram(gmo2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
  % axis([-5000 5000 0 inf]);
  plot(emo2(n0mo-dngmo:n0mo+dngmo),Nmo2(n0mo-dngmo:n0mo+dngmo),"black",LineWidth=1.5);
  xlabel('m x o'); ylabel('pr');
% %
% % ratio center-surround histogram
%   nexttile
%   % histogram(csl1(1:ncs),8000,FaceColor='black',EdgeColor='black');
%   % axis([-0.5 0.5 0 inf]);
%   plot(ecs1(n0cs1-dncs:n0cs1+dncs),Ncs1(n0cs1-dncs:n0cs1+dncs),"black");
%   xlabel('cs1'); ylabel('pr');
%   fontsize(12,'points');
%
% linear center-surround histogram
  nexttile
  % histogram(csl2(1:ncs2),8000,FaceColor='black',EdgeColor='black');
  % axis([-0.5 0.5 0 inf]);
  plot(ecs2(n0cs2-dncs:n0cs2+dncs),Ncs2(n0cs2-dncs:n0cs2+dncs),"black",LineWidth=1.5);
  xlabel('cs1'); ylabel('pr');
  fontsize(12,'points');
  %
  % linear center-surround histogram 5 x 5
  nexttile
  % histogram(csl4(1:ncs4),8000,FaceColor='black',EdgeColor='black');
  % axis([-0.5 0.5 0 inf]);
  plot(ecs4(n0cs4-dncs:n0cs4+dncs),Ncs4(n0cs4-dncs:n0cs4+dncs),"black",LineWidth=1.5);
  xlabel('cs2'); ylabel('pr');
  fontsize(12,'points');
%
  nexttile
  ep = (1:100);
  Np = 1-exp(-ep/30);
  plot(ep,Np,"black",LineWidth=1.5);
  xlabel('p'); ylabel('pr');
  fontsize(12,'points');
%
%  
else % do everything*******************************************************
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
  imglms = rgb2lms(imgrgb,lmsmtrx);
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    ptch = imglms(x:x+psz-1,y:y+psz-1,:);    
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % ntype of normalization
    % lms values
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
    % gradient magnitudes and orientations and center/surround
    ptch = rot(ptch,coeff,psz);   % transform to abr coordinates
    ptcha = ptch(:,:,1);      % process the a channel
    if cnorm == 1     % contrast normalization
      ptcha = cntrst_norm(ptcha,c0,psz);
    end
    [gm,go] = imgrad(ptcha,sd1,nsd1);
    [gsz,~] = size(gm); 
    for i = 1:gsz
      for j = 1:gsz
        if gm(i,j) > thresh
          ng = ng+1;
          gml1(ng) = gm(i,j);
          gol1(ng) = go(i,j);
          gmol1(ng) = gm(i,j)*go(i,j);
        end
      end
    end
    [gm2,go2] = imgrad2(ptcha,sd2,nsd2);
    [gsz2,~] = size(gm2);
    for i = 1:gsz2
      for j = 1:gsz2
        ng2 = ng2 + 1;
        gm2l1(ng2) = gm2(i,j);
        go2l1(ng2) = go2(i,j);
        gmo2l1(ng2) = gm2(i,j)*go2(i,j);
      end
    end
    cstype = 1;
    [cs] = cen_sur(ptcha,swid1,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs1 = ncs1 + 1;
        csl1(ncs1) = cs(i,j);
      end
    end
    cstype = 2;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs2 = ncs2 + 1;
        csl2(ncs2) = cs(i,j);
      end
    end
    cstype = 4;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs4 = ncs4 + 1;
        csl4(ncs4) = cs(i,j);
      end
    end          
  end
end
%
% image set 10
for inum = 1:nimg10
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set10_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);  % apply OTF
  end     
  imglms = rgb2lms(imgrgb,lmsmtrx);
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    ptch = imglms(x:x+psz-1,y:y+psz-1,:);    
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % ntype of normalization
    % lms values
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
    % gradient magnitudes and orientations and center/surround
    ptch = rot(ptch,coeff,psz);   % transform to abr coordinates
    ptcha = ptch(:,:,1);      % process the a channel
    if cnorm == 1     % contrast normalization
      ptcha = cntrst_norm(ptcha,c0,psz);
    end
    [gm,go] = imgrad(ptcha,sd1,nsd1);
    [gsz,~] = size(gm); 
    for i = 1:gsz
      for j = 1:gsz
        if gm(i,j) > thresh
          ng = ng+1;
          gml1(ng) = gm(i,j);
          gol1(ng) = go(i,j);
          gmol1(ng) = gm(i,j)*go(i,j);
        end
      end
    end
    [gm2,go2] = imgrad2(ptcha,sd2,nsd2);
    [gsz2,~] = size(gm2);
    for i = 1:gsz2
      for j = 1:gsz2
        ng2 = ng2 + 1;
        gm2l1(ng2) = gm2(i,j);
        go2l1(ng2) = go2(i,j);
        gmo2l1(ng2) = gm2(i,j)*go2(i,j);
      end
    end
    cstype = 1;
    [cs] = cen_sur(ptcha,swid1,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs1 = ncs1 + 1;
        csl1(ncs1) = cs(i,j);
      end
    end
    cstype = 2;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs2 = ncs2 + 1;
        csl2(ncs2) = cs(i,j);
      end
    end
    cstype = 4;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs4 = ncs4 + 1;
        csl4(ncs4) = cs(i,j);
      end
    end              
  end
end
%
% image set 12
for inum = 1:nimg12
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set12_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w); % apply OTF
  end     
  imglms = rgb2lms(imgrgb,lmsmtrx);
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    ptch = imglms(x:x+psz-1,y:y+psz-1,:);    
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % ntype of normalization
    % lms values
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
    % gradient magnitudes and orientations and center/surround
    ptch = rot(ptch,coeff,psz);   % transform to abr coordinates
    ptcha = ptch(:,:,1);      % process the a channel
    if cnorm == 1     % contrast normalization
      ptcha = cntrst_norm(ptcha,c0,psz);
    end
    [gm,go] = imgrad(ptcha,sd1,nsd1);
    [gsz,~] = size(gm); 
    for i = 1:gsz
      for j = 1:gsz
        if gm(i,j) > thresh
          ng = ng+1;
          gml1(ng) = gm(i,j);
          gol1(ng) = go(i,j);
          gmol1(ng) = gm(i,j)*go(i,j);
        end
      end
    end
    [gm2,go2] = imgrad2(ptcha,sd2,nsd2);
    [gsz2,~] = size(gm2);
    for i = 1:gsz2
      for j = 1:gsz2
        ng2 = ng2 + 1;
        gm2l1(ng2) = gm2(i,j);
        go2l1(ng2) = go2(i,j);
        gmo2l1(ng2) = gm2(i,j)*go2(i,j);
      end
    end
    cstype = 1;
    [cs] = cen_sur(ptcha,swid1,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs1 = ncs1 + 1;
        csl1(ncs1) = cs(i,j);
      end
    end
    cstype = 2;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs2 = ncs2 + 1;
        csl2(ncs2) = cs(i,j);
      end
    end 
    cstype = 4;
    [cs] = cen_sur(ptcha,swid2,cstype);
    [csz,~] = size(cs);      
    for i = 1:csz
      for j = 1:csz
        ncs4 = ncs4 + 1;
        csl4(ncs4) = cs(i,j);
      end
    end                  
  end
end
%
% cumulative channel and filter responses
for i = 1:n
  abr(i,:) = lms(i,:)*coeff; % correct multiplicatoin
end
[Na,ea] = histcounts(abr(1:n,1),nbins,'Normalization','cdf');
[Nb,eb] = histcounts(abr(1:n,2),nbins,'Normalization','cdf');
[Nr,er] = histcounts(abr(1:n,3),nbins,'Normalization','cdf');
%
% first derivative of gaussians steerable filter
[Nm,em] = histcounts(gml1(1:ng),nbins,'Normalization','cdf');
[No,eo] = histcounts(gol1(1:ng),nbins,'Normalization','cdf');
[Nmo,emo] = histcounts(gmol1(1:ng),nbins,'Normalization','cdf');
% second derivative of gaussians steerable filter
[Nm2,em2] = histcounts(gm2l1(1:ng2),nbins,'Normalization','cdf');
[No2,eo2] = histcounts(go2l1(1:ng2),nbins,'Normalization','cdf');
[Nmo2,emo2] = histcounts(gmo2l1(1:ng2),nbins,'Normalization','cdf');
% ratio center surround filter
[Ncs1,ecs1] = histcounts(csl1(1:ncs1),nbins,'Normalization','cdf'); 
[Ncs2,ecs2] = histcounts(csl2(1:ncs2),nbins,'Normalization','cdf'); 
[Ncs4,ecs4] = histcounts(csl2(1:ncs4),nbins,'Normalization','cdf'); 
%
% Save cdfs
% abr = opponent color channels, mo13 = magnitude, oriention and product
% for 1st derivative of Gauss 3x3 kernel, mo23 = magnitude, oriention
% and product for 2nd derivative of Gauss 3x3 kernel, cs3 = ratio and
% linear center-surround filter 3 x 3 kernel, otf = otf applied to images
if filter == 0
  save("cdfs_abr_mo13_mo23_cs33.mat","ea","Na","eb","Nb", ...
       "er","Nr","em","Nm","eo","No","emo","Nmo","em2","Nm2", ...
       "eo2","No2","emo2","Nmo2","ecs1","Ncs1","ecs2","Ncs2",...
       "ecs4","Ncs4","coeff");
elseif filter == 1
  save("cdfs_abr_mo13_mo23_cs33_otf.mat","ea","Na","eb","Nb", ...
       "er","Nr","em","Nm","eo","No","emo","Nmo","em2","Nm2", ...
       "eo2","No2","emo2","Nmo2","ecs1","Ncs1","ecs2","Ncs2",...
       "ecs4","Ncs4","coeff");
end  
%
dngm = 800;
dngo = 7500;
dngmo = 400;
dncs = 400;
n0m = 1;
for i = 1:nbins-1
  if No(i) < 0.5 && No(i+1) > 0.5
    n0o = i;
  end    
  if Nmo(i) < 0.5 && Nmo(i+1) > 0.5
    n0mo = i;
  end    
  if Ncs1(i) < 0.5 && Ncs1(i+1) > 0.5
    n0cs1 = i;
  end
  if Ncs2(i) < 0.5 && Ncs2(i+1) > 0.5
    n0cs2 = i;
  end        
  if Ncs4(i) < 0.5 && Ncs4(i+1) > 0.5
    n0cs4 = i;
  end        
end
figure;
tiledlayout(3,3);
%
% gradient magnitude histogram 1st
nexttile
% histogram(gml1(1:ng),8000,FaceColor='black',EdgeColor='black');
% axis([0 200 0 inf]);
plot(em(n0m:n0m+dngm-1),Nm(n0m:n0m+dngm-1),"black",LineWidth=1.5);
xlabel('m'); ylabel('pr'); LineWidth(1.0);
%
% gradient orientation histogram
nexttile
% histogram(gol1(1:ng),8000,FaceColor='black',EdgeColor='black');
% axis([-180 180 0 15000]);
plot(eo(n0o-dngo:n0o+dngo),No(n0o-dngo:n0o+dngo),"black",LineWidth=1.5);
xlabel('o'); ylabel('pr');
%
% gradient product histogram
nexttile
% histogram(gmol1(1:ng),8000,FaceColor='black',EdgeColor='black');
% axis([-18000 18000 0 inf]);
plot(emo(n0mo-dngmo:n0mo+dngmo),Nmo(n0mo-dngmo:n0mo+dngmo),"black",LineWidth=1.5);
xlabel('m x o'); ylabel('pr');
%
dngm = 450;
dngo = 7500;
dngmo = 200;
n0m = 1;
for i = 1:nbins-1
  if No2(i) < 0.5 && No2(i+1) > 0.5
    n0o = i;
  end    
  if Nmo2(i) < 0.5 && Nmo2(i+1) > 0.5
    n0mo = i;
  end    
end
% response magnitude histogram 2nd derivative
nexttile
% histogram(gm2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
% axis([0 120 0 inf]);
plot(em2(n0m:dngm),Nm2(n0m:dngm),"black",LineWidth=1.5);
xlabel('m'); ylabel('pr');
%
% response orientation histogram 2nd derrivative
nexttile
% histogram(go2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
% axis([-90 90 0 15000]);
plot(eo2(n0o-dngo:n0o+dngo),No2(n0o-dngo:n0o+dngo),"black",LineWidth=1.5);
xlabel('o'); ylabel('pr');
%
% response product histogram 2nd derivative
nexttile
% histogram(gmo2l1(1:ng2),8000,FaceColor='black',EdgeColor='black');
% axis([-5000 5000 0 inf]);
plot(emo2(n0mo-dngmo:n0mo+dngmo),Nmo2(n0mo-dngmo:n0mo+dngmo),"black",LineWidth=1.5);
xlabel('m x o'); ylabel('pr');
% %
% % ratio center-surround histogram
% nexttile
% % histogram(csl1(1:ncs1),8000,FaceColor='black',EdgeColor='black');
% % axis([-0.5 0.5 0 inf]);
% plot(ecs1(n0cs1-dncs:n0cs1+dncs),Ncs1(n0cs1-dncs:n0cs1+dncs),"black",LineWidth=1.5);
% xlabel('cs1'); ylabel('pr');
%
% linear center-surround histogram 3 x 3
nexttile
% histogram(csl2(1:ncs2),8000,FaceColor='black',EdgeColor='black');
% axis([-0.5 0.5 0 inf]);
plot(ecs2(n0cs2-dncs:n0cs2+dncs),Ncs2(n0cs2-dncs:n0cs2+dncs),"black",LineWidth=1.5);
xlabel('cs2'); ylabel('pr');
%
% linear center-surround histogram 5 x 5
nexttile
% histogram(csl4(1:ncs4),8000,FaceColor='black',EdgeColor='black');
% axis([-0.5 0.5 0 inf]);
plot(ecs4(n0cs4-dncs:n0cs4+dncs),Ncs4(n0cs4-dncs:n0cs4+dncs),"black",LineWidth=1.5);
xlabel('cs4'); ylabel('pr');
fontsize(12,'points');
%
nexttile
ep = (1:100);
Np = 1-exp(-ep/30);
plot(ep,Np,"black",LineWidth=1.5);
xlabel('p'); ylabel('pr');
fontsize(12,'points');
end

