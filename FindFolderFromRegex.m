function folder_list = FindFolderFromRegex(path, pattern)

    folder_list ={};
    list = dir(path);
    for i = 1:length(list)
        
        if (list(i).isdir ~= 1)
            continue;
        end
        
        folder = regexp(list(i).name, pattern, 'match');
        
        if (length(folder) == 1) && strcmp(cell2mat(folder), list(i).name)
            folder_list = [folder_list folder];
        end
    end

end