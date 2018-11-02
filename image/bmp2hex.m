imdata = imread('kodim23.bmp'); % 24-bit BMP image RGB888 

tmp=1:768*512*3;
m = 1;
for i=1:512
	for j=1:768
		for k = 1:3
			tmp(m)=imdata(i,j,k);
			m = m+1;
		end
	end
end

fid = fopen('kodim23.hex', 'wt');
fprintf(fid, '%x\n', tmp);
fclose(fid);

disp('Text file write done');
disp(' ');