function path = resolve_storage_file(storageDirs, fileName)
%RESOLVE_STORAGE_FILE Return first existing path for fileName across dirs.
path = '';
for i = 1:numel(storageDirs)
    cand = fullfile(storageDirs{i}, fileName);
    if isfile(cand)
        path = cand;
        return;
    end
end
end
