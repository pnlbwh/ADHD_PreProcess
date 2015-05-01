function DiffusionDicomToNrrdHesham( directoryName, caseDirName )
%Input
%directoryName -- base directory which has the dicom files (one directory
%lower than the actual dicom directory)

%caseDirName -- name where to store the file (e.g. case001)

%first convert the dicoms to nrrd without eddy current or any correction

%EDIT -- wild card for the dicom diffusion directory
fn = dir([directoryName '/*3She*']);
%
addpath('/projects/schiz/guest/kquintus/scripts/matlab/');

if isempty(fn)
    fprintf('No diffusion files found\n');
    return;
end

%make a diff directory
system(['mkdir ' caseDirName '/diff']);

%run standard converter
system(['DWIConvert -i ' fn(1).name ' -o ' caseDirName '/diff/dwi.nhdr']);

%load the file now
dwi = loadNrrdStructure([caseDirName '/diff/dwi.nhdr']);

dim=0; %dimension along which to dice the diffusion volume (gradient direction)
for k=1:numel(dwi.kinds)
    if strcmp(dwi.kinds{k},'list')
        dim = k-1; %C style indexing
    end
end

%use unu to dice the nrrd volume
cd(fn(1).name);
system(['mkdir tmp']);
cd('tmp');
cumand = sprintf('unu dice -i %s/diff/dwi.nhdr -a %d -o Diffusion-G',caseDirName,dim);
system(cumand);

files = dir('Diffusion-G*.nrrd');
assert(numel(files) == size(dwi.gradients,1));

fprintf('Run FSL flirt affine registration for eddy current correction\n');
newGradients = dwi.gradients;
id = [];

for j=1:numel(files)
  niiFile = strrep(files(j).name,'nrrd','nii.gz');
  fn_ = strrep(files(j).name,'nrrd','txt');
  system(['magicScalarFileConvert ' files(j).name ' ' niiFile]);
  if j == 1 %use as reference B0
      refb0 = niiFile;
  else
    bval = dwi.bvalue * norm(dwi.gradients(j,:))^2;
    if bval < 2500
        %system(['flirt -interp sinc -sincwidth 7 -sincwindow blackman -in ' niiFile ' -ref ' refb0 ' -nosearch -o ' niiFile ' -omat ' fn_ ' -paddingsize 1']);
        system(['flirt -in ' niiFile ' -ref ' refb0 ' -nosearch -o ' niiFile ' -omat ' fn_ ' -paddingsize 1']);
        input_matrix = fn_;
        id = [id; j];
    else %for b>=3000
        mrtx = load(input_matrix);
        mrtx = mrtx(1:3,1:3);
        %if transform not identity, then apply it.
        if ((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
            %system(['flirt -interp sinc -sincwidth 3 -sincwindow blackman -in ' niiFile ' -ref ' refb0 ' -applyxfm -init ' input_matrix ' -out ' niiFile]);
            system(['flirt -in ' niiFile ' -ref ' refb0 ' -applyxfm -init ' input_matrix ' -out ' niiFile]);
        end
      
    end
    newGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
  end

end

%now convert back to nrrd and merge
fprintf('Merging to create the NRRD file \n');
%first merge the nifti files - FSL merge 
system(['gunzip *.nii.gz']);
f = dir(['*Diffusion-G*.nii']); %nifti files
m = load_untouch_nii(f(1).name);
sz = size(m.img);
N = numel(f);
data = uint16(zeros([sz N]));
for j=1:N
    m = load_untouch_nii(f(j).name);
    m.img(m.img<0) = 0;
    switch dim
        case 3, data(:,:,:,j) = m.img;
        case 2, data(:,:,j,:) = m.img;
        case 1, data(:,j,:,:) = m.img;
        case 0, data(j,:,:,:) = m.img;
    end
    
end   

dwi.data = data;
dwi.gradients = newGradients;
dwi.spacedirections = 2*eye(3).*sign(dwi.spacedirections);

%now create a file for the low-b values
dwi_low = dwi;
dwi_low.data = data(:,:,:,id);
dwi_low.gradients = newGradients(id,:);

cd('../');
%remove temporary files
system('rm -r tmp');
cd([caseDirName '/diff']);
dn = pwd;
mat2DWInhdr('dwi-Ed',dn,dwi,'uint16');

mat2DWInhdr('dwi-Ed-lowB',dn,dwi_low,'unint16');

fprintf('done converting diffusion dicoms\n');






