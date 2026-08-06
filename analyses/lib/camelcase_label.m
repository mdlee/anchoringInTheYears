function out = camelcase_label(label)
%CAMELCASE_LABEL Convert a question label to a CamelCase file stem.
label = strrep(label, '+', 'Plus');
label = strrep(label, '%', 'Pct');
parts = regexp(label, '[A-Za-z0-9]+', 'match');
out = '';
for i = 1:numel(parts)
    p = parts{i};
    out = [out, upper(p(1)), p(2:end)]; %#ok<AGROW>
end
end
