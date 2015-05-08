function createArtifact(case_path, input_file_name, output_file_name)

    % Assumptions:
    %   - gradients number along 4th dimension

    % Load the reference NRRD file
    file_path = fullfile(dir_path, input_file_name);
    dwi = loadNrrdStructure(file_path);

    % Search for the first 3 B3000 gradients
    count = 3;
    index = 1;
    index_array = [0 0 0];

    while (count > 0) && (index <= 70)

        if (dwi.bvalue(index) * norm(dwi.gradients(index,:) > 2600)
            count = count -1;
            index_array(4-count) = index;
        end

        index = index +1;
    end

    if (index > 70)
        disp('= ERROR : Couldn''t find 3 B-3000 gradients =');
        return;
    end

    % for each 3 gradients, we choose one slice, and we put half of it to 0;
    slice_number = [50, 45, 40];
    sz = size(dwi.data);
    tmp = zeros(sz(1), sz(2));
    for i=1:3
        tmp(:) = dwi.data(:, :, slice_number(i), index_array(i));
        tmp(1:sz(1)/2, :) = 0;
        dwi.data(:, :, slice_number(i), index_array(i)) = tmp(:);
    end

end