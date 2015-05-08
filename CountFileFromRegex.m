function count = CountFileFromRegex(path, pattern)

count = 0;

list = dir(path);
for i = 1:length(list)

    file = regexp(list(i).name, pattern, 'match');

    if (length(file) == 1) && strcmp(cell2mat(file), list(i).name)
        count = count + 1;
    end
end


end