function EddyCurrentCorrection_diffusion(case_path, recreate)

% % % 
% Count the number of 'raw' scans
% % % 

% File name example: file_name = 'dwi_1.nhdr';
pattern = 'dwi_[0-9]*.nhdr';
diff_path = fullfile(case_path, 'diff/');
count_scans = CountFileFromRegex(diff_path, pattern);

if (count_scans < 1)
    disp('ERROR 111: No diffusion volume found in diff/ folder');
    disp(['Case: ' case_path]);
    return;
    
elseif (count_scans > 1)
    disp('Multiple diffusion volumes found in diff/ ');
    disp(['Case: ' case_path]);
end

% % % 
% Count the number of QCed scans (by DTIPrep)
% % % 

pattern = 'dwi_[0-9]*_quality_control.txt';
count_process_files = CountFileFromRegex(diff_path, pattern);

if (count_scans ~= count_process_files)
    disp('ERROR: not all scans have been QCed by DTIPrep');
    disp(['Case: ' case_path]);
    return;
end

% % % 
% Which one is the best scan ?
% % % 

dwi_qc = zeros(70, count_scans);
best_scan = 1;
non_zero_gradients = -1;

for i=1:count_scans
   dwi_qc(:, i) = load(fullfile(diff_path, ['dwi_' int2str(i) '_quality_control.txt']));
   
   if (nnz(dwi_qc) > non_zero_gradients)
      best_scan = i; 
      non_zero_gradients = nnz(dwi_qc);
   end
end


% % % 
% Extract the reference B0
% % % 

index_best_scan=best_scan;

file_name = ['dwi_' int2str(index_best_scan) '.nhdr'];
input_file_path = fullfile(diff_path, file_name);

reference_b0_path = fullfile(diff_path, 'reference_b0.nrrd');
reference_b0_path_nii = strrep(reference_b0_path, 'nrrd', 'nii.gz');
dwi = loadNrrdStructure(input_file_path);

% Let's take the reference B0 as the first null gradient, with a good
% quality
index_B0 = 1;
while (dwi.bvalue * norm(dwi.gradients(index_B0,:)) ~= 0) || (dwi_qc(index_B0, index_best_scan) == 0) && (index_B0 <= 70)
    index_B0 = index_B0+1;
end

if (index_B0 > 70)
    disp('= ERROR 112 =');
    disp('No B0 gradient found');
    disp(['Case: ' case_path]);
    return;
end

% Extract the B0 slice
command = ['unu slice -a 3 -p ' int2str(index_B0 - 1) ' -i ' input_file_path ' -o ' reference_b0_path];
system(command);

% Convert it to nifti
command = ['ConvertBetweenFileFormats ' reference_b0_path ' ' reference_b0_path_nii];
system(command);

% % % 
% Now register the scans to the reference B0
% % % 


% Create the temporary folder

[success, message, messageid] = mkdir(case_path, 'tmp');

if (success ~= 1)
    disp('= ERROR 100 =')
    disp(['Could not create directory < tmp > in < ' case_path ' >'])
    disp(message);
    disp(messageid);
    return;
end

tmp_path = fullfile(case_path, '/tmp');

%%%
% Step 1. Register the good gradients, do not touch the bad ones, and
% recreate one NHDR file

% For each scan:
for scan_number=1:count_scans
   

    
    file_name = ['dwi_' int2str(scan_number) '.nhdr'];
    input_file_path = fullfile(diff_path, file_name);
    
    % We give the index of the B0 image only when we process the scan from
    % which it is extracted, -1 otherwise
    reference_b0_index = -1;
    if (scan_number == best_scan)
        reference_b0_index = index_B0;
    end
    
    output_file_name = ['dwi_' int2str(scan_number) '-Ed'];
    
    dwi_qc(:, scan_number) = RegisterScanToB0(reference_b0_path_nii, input_file_path, ...
                        output_file_name, diff_path, tmp_path, dwi_qc(:, scan_number), reference_b0_index);
                  
    % write the new dwi_qc variable
    volume_quality_array = zeros(70,1);
    volume_quality_array = dwi_qc(:, scan_number);
    save(fullfile(diff_path, ['dwi_' int2str(scan_number) '_quality_control.txt']), ...
                'volume_quality_array', '-ascii');
end

%%%
% Step 2. Merge into one file

    % A. How many gradients in total are we going to have? 
    % Let's apply the OR operator
merged_qc = zeros(70,1);
for i=1:count_scans
    merged_qc = merged_qc | dwi_qc(:, i);
end

number_of_gradients = nnz(merged_qc);

    % B. Now let's create the header of our final file
file_name = ['dwi_' int2str(index_best_scan) '.nhdr'];
input_file_path = fullfile(diff_path, file_name);
dwi = loadNrrdStructure(input_file_path);

sz = size(dwi.data);

diff_data.data = zeros(sz(1), sz(2), sz(3), count_scans);
diff_data.data(:, :, :, :, best_scan) = dwi.data;
diff_data.gradients = zeros(sz(4), 3, count_scans);

dwi.data = zeros(sz(1), sz(2), sz(3), number_of_gradients);
dwi.gradients = zeros(number_of_gradients, 3);

    % C. Let's fill out the .data and .gradients variable

% Load all the scans in memory
for i=1:count_scans
    
    % Previously loaded in Step 2, section B
    if (i == best_scan)
       continue; 
    end
    
    file_name = ['dwi_' int2str(i) '.nhdr'];
    input_file_path = fullfile(diff_path, file_name);
    
    tmp_dwi = loadNrrdStructure(input_file_path);
    diff_data.data(:, :, :, :, i) = tmp_dwi.data;
end

for gradient_direction=1:70
   if (merged_qc(gradient_direction) == 0) 
       continue;
   end
   
   % If the gradient is present in the "best scan", we take it from here
   if (dwi_qc(gradient_direction, best_scan) == 1)
       dwi.data(:, :, :, gradient_direction) = diff_data.data(:, :, :, gradient_direction, best_scan);
       dwi.gradients(gradient_direction, :) = diff_data.gradients(gradient_directon, :, best_scan);
       
   % Otherwise we take it from another volume
   else
        for k=1:count_scans
           if (k == best_scan) 
               continue;
           end
           
           if (dwi_qc(gradient_direction, k) == 0)
                continue;
           end
           
           % else, it mean the gradient is present in this k^th volume
           dwi.data(:, :, :, gradient_direction) = diff_data.data(:, :, :, gradient_direction, k);
           dwi.gradients() = diff_data.gradients(gradient_directon, :, k);
           
        end
   end
end

    % Finally, we write the file on the disk
clear diff_data;

output_file_name = 'dwi-Qc-Ed';
mat2DWInhdr(output_file_name, diff_path, dwi, 'uint16');

% file_name_output = ['dwi_' int2str(scan_index) '-Ed'];
% 
% 
% if exist(fullfile(diff_path, [file_name_output, '.nhdr']), 'file') && (recreate == 0)
%     disp('=== INFO 113 ===');
%     disp(['Eddy current correction already performed for scan ' int2str(scan_index)]);
%     disp(['In case: ' case_path]);
%     return;
% end
% 
% file_name = ['dwi_' int2str(scan_index) '.nhdr'];
% dwi = loadNrrdStructure(fullfile(diff_path, file_name));
% 
% dim=-1; %dimension along which to dice the diffusion volume (gradient direction)
% for k=1:numel(dwi.kinds)
%     if strcmp(dwi.kinds{k},'list')
%         dim = k-1; %C style indexing
%     end
% end
% 
% % Create the temporary folder
% 
% [success, message, messageid] = mkdir(case_path, 'tmp');
% 
% if (success ~= 1)
%     disp('= ERROR 100 =')
%     disp(['Could not create directory < tmp > in < ' case_path ' >'])
%     disp(message);
%     disp(messageid);
%     return;
% end
% 
% %use unu to dice the nrrd volume
% 
% tmp_path = fullfile(case_path, 'tmp');
% %cd(tmp_path);
% 
% dwi_path = fullfile(case_path, 'diff/', file_name);
% dice_path = fullfile(case_path, 'tmp/', 'Diffusion-G');
% 
% command = sprintf('unu dice -i %s -a %d -o %s',dwi_path,dim, dice_path);
% system(command);
% 
% % check that we have as many files as gradients number
% files = dir(fullfile(case_path, 'tmp/Diffusion-G*.nrrd'));
% assert(numel(files) == size(dwi.gradients,1));
% 
% % we use FSL flirt for eddy current correction
% newGradients = dwi.gradients;
% 
% 
% % Let's take the reference B0 as the first null gradient
% index = 1;
% while (dwi.bvalue(index) * norm(dwi.gradients(index,:)) ~= 0) && (index <= 70)
%     index = index+1;
% end
% 
% if (index > 70)
%     disp('= ERROR 112 =');
%     disp('No B0 gradient found');
%     disp(['Case: ' case_path]);
% %     return;
% end
% 
% 
% 
% refb0File = fullfile(tmp_path, strrep(files(index).name,'nrrd','nii.gz'));
% % disp(refb0File);
% % pause();
% nrrdFile = fullfile(tmp_path, files(index).name);
% system(['ConvertBetweenFileFormats ' nrrdFile ' ' refb0File]);
% last_input_matrix = '';
% 
% for j = 1:numel(files)
%     
%     % When we encouter the B0 image
%     if (j == index)
%         continue;
%     end
%     
%     % Path to files
%     nrrdFile = fullfile(tmp_path, files(j).name);
%     niiFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','nii.gz'));
%     matrixFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','txt'));
%     
%     % Convert NRRD -> NII
%     system(['ConvertBetweenFileFormats ' nrrdFile ' ' niiFile]);
%     
%     % Diffusion images with B value > 2500 => we use the previous
%     % transformation matrix. The B values are organized as follow: 
%     %  1000, 2000, 3000, 1000, 2000, 3000, etc...
% 
%     bval = dwi.bvalue * norm(dwi.gradients(j,:));
% 
%     if (bval < 2500)
%         command = ['flirt -interp sinc -in ' niiFile ' -ref ' refb0File ' -nosearch -o ' niiFile ' -omat ' matrixFile ' -paddingsize 1'];
%         last_input_matrix = matrixFile;
%         input_matrix = matrixFile;
%         system(command);
%     else
%         %command = ['flirt -interp nearestneighbour -in ' niiFile ' -ref ' refb0File ' -applyxfm -init ' last_input_matrix ' -out ' niiFile];
%         command = ['flirt -interp sinc -in ' niiFile ' -ref ' refb0File ' -applyxfm -init ' last_input_matrix ' -out ' niiFile]; % -sincwidth 3 -sincwindow blackman
%         input_matrix = last_input_matrix;
%         mrtx = load(input_matrix);
%         mrtx = mrtx(1:3,1:3);
%         %if transform not identity, then apply it.
%         if ((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
%                 system(command);
%         end
%     end
% 
%     
%     
%     newGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
% end
% 
% %now convert back to nrrd and merge
% fprintf('Merging to create the NRRD file \n');
% 
% %first merge the nifti files - FSL merge 
% zipedNiiFile = fullfile(tmp_path,'*.nii.gz');
% system(['gunzip ' zipedNiiFile]);
% 
% clear files;
% files = dir(fullfile(tmp_path, 'Diffusion-G*.nii')); %nifti files
% assert(numel(files) == size(dwi.gradients,1));
% 
% % Get the parameters from the first nifti file
% m = load_untouch_nii(fullfile(tmp_path,files(1).name));
% sz = size(m.img);
% N = numel(files);
% data = uint16(zeros([sz N]));
% for j=1:N
%     m = load_untouch_nii(fullfile(tmp_path, files(j).name));
%     % SEE ***
%     disp('Number of negative values: ');
% %     neg_val = nnz(m.img<0)
%     
%     m.img(m.img<0) = 0;
%     
%     switch dim
%         case 3, data(:,:,:,j) = m.img;
%         case 2, data(:,:,j,:) = m.img;
%         case 1, data(:,j,:,:) = m.img;
%         case 0, data(j,:,:,:) = m.img;
%     end
%     
% end   
% 
% dwi.data = data;
% dwi.gradients = newGradients;
% dwi.spacedirections = 2*eye(3).*sign(dwi.spacedirections);
% 
% 
% %remove temporary files
% %system(['rm -r ' tmp_path]);
% 
% 
% 
% mat2DWInhdr(file_name_output,diff_path,dwi,'uint16');

end