function imgout = aply_otf(imgin,ppd,pd,w)
%
% apply otf to image
%
% imgin = input image (assumes even size, and width = height)
% ppd = pixels per degree
% pd = pupil diameter
% w = wavelength
%
imgout = imgin;
sz1 = size(imgin,1); sz2 = size(imgin,2);
ndim = size(imgin,3);
for k = 1:ndim
  img = imgin(:,:,k);  
  imgmn = mean(mean(img));
  img = img - imgmn;
  ftimg = fftshift(fft2(fftshift(img)));      % fft
  i0 = sz1/2+1; j0 = sz2/2 + 1; 
  for i = 1:sz1
    for j = 1:sz2
      u = sqrt((i-i0)^2 + (j-j0)^2)/ppd;
      ftimg(i,j) = ftimg(i,j)*otf(u,pd,w);
    end
  end
  img = ifftshift(ifft2(ifftshift(ftimg))) + imgmn; % inverse fft
  img = img + imgmn;
  imgout(:,:,k) = img;
end
%
end