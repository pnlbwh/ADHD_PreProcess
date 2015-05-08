function EpiCorrection(case_path, recreate)

pattern = 'dwi_[0-9]*-Ed.nhdr';
% warning('pattern modified for debugging')
% pattern = 'dwi_[0-9]*.nhdr';
diff_path = fullfile(case_path, 'diff/');
count = CountFileFromRegex(diff_path, pattern);

if (count < 1)
    disp('ERROR 114: No diffusion volume with Eddy Current correction found in diff/ folder');
    disp(['Case: ' case_path]);
    return;
    
elseif (count > 1)
    disp('Multiple diffusion volumes with Eddy Current correction found in diff/ ');
    disp(['Case: ' case_path]);
    disp('Processing the last one only');
end

scan_index=count;

% SEE***
output_file_name = ['dwi_' int2str(scan_index) '-Ed-Epi.nhdr'];

if exist(fullfile(diff_path, output_file_name), 'file') && (recreate == 0)
    disp('=== INFO 113 ===');
    disp(['EPI correction already performed for scan ' int2str(scan_index)]);
    disp(['In case: ' case_path]);
    return;
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

tmp_path = fullfile(case_path, 'tmp/');
input_dwi_name = ['dwi_' int2str(scan_index) '-Ed.nhdr'];
input_dwi_path = fullfile(diff_path, input_dwi_name);
baseline = fullfile(diff_path, ['dwi_' int2str(scan_index) '-Ed-B0.nrrd']);
baseline_masked = fullfile(diff_path, ['dwi_' int2str(scan_index) '-Ed-B0-Bet.nrrd']);
mask = fullfile(diff_path, ['dwi_' int2str(scan_index) '-Ed-Mask.nrrd']);

slice_nii_path = fullfile(tmp_path, 'slice.nii.gz');
mask_nii = fullfile(tmp_path, 'mask.nii.gz');
mask_mask_nii = fullfile(tmp_path, 'mask_mask.nii.gz'); % bet appends '_mask'


% Example: s4 --launch DiffusionWeightedVolumeMasking 
% --otsuomegathreshold 0.9
% /projects/schiz/ADHD/case101/diff/dwi_1-Ed.nhdr (input)
% /projects/schiz/ADHD/case101/diff/dwi_1-Ed-B0.nrrd (output baseline)
% /projects/schiz/ADHD/case101/diff/dwi_1-Ed-Mask.nrrd (output mask)

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% First possibility -> use DWVolumeMasking -> Bad results
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

software = 's4 --launch DiffusionWeightedVolumeMasking --otsuomegathreshold 0.9';
command = [software ' ' input_dwi_path ' ' baseline ' ' mask ' ' ];

%system(command);

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Second possibility -> Bet -> Good results, but more processing
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Diffusion Data
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

    % Idea: extract slice [baseline image] -> nii -> bet (-f 0.3) -> nrrd
    % use unu 2op to apply mask
    % use unu slice to extract slice

    % Extract baseline volume
    software = 'unu slice -a 3 -p 0 -i ';
    command = [software input_dwi_path ' -o ' baseline];
    system(command);

    % Convert it to nifti
    software = 'ConvertBetweenFileFormats ';
    command = [software baseline ' ' slice_nii_path];
    system(command);

    % BET (Brain Extraction Tool)
    % -m = generate binary mask
    % (-n = don't generate segmented brain image output)
    % -f = fractional intensity threshold
    software = 'bet ';
    command = [software slice_nii_path ' ' mask_nii ' -m -f 0.3'];
    system(command);

    % Convert mask from nifti to nrrd
    software = 'ConvertBetweenFileFormats ';
    command = [software mask_mask_nii ' ' mask];
    system(command);
    
    % Convert Baseline masked from nifti to nrrd
    software = 'ConvertBetweenFileFormats ';
    command = [software mask_nii ' ' baseline_masked];
    system(command);

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% T2 Data
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

    pattern = 'T2_[0-9]+.nrrd';
    t2_path = fullfile(case_path, 'T2/');
    count = CountFileFromRegex(t2_path, pattern);

    if (count < 1)
        disp('ERROR 114: No T2 Volume found in T2/ folder');
        disp(['Case: ' case_path]);

    elseif (count > 1)
        disp('Multiple T2 volumes found in T2/ ');
        disp(['Case: ' case_path]);
        disp('Processing the last one only');
    end

    scan_index=count;

    % SEE***
    output_t2 = ['T2_' int2str(scan_index) '-Bet.nrrd'];
    output_t2_path = fullfile(case_path, 'T2/', output_t2);
    output_t2_nii = fullfile(tmp_path, strrep(output_t2, '.nrrd', '.nii.gz'));

    input_t2 = ['T2_' int2str(scan_index) '.nrrd'];
    input_t2_path = fullfile(t2_path, input_t2);
    input_t2_nii = fullfile(tmp_path, strrep(input_t2, '.nrrd', '.nii.gz'));

    output_mask = ['T2_' int2str(scan_index) '-Mask.nrrd'];
    output_mask_path = fullfile(case_path, 'T2/', output_mask);
    output_mask_nii = fullfile(tmp_path, ['T2_' int2str(scan_index) '-Bet_mask.nii.gz']);

    % Convert to Nifti
    command = ['ConvertBetweenFileFormats ' input_t2_path ' ' input_t2_nii];
    system(command);

    % Bet T2
    % if you want to ouput the mask, put the -m flag at the end
    command = ['bet ' input_t2_nii ' ' output_t2_nii ' -f 0.3 -m -R'];
    system(command);

    % Convert T2 masked back to NRRD
    command = ['ConvertBetweenFileFormats ' output_t2_nii ' ' output_t2_path];
    system(command);

    % Convert T2 Mask to NRRD
    command = ['ConvertBetweenFileFormats ' output_mask_nii ' ' output_mask_path];
    system(command);



% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% EPI script
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

    % ORIGINAL EPI SCRIPT -> T2 => DWI fails, too hard to debug because too hard to read bash scripts...
    output_dwi_epi_path = fullfile(diff_path, ['dwi_' int2str(scan_index) '-Ed-Epi.nhdr']);
    % -d (debug) -f (fast)  flags for debugging
    warning('EPI debug mode is enabled, fast registration used, and custom epi.sh script used!');
    command = ['/projects/schiz/ra/ccarquex/ADHD_PreProcess/epi.sh -d -f ' input_dwi_path ' ' mask ' ' output_t2_path ' ' output_dwi_epi_path];
%     system(command);



% STEP 1: T2 => DWI with an affine transformation

    % ${ANTSPATH}/ANTS 3 -m $METRIC[$fixed,$moving,1,32] -i 0 -o $pre --rigid-affine true
    ANTSPATH = getenv('ANTSPATH');
    ants_bin = fullfile(ANTSPATH, 'ANTS');
    ants_warp = fullfile(ANTSPATH, 'WarpImageMultiTransform');
    
        
    if strcmp(ANTSPATH, '')
        disp('= ERROR 201 =');
        disp('Variable $ANTSPATH is not set');
    end

    output_tranformation_T2_to_DWI = fullfile(tmp_path, 'T2-to-DWI');
    
    command = [ants_bin ' 3 -m MI[' baseline_masked ', ' output_t2_path ', 1, 32] -i 0 -o ' output_tranformation_T2_to_DWI ' --rigid-affine true']; %--rigid-affine true
    system(command);
    
%   WarpImageMultiTransform 2 b.img bwarp.img -R a.img abWarp.nii abAffine.txt
%   (b -> a)
    t2_in_dwi_space = fullfile(tmp_path, 't2_in_dwi_space.nrrd');
    command = [ants_warp ' 3 ' output_t2_path ' ' t2_in_dwi_space ' -R ' baseline_masked ' ' output_tranformation_T2_to_DWI 'Affine.txt'];
    system(command);

% STEP 2: DWI => T2 with a geodesic dipheomorphism along the phase
% direction
    
    %    run $ANTSPATH/ANTS 3 -m CC[$fixed,$moving,1,5] -i 50x20x10 -r Gauss[3,0] -t SyN[1] -o $pre --Restrict-Deformation 0x1x0
    output_tranformation_DWI_to_T2 = fullfile(tmp_path, 'DWI-to-T2');
    command = [ants_bin ' 3 -m CC[' t2_in_dwi_space ', ' baseline_masked ', 1, 5] -i 50x20x10 -r Gauss[3,0] -t SyN[1] -o ' output_tranformation_DWI_to_T2 ' --Restrict-Deformation 0x1x0 --rigid-affine true'];
    system(command);
    
%     WarpImageMultiTransform 2 b.img bwarp.img -R a.img abWarp.nii abAffine.txt
    output_dwi_baseline_epi_path = fullfile(diff_path, ['dwi_' int2str(scan_index) '-Ed-Epi-B0.nrrd']);
    command = [ants_warp ' 3 ' baseline_masked ' ' output_dwi_baseline_epi_path ' -R ' t2_in_dwi_space ' ' output_tranformation_DWI_to_T2 'Warp.nii.gz ' output_tranformation_DWI_to_T2 'Affine.txt'];
    system(command);
  
%     Use NN for Warp ?
    
% SEE*** rm the tmp directory and 

% Clean
command = ['rm -r ' tmp_path];
%system(command);



























end
