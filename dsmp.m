function imgout = dsmp(imgin,lev,ncolr)
%
% downsample image
%
% imgin = input image (double)
% lev = power of two of downsampling (0, 2, 4, 8, 16)
% ncolr = number of color channels
imgout = imgin;
%
% apply 3 x 3 gaussian kernals and downsample
kern = [1/16 1/8 1/16; 1/8 1/4 1/8; 1/16 1/8 1/16];
if lev >= 1 % no downsample
    imgout = imgin;
end
%
if lev >= 2 % factor of 2
  if ncolr == 1
    imgout = conv2(imgout,kern,'same');    
    imgout = imresize(imgout,0.5,'nearest');
  else
    imin1 = imgout(:,:,1);
    imout1 = conv2(imin1,kern,'same');
    imout1 = imresize(imout1,0.5,'nearest');
    imin2 = imgout(:,:,2);
    imout2 = conv2(imin2,kern,'same');
    imout2 = imresize(imout2,0.5,'nearest');
    imin3 = imgout(:,:,3);
    imout3 = conv2(imin3,kern,'same');
    imout3 = imresize(imout3,0.5,'nearest');
    imgout = imresize(imgout,0.5,'nearest');    
    imgout(:,:,1) = imout1;
    imgout(:,:,2) = imout2;
    imgout(:,:,3) = imout3;      
  end
end
%
if lev >= 4 % factor of 4
  if ncolr == 1
    imgout = conv2(imgout,kern,'same');    
    imgout = imresize(imgout,0.5,'nearest');
  else
    imin1 = imgout(:,:,1);
    imout1 = conv2(imin1,kern,'same');
    imout1 = imresize(imout1,0.5,'nearest');
    imin2 = imgout(:,:,2);
    imout2 = conv2(imin2,kern,'same');
    imout2 = imresize(imout2,0.5,'nearest');
    imin3 = imgout(:,:,3);
    imout3 = conv2(imin3,kern,'same');
    imout3 = imresize(imout3,0.5,'nearest');
    imgout = imresize(imgout,0.5,'nearest');    
    imgout(:,:,1) = imout1;
    imgout(:,:,2) = imout2;
    imgout(:,:,3) = imout3;            
  end
end
%
if lev >= 8 % factor of 8
  if ncolr == 1
    imgout = conv2(imgout,kern,'same');    
    imgout = imresize(imgout,0.5,'nearest');
  else
    imin1 = imgout(:,:,1);
    imout1 = conv2(imin1,kern,'same');
    imout1 = imresize(imout1,0.5,'nearest');
    imin2 = imgout(:,:,2);
    imout2 = conv2(imin2,kern,'same');
    imout2 = imresize(imout2,0.5,'nearest');
    imin3 = imgout(:,:,3);
    imout3 = conv2(imin3,kern,'same');
    imout3 = imresize(imout3,0.5,'nearest');
    imgout = imresize(imgout,0.5,'nearest');    
    imgout(:,:,1) = imout1;
    imgout(:,:,2) = imout2;
    imgout(:,:,3) = imout3;      
  end
end
%
if lev >= 16 % factor of 16
  if ncolr == 1
    imgout = conv2(imgout,kern,'same');    
    imgout = imresize(imgout,0.5,'nearest');
  else
    imin1 = imgout(:,:,1);
    imout1 = conv2(imin1,kern,'same');
    imout1 = imresize(imout1,0.5,'nearest');
    imin2 = imgout(:,:,2);
    imout2 = conv2(imin2,kern,'same');
    imout2 = imresize(imout2,0.5,'nearest');
    imin3 = imgout(:,:,3);
    imout3 = conv2(imin3,kern,'same');
    imout3 = imresize(imout3,0.5,'nearest');
    imgout = imresize(imgout,0.5,'nearest');    
    imgout(:,:,1) = imout1;
    imgout(:,:,2) = imout2;
    imgout(:,:,3) = imout3;      
  end
end
%
end
