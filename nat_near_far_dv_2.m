%
% learn all near-far decision bounds from natural image patch pairs
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
lev = 1;         % resolution scale-down level (1,2,4,8) ******************
levb = 1;        % level for bin bounds (1,2,4,8) *************************
sz = sz1/lev;    % image size given level
psz = psz1/lev;  % patch size given level
psz2 = 2*psz;
ppd = 60;        % pixels per degree
lms = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
ncolr = 3;       % number of color channels
mnv = -25; mxv = 25;
saveflg = 0;
%
% border 
showflag = 0;
dir = 2;
%
% load color and edge histograms
if filter == 0
  load("cdfs_abr_mo13_mo23_cs33.mat"); % natural image cdfs
elseif filter == 1
  load("cdfs_abr_mo13_mo23_cs33_otf.mat"); % natural image cdfs
end
%
% power spectrum
b0 = 16;                 % weak Fourier power suppression parameter 
%
% load bin bounds, 0=HE, 2=AHE-F, 3=AHE-B, 4=AHE-B&F
b = 5; % bound type: 5 = natural images, 4 = Brodatz & Fabric**************
cstat = [b,0,0,0,b,b,b,0,b,b,b,0,b,b,0,0,0,0,0,0]; % natural images
[nb,bb] = mk_bb(cstat,levb,filter);
flist = [1,0,0,0,1,1,1,0,1,1,1,0,1,1,0,0,0,0,0,0];
ne = [5,7,9,10]; % edge features to use************************************
nh = [1,13,14];  % spot features to use************************************
% 
% edge parameters
thresh = 50;            % gradient threshold
sdg = 1;                % derivative of gaussian sd in pixels
nsdg = 3;               % kernel width in gaussian sd (~= sobal)
sdg2 = 1;               % 2nd derivative of gaussian sd in pixels
nsdg2 = 3;              % kernel width in gaussian sd
%
fun_level = 0;
%
% load patch pairs
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
% response storage same
rps = zeros(pcnt,1); rhs = zeros(pcnt,1); rbs = zeros(pcnt,1);
res = zeros(pcnt,1); rcs = zeros(pcnt,1);
rh1s = zeros(pcnt,1); rh2s = zeros(pcnt,1); rh3s = zeros(pcnt,1);
rb1s = zeros(pcnt,1); rb2s = zeros(pcnt,1);
re1s = zeros(pcnt,1); re3s = zeros(pcnt,1); re4s = zeros(pcnt,1);
%
% response storage different
rpd = zeros(pcnt,1); rhd = zeros(pcnt,1); rbd = zeros(pcnt,1);
red = zeros(pcnt,1); rcd = zeros(pcnt,1);
rh1d = zeros(pcnt,1); rh2d = zeros(pcnt,1); rh3d = zeros(pcnt,1);
rb1d = zeros(pcnt,1); rb2d = zeros(pcnt,1);
re1d = zeros(pcnt,1); re3d = zeros(pcnt,1); re4d = zeros(pcnt,1);
rbcs = zeros(pcnt,1); rbcd = zeros(pcnt,1);
%
% far/diff feature responses***********************************************
nd = 0; n0d = 0;
for i = 1:pcnt 
  ptch1 = ptchf(1:psz,1:psz,1:ncolr,i);
  [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means     
  ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
  ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge
%  
  ptch2 = ptchf(1:psz,psz+1:psz2,1:ncolr,i);  
  [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means     
  ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates 
  ptch2a = ptch2(:,:,1); % grayscale patches for border,power,edge
% power
  Rpout = Rp(ptch1a,ptch2a,b0,psz);
  rpd0 = log(Rpout);
% spot      
  Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
  rh1d0 = log(Rhout(nh(1))); rh2d0 = log(Rhout(nh(2)));
  rh3d0 = log(Rhout(nh(3)));  
% contrast normalize     
  if cnorm == 1 
    ptch1a = cntrst_norm(ptch1a,c0,psz);
    ptch2a = cntrst_norm(ptch2a,c0,psz);
  end
% border
  Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
  rb1d0 = Rbout(1); rb2d0 = Rbout(2);
% edge
  Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
  re1d0 = log(Reout(ne(1))); re3d0 = log(Reout(ne(3)));
  re4d0 = log(Reout(ne(4)));
%
% check for extreme outliers and store clean responses
  if (rh1d0 > mnv) && (rh2d0 > mnv) && (rh3d0 > mnv) && ...
     (re1d0 > mnv) && (re3d0 > mnv) && (re4d0 > mnv) && (rpd0 > mnv) && ...
     (rh1d0 < mxv) && (rh2d0 < mxv) && (rh3d0 < mxv) && ...
     (re1d0 < mxv) && (re3d0 < mxv) && (re4d0 < mxv) && (rpd0 < mxv)
      nd = nd+1;
      rh1d(nd) = rh1d0; rh2d(nd) = rh2d0; rh3d(nd) = rh3d0;
      re1d(nd) = re1d0; re3d(nd) = re3d0; re4d(nd) = re4d0; 
      rpd(nd) = rpd0; rb1d(nd) = rb1d0; rb2d(nd) = rb2d0;
  else
      n0d = n0d+1;  
  end  

end
%
% near/same feature responses**********************************************
ns = 0; n0s = 0;
for i = 1:pcnt
  ptch1 = ptchn(1:psz,1:psz,1:ncolr,i);
  [ptch1,~] = ptch_norm(ptch1,m0,c0,ntype,ncolr); % norm patch & means     
  ptch1 = rot(ptch1,coeff,psz);   % transform to abr coordinates 
  ptch1a = ptch1(:,:,1); % grayscale patches for border,power,edge
%  
  ptch2 = ptchn(1:psz,psz+1:psz2,1:ncolr,i);  
  [ptch2,~] = ptch_norm(ptch2,m0,c0,ntype,ncolr); % norm patch & means     
  ptch2 = rot(ptch2,coeff,psz);   % transform to abr coordinates 
  ptch2a = ptch2(:,:,1); % grayscale patches for border,power,edge
% power
  Rpout = Rp(ptch1a,ptch2a,b0,psz);
  rps0 = log(Rpout);
% spot      
  Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist);
  rh1s0 = log(Rhout(nh(1))); rh2s0 = log(Rhout(nh(2)));
  rh3s0 = log(Rhout(nh(3)));
% contrast normalize     
  if cnorm == 1 
    ptch1a = cntrst_norm(ptch1a,c0,psz);
    ptch2a = cntrst_norm(ptch2a,c0,psz);
  end
% border
  Rbout = Rb(ptch1a,ptch2a,psz,dir,sdg,nsdg,showflag);
  rb1s0 = Rbout(1); rb2s0 = Rbout(2);  
% edge
  Reout = Re(ptch1a,ptch2a,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist);
  re1s0 = log(Reout(ne(1))); re3s0 = log(Reout(ne(3)));
  re4s0 = log(Reout(ne(4)));
%
% check for extreme outliers and store clean responses
  if (rh1s0 > mnv) && (rh2s0 > mnv) && (rh3s0 > mnv) && ...
     (re1s0 > mnv) && (re3s0 > mnv) && (re4s0 > mnv) && (rps0 > mnv) && ...
     (rh1s0 < mxv) && (rh2s0 < mxv) && (rh3s0 < mxv) && ...
     (re1s0 < mxv) && (re3s0 < mxv) && (re4s0 < mxv) && (rps0 < mxv)
    ns = ns+1;
    rh1s(ns) = rh1s0; rh2s(ns) = rh2s0; rh3s(ns) = rh3s0;
    re1s(ns) = re1s0; re3s(ns) = re3s0; re4s(ns) = re4s0; 
    rps(ns) = rps0; rb1s(ns) = rb1s0; rb2s(ns) = rb2s0;
  else
    n0s = n0s+1;  
  end  
end
%
% spot****************************************
resultsh =  classify_normals([rh1s(1:ns),rh2s(1:ns),rh3s(1:ns)],...
    [rh1d(1:nd),rh2d(1:nd),rh3d(1:nd)],'input_type','samp','plotmode',0);
dbndh = resultsh.samp_opt_bd;  % sample-optimized bound
resultsh =  classify_normals([rh1s(1:ns),rh2s(1:ns),rh3s(1:ns)],...
    [rh1d(1:nd),rh2d(1:nd),rh3d(1:nd)],'input_type','samp','dom',dbndh,...
    'samp_opt',0);
% axis([-10 0 -6 6 -6 6]); axis square;
xlabel('a'); ylabel('cs small'); zlabel('cs large');
%
name = append('dbndhNO',num,'.mat');
if saveflg == 1
  save(name,"dbndh");
end
%
dvhfun=quad2fun(dbndh,fun_level); % decision-variable function
for i = 1:nd
    rhd(i) = dvhfun([rh1d(i),rh2d(i),rh3d(i)]');
end
for i = 1:ns
    rhs(i) = dvhfun([rh1s(i),rh2s(i),rh3s(i)]');
end
%
% edge****************************************
resultse =  classify_normals([re1s(1:ns),re3s(1:ns),re4s(1:ns)],...
    [re1d(1:nd),re3d(1:nd),re4d(1:nd)],'input_type','samp','plotmode',0);
dbnde = resultse.samp_opt_bd;  % sample-optimized bound
resultse =  classify_normals([re1s(1:ns),re3s(1:ns),re4s(1:ns)],...
    [re1d(1:nd),re3d(1:nd),re4d(1:nd)],'input_type','samp','dom',dbnde,...
    'samp_opt',0);
% axis([-10 0 -6 6 -6 6]); axis square;
xlabel('mag edge'); ylabel('mag bar'); zlabel('orien bar');
%
name = append('dbndeNO',num,'.mat');
if saveflg == 1
    save(name,"dbnde");
end
%
dvefun=quad2fun(dbnde,fun_level); % decision-variable function
for i = 1:nd
    red(i) = dvefun([re1d(i),re3d(i),re4d(i)]');
end
for i = 1:ns
    res(i) = dvefun([re1s(i),re3s(i),re4s(i)]');
end
%
% content: power, spot, & edge****************************************
resultsphe =  classify_normals([rps(1:ns),rhs(1:ns),res(1:ns)],...
    [rpd(1:nd),rhd(1:nd),red(1:nd)],'input_type','samp','plotmode',0);
dbndc = resultsphe.samp_opt_bd;  % sample-optimized bound
resultsphe =  classify_normals([rps(1:ns),rhs(1:ns),res(1:ns)],...
    [rpd(1:nd),rhd(1:nd),red(1:nd)],'input_type','samp','dom',dbndc,...
    'samp_opt',0);
axis([-10 0 -6 6 -6 6]); axis square;
xlabel('power'); ylabel('spot'); zlabel('edge');
%
name = append('dbndcNO',num,'.mat');
if saveflg == 1
    save(name,"dbndc");
end
%
dvcfun=quad2fun(dbndc,fun_level); % decision-variable function
for i = 1:nd
  rcd(i) = dvcfun([rpd(i),rhd(i),red(i)]');
end
for i = 1:ns
  rcs(i) = dvcfun([rps(i),rhs(i),res(i)]');
end
%
% border
resultsb =  classify_normals([rb1s(1:ns),rb2s(1:ns)],...
          [rb1d(1:nd),rb2d(1:nd)],'input_type','samp','plotmode',0);
dbndb = resultsb.samp_opt_bd;  % sample-optimized bound
resultsb =  classify_normals([rb1s(1:ns),rb2s(1:ns)],...
    [rb1d(1:nd),rb2d(1:nd)],'input_type','samp','dom',dbndb,'samp_opt',0);
axis normal
fontsize(14,'points');
xlabel('border edge'); ylabel('average edge');  %-1.44912666280213
name = append('dbndbNO',num,'.mat');
if saveflg == 1
    save(name,"dbndb");
end
%
dvbfun=quad2fun(dbndb,fun_level); % decision-variable function
for i = 1:nd
  rbd(i) = dvbfun([rb1d(i),rb2d(i)]');
end
for i = 1:ns
  rbs(i) = dvbfun([rb1s(i),rb2s(i)]');
end
%
% border and content
resultsbc =  classify_normals([rcs(1:ns),rbs(1:ns)],...
    [rcd(1:nd),rbd(1:nd)],'input_type','samp','plotmode',0);
dbndbc = resultsbc.samp_opt_bd;  % sample-optimized bound
resultsbc =  classify_normals([rcs(1:ns),rbs(1:ns)],...
    [rcd(1:nd),rbd(1:nd)],'input_type','samp','dom',dbndbc,'samp_opt',0);
axis normal
fontsize(14,'points');
xlabel border
ylabel content  
name = append('dbndbcNO',num,'.mat');
if saveflg == 1
    save(name,"dbndbc");
end
dvbcfun=quad2fun(dbndbc,fun_level); % decision-variable function
%
% bc decision variable 
for i = 1:nd
  rbcd(i) = dvbcfun([rcd(i),rbd(i)]');
end
for i = 1:ns
  rbcs(i) = dvbcfun([rcs(i),rbs(i)]');
end
figure; hold on;
histogram(rbcs,'BinWidth',0.4);
histogram(rbcd,'BinWidth',0.4);
done = 1;