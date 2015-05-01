%base_code

%caseName = caseFileNames(1);


% %choose the last one which has been create
% if isempty(caseFileNames), 
%     lastCaseNum = 0;
% else
%     lastCaseNum = str2double(caseFileNames(end).name(5:end));
% end
% 
% if isnan(lastCaseNum)
%     fprintf('Last Case number not found -- quitting\n');
%     return;
% end

%new case directory
%caseDirName = sprintf('%scase%03d',directStr,caseNum);
% caseDirName = sprintf('%sCardiacNeonate%03d',directStr,caseNum);

% if exist(caseDirName,'dir') && recreate == 0
%     fprintf('This case number already exists\n');
%     return;
% end

% if ~exist(caseDirName,'dir')
%  system(['mkdir ' caseDirName]);
%  cd(caseDirName);
%  system(['mkdir raw']);
%  system(['mkdir diff']);
%  system(['mkdir fMRI']);
%  system(['mkdir T1']);
%  system(['mkdir T2']);
% end


% fn = dir([caseDirName '/raw/']);
% 
% if numel(fn) <= 2
% %now move the zip file to a new directory in this case number
%  system(['cp ' zipfile ' ' caseDirName '/raw/']);
%  cd([caseDirName '/raw']);
%  fn = dir('*.zip');
%  system(['unzip ' fn(1).name]);
%  name = dir('*');
%  if name(3).isdir, id = 3; end
%  if name(4).isdir, id = 4; end;
%  system(['mv ' name(id).name '/* .']);
%  
% else
%  cd([caseDirName '/raw/']);
% end
% 
% %now convert all required files to nrrd format
% %First do T1 conversion
% if ~exist([caseDirName '/T1/T1.nrrd'],'file') || recreate
%  fn = dir('WIP*RMS*');
%  if isempty(fn)
%      fprintf('No T1 files found\n');
%  else
%      system(['ConvertBetweenFileFormats ' fn(end).name ' ' caseDirName '/T1/T1.nrrd']);
%  end
% end
% 
% %Now create T2.nrrd 
% if ~exist([caseDirName '/T2/T2.nrrd'],'file') || recreate
%  fn = dir('*T2_to*');
%  if isempty(fn)
%      fprintf('No T2 files found\n');
%  else
%      system(['ConvertBetweenFileFormats ' fn(end).name ' ' caseDirName '/T2/T2.nrrd']);
%  end
% end
% 
%Lets convert fMRI files now
% if ~exist([caseDirName '/fMRI/fMRI.nhdr'],'file') || recreate
%  addpath(thisdir); 
%  fn = dir('MoCo*fMRI*');
%  if isempty(fn)
%      fprintf('No fMRI files found\n');
%  else
%      ConvertfMRIDicomToNrrd(fn(end).name,caseDirName);
%       cd('../');
%  end
% 
% end
% 
% 
% %Now convert the diffusion dicoms to nrrd
% if ~exist([caseDirName '/diff/dwi-Ed.nhdr'],'file') || recreate
%  addpath(thisdir);
%  dn = pwd;
%  DiffusionDicomToNrrd(dn,thisdir,caseDirName);
% end
% 
% %Delete all the unzipped files to save some space
% cd([caseDirName '/raw/']);
% fn = dir('*');
% for j=1:numel(fn)
%   if fn(j).isdir 
%     system(['rm -r ' fn(j).name]);
%   end
% end
% 
% fprintf('Created %s -- done\n',caseDirName);