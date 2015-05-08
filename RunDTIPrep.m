function RunDTIPrep(case_path, recreate, protocol_path)

DTIPrep_path = '/projects/schiz/software/DTIPrepPackage/DTIPrep';

% % % 
% Check that the files exists
% % % 

if ~exist(protocol_path, 'file')
    disp('ERROR 202: No protocol found in common_files/ folder');
    disp(['Case: ' case_path]);
    return;
end

% File name example: file_name = 'dwi_1.nhdr';
pattern = 'dwi_[0-9]*.nhdr';
diff_path = fullfile(case_path, 'diff/');
count = CountFileFromRegex(diff_path, pattern);

if (count < 1)
    disp('ERROR 111: No diffusion volume found in diff/ folder');
    disp(['Case: ' case_path]);
    return;
    
elseif (count > 1)
    disp('Multiple diffusion volumes found in diff/ ');
    disp(['Case: ' case_path]);
%     disp('Processing the last one only');
end

for scan_index=1:1 %count


    input_dwi_name = ['dwi_' int2str(scan_index) '.nhdr'];
    input_dwi_path = fullfile(diff_path, input_dwi_name);

    % % % 
    % Create the results directory
    % % % 

    output_dir_name = 'DTIPrep_results'; 
    [success, message, messageid] = mkdir(diff_path, output_dir_name);

    if (success ~= 1)
        disp('= ERROR 100 =')
        disp(['Could not create directory < DTIPrep_results > for < ' case_path ' >'])
        disp(message);
        disp(messageid);
        return;
    end

    output_folder = fullfile(diff_path, output_dir_name);

    % % % 
    % Run DTIPrep according to the protocol file
    % % % 

    command = [DTIPrep_path ' --DWINrrdFile ' input_dwi_path ' --xmlProtocol ' protocol_path ' --check --outputFolder ' output_folder];
    system(command);

    % % % 
    % Parse the results
    % % % 

    xml_results_name = ['dwi_' int2str(scan_index) '_XMLQCResult.xml'];
    xml_results_path = fullfile(output_folder, xml_results_name);

    if ~exist(xml_results_path, 'file')
        disp(['ERROR 203: No xml result file found at: ' xml_results_path]);
        return;
    end


    xRoot = xml2struct(xml_results_path);

    if (length(xRoot.QCResultSettings.entry) < 3) || (length(xRoot.QCResultSettings.entry{3}.entry) ~= 73)
        disp(['ERROR while reading the XML result file: ' xml_results_path]);
        disp('Wrong number of entries')
        return;
    end

    volume_quality_array = zeros(70);

    for i=4:73
        result = xRoot.QCResultSettings.entry{3}.entry{i}.processing.Text;
        if (strcmp(result, 'INCLUDE'))
            volume_quality_array(i-3) = 1;    
        else
            volume_quality_array(i-3) = 0;
        end    
    end

    % % % 
    % Save the results
    % % % 

    output_result_matrix_name = ['dwi_' int2str(scan_index) '_quality_control.txt'];
    output_result_matrix_path = fullfile(diff_path, output_result_matrix_name);
    save(output_result_matrix_path, 'volume_quality_array', '-ascii');

end % END of the for loop

end