function  MakeNewCase(start_number, stop_number, recreate)
%This function creates the directory structure for a new ADHD study
%It also pre-processes the data and creates nrrd file format for
%each case
%Pre-processing involves -- eddy and motion correction
%Can also do EPI correction - optionally.
%zipfile -- the zip file in which the dicom data is stored - give full path
% caseNum -- the case number which needs to be created
%recreate -- optional if you want to re-convert the data

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Let's prepare the script
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % 


% Add the current directory to the path
thisdir = '/projects/schiz/ra/ccarquex/ADHD_PreProcess';
if exist(thisdir,'dir'), addpath(thisdir); end

thisdir = '/projects/schiz/pi/yogesh/toolboxes/NiftiToMatConvert';
if exist(thisdir,'dir'), addpath(thisdir); end

thisdir = '/projects/schiz/pi/yogesh/phd/dwmri/lib';
if exist(thisdir,'dir'), addpath(thisdir); end

% mat2DWInhdr.m
thisdir = '/projects/schiz/pi/yogesh/toolboxes/CompressedSensing/CompressedSensingDWI/MATLAB_SCRIPTS';
if exist(thisdir,'dir'), addpath(thisdir); end

% Path to data
data_path = '/projects/schiz/ADHD/';

% Protocol path
protocol_name = 'protocol.xml';
protocol_path = fullfile(data_path, 'common_files/', protocol_name);

% if (nargin <= 2)
%     recreate = 0;
% end

% % % % % % % % % % % % % % % % % % % % % % % % % % % % % 
% Find all the cases
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % 

% Let's first create directories
caseFileNames = dir(fullfile(data_path, 'case*'));

for i = 1:length(caseFileNames)
    
    % Find the case number
    pattern = 'case(\d+)';
    replace_expression = '$1';
    text = caseFileNames(i).name;
    
    case_number = regexprep(text, pattern, replace_expression);
    case_number = str2num(case_number);
    
    % If this is in the given range
    if (case_number >= start_number) && (case_number <= stop_number)
         disp(['Processing case number: ' int2str(case_number)]);
         
         caseDir = caseFileNames(i);
         
         % Convert all the DICOMS to NRRD format
         disp('Converting DICOMS to Nifti and NRRD')
         %ConvertCaseToNrrd(caseDir, data_path, recreate);
         
         % Run DTIPrep and searches for bad gradients
         disp('Running DTIPrep');
         %RunDTIPrep(fullfile(data_path, caseDir.name), recreate, protocol_path);
         
         % Eddy Current correction
         disp('Eddy currents correction');
         EddyCurrentCorrection_diffusion(fullfile(data_path, caseDir.name), recreate)

         
         % EPI script
         %EpiCorrection(fullfile(data_path, caseDir.name), recreate);
         
    end
end



% % % % % % % % % % % % % % % % % % % % % % % % % % % 





end

