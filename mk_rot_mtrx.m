%
% mk_rot_mtrx.m
%
clearvars; close all;
%
addpath(['C:\Users\Bill Geisler\Documents\Projects\Texture\Images' ...
        '\CPS Set-9-10-12_16-bit linear']);
%
% ntype: 0 = none 1 = mean, 2 = mean and contrast, 3 = average mean
% ncolr = number of color channels (1 or 3)
%
cnorm = 1; lmsflg = 1; % cnorm, and lms flag
m0 = 128; c0 = 0.25; ntype = 3; ncolr = 3; nsmp = 20;
psz = 64; nbins = 16000;
%
% optical filter
filter = 1;  % 1 = apply optical filter, 0 = no filter*********************
pd = 4;      % pupil diameter
w = 550;     % wavelength
ppd = 64;    % pixels per degree
mxval = 2^14 - 1;
%
% color
lmsmtrx = [4.370,1.338,0.118;6.984,8.373,-0.922;-1.096,-0.667,5.814];
%
nimg9 = 104; nimg10 = 90; nimg12 = 197;
mxx = zeros(nimg9+nimg10+nimg12,1); nmxx = 0;
szx = 2844; szy = 4284;
%
nrgb = (nimg9+nimg10+nimg12)*nsmp*psz^2;
rgb = zeros(nrgb,3); lms = zeros(nrgb,3); abr = zeros(nrgb,3);
n = 0;
% image set 9
  mxmx = 0;
for inum = 1:nimg9
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set9_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  nmxx = nmxx + 1; mxx(nmxx) = max(imgrgb,[],"all");    
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);
  end   
  % imgrgb = 255*imgrgb/max(imgrgb,[],'all');
  imglms = rgb2lms(imgrgb,lmsmtrx);
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    if lmsflg == 1
      ptch = imglms(x:x+psz-1,y:y+psz-1,:);
    else
      ptch = imgrgb(x:x+psz-1,y:y+psz-1,:);
    end
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % 
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
  end
end
for inum = 1:nimg10
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set10_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;
  nmxx = nmxx + 1; mxx(nmxx) = max(imgrgb,[],"all"); 
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);
  end     
  % imgrgb = 255*imgrgb/mxval; % scale to 0-255
  imglms = rgb2lms(imgrgb,lmsmtrx);
  % mlum = mean(mean(0.5*(imglms(:,:,1)+imglms(:,:,2))));
  % imglms = 128*imglms/mlum;
  % rgb values
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    if lmsflg == 1
      ptch = imglms(x:x+psz-1,y:y+psz-1,:);
    else
      ptch = imgrgb(x:x+psz-1,y:y+psz-1,:);
    end
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % 
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
  end
end
for inum = 1:nimg12
  num = num2str(inum);
  %
  % load rgb image
  name = append('Set12_16_',num,'.png');
  imgrgb = double(imread(name))*255/mxval;  
  nmxx = nmxx + 1; mxx(nmxx) = max(imgrgb,[],"all"); 
  if filter == 1
    imgrgb = aply_otf(imgrgb,ppd,pd,w);
  end     
  imglms = rgb2lms(imgrgb,lmsmtrx);
  for k = 1:nsmp
    x = randi(szx-psz); y = randi(szy-psz);
    if lmsflg == 1
      ptch = imglms(x:x+psz-1,y:y+psz-1,:);
    else
      ptch = imgrgb(x:x+psz-1,y:y+psz-1,:);
    end
    ptch = ptch_norm(ptch,m0,c0,ntype,ncolr); % 
    for i = 1:psz
      for j = 1:psz
        n = n+1;
        lms(n,:) = ptch(i,j,:);
      end
    end
  end
end
%
% lms histograms
%
figure;
tiledlayout(3,3);
nexttile
histogram(lms(1:n,1),FaceColor='red',EdgeColor = 'red');
axis([0 500 0 inf]);
xlabel('l');
nexttile
histogram(lms(1:n,2),FaceColor='green',EdgeColor = 'green');
axis([0 500 0 inf]);
xlabel('m');
nexttile
histogram(lms(1:n,3),FaceColor = 'blue',EdgeColor = 'blue');
axis([0 500 0 inf]);
xlabel('s');
%
% PCA to get transformation matrix
coeff = pca(lms);
if filter == 0
  save("PCA_matrix_3.mat","coeff");
elseif filter == 1
  save("PCA_matrix_3_OTF.mat","coeff");
end
%
for i = 1:n
  % abr(i,:) = coeff*lms(i,:)'; % incorrect multiplication
  abr(i,:) = lms(i,:)*coeff; % correct multiplicatoin
end
%
nexttile
histogram(abr(1:n,1),FaceColor='black',EdgeColor='black');
axis([0 511 0 inf]);
xlabel('a');
nexttile
histogram(abr(1:n,2),FaceColor='blue',EdgeColor='blue');
axis([-100 500 0 inf]);
xlabel('b');
nexttile
histogram(abr(1:n,3),FaceColor = 'red',EdgeColor = 'red');
axis([-100 500 0 inf]);
xlabel('s');
%
% cumulative channel responses
[Na,ea] = histcounts(abr(1:n,1),nbins,'Normalization','cdf');
[Nb,eb] = histcounts(abr(1:n,2),nbins,'Normalization','cdf');
[Nr,er] = histcounts(abr(1:n,3),nbins,'Normalization','cdf');
n0a = 1;
for i = 1:nbins-1
  if Nb(i) < 0.5 && Nb(i+1) > 0.5
    n0b = i;
  end    
  if Nr(i) < 0.5 && Nr(i+1) > 0.5
    n0r = i;
  end    
end   
dna = 1000;
dnb = 500;
dnr = 500;
nexttile
plot(ea(n0a:n0a+dna),Na(n0a:n0a+dna),"black");
xlabel('a'); ylabel('pr');
nexttile
plot(eb(n0b-dnb:n0b+dnb),Nb(n0b-dnb:n0b+dnb),"blue");
xlabel('b'); ylabel('pr');
nexttile
plot(er(n0r-dnr:n0r+dnr),Nr(n0r-dnr:n0r+dnr),"red");
xlabel('s'); ylabel('pr');
fontsize(12,'points');
