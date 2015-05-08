function EddyCurrentCorrection_diffusion(case_path, recreate)


% File name example: file_name = 'dwi_1.nhdr';
pattern = 'dwi_[0-9]*.nhdr';
diff_path = fullfile(case_path, 'diff/');
count = CountFileFromRegex(diff_path, pattern);

if (count < 1)
    disp('ERROR 111: No diffusion volume found in diff/ folder');
    disp(['Case: ' case_path]);
    
elseif (count > 1)
    disp('Multiple diffusion volumes found in diff/ ');
    disp(['Case: ' case_path]);
    disp('Processing the last one only');
end

scan_index=count;

% SEE***
file_name_output = ['dwi_' int2str(scan_index) '-Ed'];

if exist(fullfile(diff_path, [file_name_output, '.nhdr']), 'file') && (recreate == 0)
    disp('=== INFO 113 ===');
    disp(['Eddy current correction already performed for scan ' int2str(scan_index)]);
    disp(['In case: ' case_path]);
    return;
end

file_name = ['dwi_' int2str(scan_index) '.nhdr'];

%dwi = loadNrrdStructureMultiB(fullfile(diff_path, file_name));
dwi = loadNrrdStructure(fullfile(diff_path, file_name));

dim=-1; %dimension along which to dice the diffusion volume (gradient direction)
for k=1:numel(dwi.kinds)
    if strcmp(dwi.kinds{k},'list')
        dim = k-1; %C style indexing
    end
end

% Create the temporary folder

[success, message, messageid] = mkdir(case_path, 'tmp');

if (success ~= 1)
    disp('= ERROR 100 =')
    disp(['Could not create directory < tmp > in < ' case_path ' >'])
    disp(message);
    disp(messageid);
    %exit();
end



%use unu to dice the nrrd volume

tmp_path = fullfile(case_path, 'tmp');
%cd(tmp_path);

dwi_path = fullfile(case_path, 'diff/', file_name);
dice_path = fullfile(case_path, 'tmp/', 'Diffusion-G');

command = sprintf('unu dice -i %s -a %d -o %s',dwi_path,dim, dice_path);
system(command);

% check that we have as many files as gradients number
files = dir(fullfile(case_path, 'tmp/Diffusion-G*.nrrd'));
assert(numel(files) == size(dwi.gradients,1));

% we use FSL flirt for eddy current correction
newGradients = dwi.gradients;


% Let's take the reference B0 as the first null gradient
index = 1;
while (dwi.bvalue(index) * norm(dwi.gradients(index,:)) ~= 0) && (index <= 70)
    index = index+1;
end

if (index > 70)
    disp('= ERROR 112 =');
    disp('No B0 gradient found');
    disp(['Case: ' case_path]);
%     return;
end



refb0File = fullfile(tmp_path, strrep(files(index).name,'nrrd','nii.gz'));
% disp(refb0File);
% pause();
nrrdFile = fullfile(tmp_path, files(index).name);
system(['ConvertBetweenFileFormats ' nrrdFile ' ' refb0File]);
last_input_matrix = '';

for j = 1:numel(files)
    
    % When we encouter the B0 image
    if (j == index)
        continue;
    end
    
    % Path to files
    nrrdFile = fullfile(tmp_path, files(j).name);
    niiFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','nii.gz'));
    matrixFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','txt'));
    
    % Convert NRRD -> NII
    system(['ConvertBetweenFileFormats ' nrrdFile ' ' niiFile]);
    
    % Diffusion images with B value > 2500 => we use the previous
    % transformation matrix. The B values are organized as follow: 
    %  1000, 2000, 3000, 1000, 2000, 3000, etc...

    bval = dwi.bvalue * norm(dwi.gradients(j,:));

    if (bval < 2500)
        command = ['flirt -interp sinc -in ' niiFile ' -ref ' refb0File ' -nosearch -o ' niiFile ' -omat ' matrixFile ' -paddingsize 1'];
        last_input_matrix = matrixFile;
        input_matrix = matrixFile;
        system(command);
    else
        %command = ['flirt -interp nearestneighbour -in ' niiFile ' -ref ' refb0File ' -applyxfm -init ' last_input_matrix ' -out ' niiFile];
        command = ['flirt -interp sinc -in ' niiFile ' -ref ' refb0File ' -applyxfm -init ' last_input_matrix ' -out ' niiFile]; % -sincwidth 3 -sincwindow blackman
        input_matrix = last_input_matrix;
        mrtx = load(input_matrix);
        mrtx = mrtx(1:3,1:3);
        %if transform not identity, then apply it.
        if ((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
                system(command);
        end
    end

    
    
    newGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
end

% refb0 = strrep(files(i).name,'nrrd','nii.gz');
% system(['magicScalarFileConvert ' files(i).name ' ' refb0]);
% for j=1:numel(files)
%   niiFile = strrep(files(j).name,'nrrd','nii.gz');
%   fn_ = strrep(files(j).name,'nrrd','txt');
%   system(['magicScalarFileConvert ' files(j).name ' ' niiFile]);
%   if j == i %use as reference B0
%       refb0 = niiFile;
%   else
%     bval = dwi.bvalue * norm(dwi.gradients(j,:));
%     if bval < 2500
%         %system(['flirt -interp sinc -sincwidth 7 -sincwindow blackman -in ' niiFile ' -ref ' refb0 ' -nosearch -o ' niiFile ' -omat ' fn_ ' -paddingsize 1']);
%         system(['flirt -interp nearestneighbour -in ' niiFile ' -ref ' refb0 ' -nosearch -o ' niiFile ' -omat ' fn_ ' -paddingsize 1']);
%         %system(['flirt -in ' niiFile ' -ref ' refb0 ' -nosearch -o ' niiFile ' -omat ' fn_ ' -paddingsize 1']);
%         input_matrix = fn_;
%     else %for b>=3000
%         mrtx = load(input_matrix);
%         mrtx = mrtx(1:3,1:3);
%         %if transform not identity, then apply it.
%         if ((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
%             system(['flirt -interp sinc -sincwidth 3 -sincwindow blackman -in ' niiFile ' -ref ' refb0 ' -applyxfm -init ' input_matrix ' -out ' niiFile]);
%             %system(['flirt -in ' niiFile ' -ref ' refb0 ' -applyxfm -init ' input_matrix ' -out ' niiFile]);
%         end
%       
%     end
%     newGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
%   end
% 
% end

%now convert back to nrrd and merge
fprintf('Merging to create the NRRD file \n');

%first merge the nifti files - FSL merge 
zipedNiiFile = fullfile(tmp_path,'*.nii.gz');
system(['gunzip ' zipedNiiFile]);

clear files;
files = dir(fullfile(tmp_path, 'Diffusion-G*.nii')); %nifti files
assert(numel(files) == size(dwi.gradients,1));

% Get the parameters from the first nifti file
m = load_untouch_nii(fullfile(tmp_path,files(1).name));
sz = size(m.img);
N = numel(files);
data = uint16(zeros([sz N]));
for j=1:N
    m = load_untouch_nii(fullfile(tmp_path, files(j).name));
    % SEE ***
    disp('Number of negative values: ');
%     neg_val = nnz(m.img<0)
    
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


%remove temporary files
%system(['rm -r ' tmp_path]);



mat2DWInhdr(file_name_output,diff_path,dwi,'uint16');

end