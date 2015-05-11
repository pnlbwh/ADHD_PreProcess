function dwi_qc = RegisterScanToB0(reference_b0_path_nii, input_file_path, output_file_name, output_path, tmp_path, dwi_qc, reference_b0_index)


% % % 
% Note: when we merge the nii files, we do include the gradients marked as bad
% (they have not been registered), so that it's easier after to merge the
% NRRD scans into one final NRRD file.
% % % 

% % % 
% Check the dimension of dwi_qc
% % % 

if (size(dwi_qc, 2) > 1)
    disp('Error: required dimensions of dwi_qc: 70x1');
    return;
end

% % % 
% Pre-process the volume
% % % 

% Dice volume along the 4th (3 = 4 minus 1) direction
command = sprintf('unu dice -i %s -a %d -o %s',input_file_path, 3, dice_path);
system(command);


if exist(fullfile(diff_path, [output_file_path, '.nhdr']), 'file') && (recreate == 0)
    disp('=== INFO 113 ===');
    disp(['Eddy current correction already performed for scan ' int2str(scan_index)]);
    disp(['In case: ' case_path]);
    return;
end

% Load the file to process
dwi = loadNrrdStructure(input_file_path);
correctedGradients = dwi.gradients;

% check that we have as many files as gradients number
files = dir(fullfile(tmp_path, 'Diffusion-G*.nrrd'));
assert(numel(files) == size(dwi.gradients,1));



% % % 
% Register all the B<2500 images
% % % 

bval = zeros(size(dwi.gradients, 1));

for j = 1:numel(files)
    
    % When we encouter the B0 image
    if (j == reference_b0_index)
        continue;
    end
    
    % Path to files
    nrrdFile = fullfile(tmp_path, files(j).name);
    niiFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','nii.gz'));
    matrixFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','txt'));
    
    % Convert NRRD -> NII
    system(['ConvertBetweenFileFormats ' nrrdFile ' ' niiFile]);
    
    % if the gradient is marked as bad, we don't register it
    if (dwi_qc(j) == 0)
        continue;
    end

    
    % Diffusion images with B value > 2500 => we use the previous
    % transformation matrix. The B values are organized as follow: 
    %  1000, 2000, 3000, 1000, 2000, 3000, etc...

    bval(j) = dwi.bvalue * norm(dwi.gradients(j,:));

    if (bval(j) < 2500)
        warning('Let''s try MI as similarity measure...');
        command = ['flirt -interp sinc -in ' niiFile ' -ref ' reference_b0_path_nii ' -nosearch -o ' niiFile ' -omat ' matrixFile ' -paddingsize 1'];
        input_matrix = matrixFile;
        system(command);
    else   
          continue;
    end
    correctedGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
    
end

% % % 
% Now register all the B>3000 images
% % % 

% We have all the transformations, so we find to which image (with B<3000) our B3000 is
% the closest to


for j = 1:numel(files)
    
    % When we encouter the B0 image
    if (j == reference_b0_index)
        continue;
    end
    
    % if the gradient is marked as bad, we don't register it
    if (dwi_qc(j) == 0)
        continue;
    end


    
    % Path to files
    nrrdFile = fullfile(tmp_path, files(j).name);
    niiFile = fullfile(tmp_path, strrep(files(j).name,'nrrd','nii.gz'));

    if (bval(j) > 2500)
        
        % Find the two closest images, which are not B3000, before and
        % after this gradient
        
        [before, after] = FindClosestNonB300Gradient(dwi_qc, bval, j);
        
        index_to_register = -1;
        
        % If nothing found
        if (before == -1) && (after == -1)
           disp('WARNING: no B<2500 image found to register B>3000') ;
           disp(['Input file: ' input_file_path]);
           disp(['Index: ' j]);
           warning('For now, until further discussion, we just do not include this gradient');
           
           disp('Press any key to continue...');
           pause();
           
           % For now, maybe MI registration later ?
           dwi_qc(j) = 0;
           continue;
        end
        
        % If one found
        if (before == -1) || (after == -1)
            if (before == -1)
                index_to_register = after;
            else
                index_to_register = before;
            end
            
        % If two found    
        else
            % We have to find which one we are closest to, in term of
            % Normalized correlation

            
            dwi_before = dwi.data(:,:,:,before);
            dwi_after = dwi.data(:,:,:,after);
            dwi_current = dwi.data(:,:,:,j);
            
            NC_before = sum(dwi_before(:).*dwi_current(:))/sqrt(sum(dwi_before) * sum(dwi_after));
            NC_after = sum(dwi_after(:).*dwi_current(:))/sqrt(sum(dwi_after) * sum(dwi_after));
            
            if (NC_before >= NC_after)
               index_to_register = before; 
            else
               index_to_register = after; 
            end
            
            
            
            
        end
        input_matrix = fullfile(tmp_path, strrep(files(index_to_register).name,'nrrd','txt'));
        command = ['flirt -interp sinc -in ' niiFile ' -ref ' reference_b0_path_nii ' -applyxfm -init ' input_matrix ' -out ' niiFile];
        mrtx = load(input_matrix);
        mrtx = mrtx(1:3,1:3);
        
        %if transform not identity, then apply it.
        if ((det(mrtx) < 1-1e-5) || (det(mrtx) > 1+1e-5))
                system(command);
        end
        
    else   
          continue;
    end
    
    % Update the gradients    
    correctedGradients(j,:) = ApplyGradRotation(dwi.gradients(j,:)',input_matrix);
    
end



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
N = numel(files); % Number of gradients

% data = uint16(zeros([sz N]));
dwi.data = uint16(zeros([sz N]));

for j=1:N
   
    m = load_untouch_nii(fullfile(tmp_path, files(j).name));
    m.img(m.img<0) = 0;
%   data(:,:,:,j) = m.img;
    dwi.data(:,:,:,j) = m.img;

   
end   

% dwi.data = data;
dwi.gradients = correctedGradients;
dwi.spacedirections = 2*eye(3).*sign(dwi.spacedirections);


%remove temporary files
system(['rm -r ' tmp_path]);


% Write the output as a NHDR file
mat2DWInhdr(output_file_name, output_path, dwi, 'uint16');




end