function ConvertCaseToNrrd(caseDir, data_path, recreate)


dirName = {'raw'; 'diff'; 'fMRI'; 'T1'; 'T2'};

for i = 1:length(dirName)
    [success, message, messageid] = mkdir(fullfile(data_path, caseDir.name), cell2mat(dirName(i)));
    
    if (success ~= 1)
        disp('= ERROR 100 =')
        disp(['Could not create directory < ' cell2mat(dirName(i)) ' > in < ' fullfile(data_path, caseDir.name) ' >'])
        disp(message);
        disp(messageid);
        return;
    else
        disp(['Creating directory: ' cell2mat(dirName(i))]);
    end
end


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% For each scan
% Let's find the path to the dicom files
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

% STEP 1 => the date
% Example: 0_2014-08-22-11-32-26
pattern = '[0-9]_([0-9]+-)+[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name), pattern);

if (length(folder_list) < 1)
    disp('ERROR 101: No <date> folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

if (length(folder_list) > 1)
    disp('ERROR 102: Multiple <date> folder found - Longitudinal not supported yet')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

caseDir.date_folder = cell2mat(folder_list);

% STEP 2 => the patient number
% Examples: 4734849-843, 4045724-1267
pattern = '[0-9]+-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder), pattern);

if (length(folder_list) < 1)
    disp('ERROR 103: No 7-4 scan number folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

if (length(folder_list) > 1)
    disp('ERROR 104: Multiple 7-4 scan number folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

caseDir.patient_number = cell2mat(folder_list);

% STEP 3 => the main folder
% Example: 2014.07.01-009Y-MR_Functional_Imaging_Non_MD_60_Min-2105
pattern = '([0-9]+.)+[0-9]+-[0-9]+Y-[a-zA-Z_0-9]+-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number), pattern);

if (length(folder_list) < 1)
    disp('ERROR 105: No < main > folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

if (length(folder_list) > 1)
    disp('ERROR 106: Multiple < main > folders found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

caseDir.main_folder = cell2mat(folder_list);

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Now let's process the dicoms, according to their modality
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 


% STEP 4 => diffusion dicoms to NRRD
% Example: SMS2_DTI_3_shells-SMS2_DTI_3_shells-19131/

pattern = '(SMS2_DTI\w+)-(SMS2_DTI\w+)-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder), pattern);

if (length(folder_list) < 1)
    disp('ERROR 105: No diffusion scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end


for i = 1:length(folder_list)
   dicom_path = fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder, cell2mat(folder_list(i)));
   output_dir = fullfile(data_path, caseDir.name, '/diff/');
   volume_name = ['dwi_' int2str(i) '.nhdr'];
   
   if (~exist(fullfile(output_dir, volume_name), 'file')) || (recreate == 1)
        system(['DWIConvert --inputDicomDirectory ' dicom_path ' --outputDirectory ' output_dir ' --outputVolume ' volume_name]);
   else
        disp(['Diffusion volume: ' volume_name ' already converted']);
   end
end


% STEP 5 => T1 DICOMS to NRRD
% Example: WIPmocoMEMPRAGE_1mm_FOV_220_RMS-WIPmocoMEMPRAGE_1mm_FOV_220-19130

pattern = 'WIP\w+RMS-\w+-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder), pattern);

if (length(folder_list) < 1)
    disp('ERROR 106: No T1 scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

if (length(folder_list) > 1)
    disp('WARNING 107: Multiple T1 scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

for i = 1:length(folder_list)
   dicom_path = fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder, cell2mat(folder_list(i)));
   volume_name = ['T1_' int2str(i) '.nrrd'];
   output_name = fullfile(data_path, caseDir.name, '/T1/', volume_name);
   
   if (~exist(output_name, 'file')) || (recreate == 1)
        system(['ConvertBetweenFileFormats ' dicom_path ' ' output_name]);
   else
        disp(['T1 volume: ' volume_name ' already converted']);
   end
end


% STEP 6 => T2 DICOMS to NRRD
% Example: WIPmocoMEMPRAGE_1mm_FOV_220_RMS-WIPmocoMEMPRAGE_1mm_FOV_220-19130

pattern = 'T2.+-T2.+-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder), pattern);

if (length(folder_list) < 1)
    disp('ERROR 108: No T2 scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

if (length(folder_list) > 1)
    disp('WARNING 109: Multiple T2 scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

for i = 1:length(folder_list)
   dicom_path = fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder, cell2mat(folder_list(i)));
   volume_name = ['T2_' int2str(i) '.nrrd'];
   output_name = fullfile(data_path, caseDir.name, '/T2/', volume_name);
   
   if (~exist(output_name, 'file')) || (recreate == 1)
        system(['ConvertBetweenFileFormats ' dicom_path ' ' output_name]);
   else
        disp(['T2 volume: ' volume_name ' already converted']);
   end
end

% STEP 8 => fMRI DICOMS to NRRD (Motion Correction Series)
% Example: MoCoSeries-SMS3_rs_fMRI-19133

pattern = 'MoCo.*-.*fMRI.*-[0-9]+';

folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder), pattern);

if (length(folder_list) < 1)
    pattern = '.*-.*fMRI.*-[0-9]+';
    folder_list = FindFolderFromRegex(fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder), pattern);
end

if (length(folder_list) < 1)
    disp('ERROR 109: No MoCo / SMS3 fMRI scan folder found')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    return;
end

if (length(folder_list) > 1)
    disp('WARNING 110: Multiple MoCo / SMS3 fMRI scan folder found - only the first one will be processed')
    disp(['Case: ', caseDir.name, ' in ', data_path]);
    %exit();
end

for i = 1:1 %length(folder_list)
   dicom_path = fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder, cell2mat(folder_list(i)));
   volume_name = ['fMRI_' int2str(i)]; % extension is given by the function
   output_dir = fullfile(data_path, caseDir.name, '/fMRI/');
  
   if (~exist(fullfile(output_dir, [volume_name, '.nhdr']), 'file')) || (recreate == 1)
        ConvertfMRIDicomToNrrd(output_dir, volume_name, dicom_path)
   else
        disp(['fMRI volume: ' volume_name '.nhdr already converted']);
   end
end


% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Cleaning
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

% STEP 9 => zip everything and put it in the raw folder, then remove the
% files

dicom_path = fullfile(data_path, caseDir.name, caseDir.date_folder, caseDir.patient_number, caseDir.main_folder);
archive_path = fullfile(data_path, caseDir.name, 'raw', 'archive.tar');

if (~exist(archive_path, 'file')) || (recreate == 1)
    system(['tar -cf ' archive_path ' ' dicom_path])
else
        disp(['archive volume: archive.tar already converted']);
end

% UNCOMMENT BELOW TO REMOVE THE DICOMS AND KEEP ONLY THE ARCHIVE

% original_folder = fullfile(data_path, caseDir.name, caseDir.date_folder);
% system(['#rm -r ' original_folder])


end