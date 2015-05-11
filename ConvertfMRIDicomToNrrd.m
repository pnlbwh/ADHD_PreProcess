function ConvertfMRIDicomToNrrd(output_dir, volume_name, dicom_path)

files = dir(fullfile(dicom_path, '/*.dcm'));
N = numel(files);

%convert dicom to nifti format first
nifti_dir = output_dir; %fullfile(output_dir, 'Nifti');


% [success, message, messageid] = mkdir(output_dir, 'Nifti');
% 
% if (success ~= 1)
%     disp('= ERROR 100 =')
%     disp(['Could not create directory < Nifti  > in < ' dicom_path ' >'])
%     disp(message);
%     disp(messageid);
% end


% Command for DICOM to NIFTI

output_nifti_name = fullfile(nifti_dir, '/image%n.nii' );
system(['/projects/schiz/pi/yogesh/phd/dwmri/EPI_DistortionCorrection/cmtk-2.2.6/bin/dcm2image -x -O ' output_nifti_name ' ' dicom_path]);

% output_nifti_name = fullfile(nifti_dir, '*.gz');
% system(['gunzip' ' ' output_nifti_name]);
% system(['rm ' fullfile(nifti_dir, '*.gz')]);
% 
% 
% files = dir(fullfile(nifti_dir, '*.nii'));
% 
% if (length(files) < 1)
%     disp('ERROR 111: fMRI dicom to nifti probably failed')
%     disp(['In ' dicom_path ' for ' output_dir]);
%     return;
% end
% 
% m = load_untouch_nii(fullfile(nifti_dir, files(1).name));
% 
% [nx, ny, nz] = size(m.img);
% data = uint16(zeros(nx,ny,nz,N));
% 
% for j=1:N
%     strct = load_untouch_nii(fullfile(nifti_dir, files(j).name));
%     data(:,:,:,j) = strct.img;
% end
% 
% 
% offset=2; %default offset
% 
% voxel = m.hdr.dime.pixdim(offset:offset+2);
% spacedirections = [voxel(1) 0 0;0 voxel(2) 0;0 0 voxel(3)];
% spaceorigin = [m.hdr.hist.srow_x(end) m.hdr.hist.srow_y(end) m.hdr.hist.srow_z(end)];
% 
% % Write the data
% file_name = fullfile(output_dir, volume_name);
% mat2nhdr(data, file_name,'fMRI',spacedirections,spaceorigin);
% 
% % Remove the Nifti folder
% %system(['rm -r ' nifti_dir]);
% 
% % Keep only uncompressed
% system(['rm ' fullfile(nifti_dir, '*.nii')]);

end