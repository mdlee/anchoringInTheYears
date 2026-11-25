function prepare_anchor_years_f2026(repoRoot)
%PREPARE_ANCHOR_YEARS_F2026 Build the F2026 event-years analysis files.
%
% COGS140J F2026 asks the same 11 event-year questions as the original
% anchor-years study. Each form uses one of the two anchors, set to the
% 1st and 99th percentiles of that study's no-anchor group. F2026 has no
% no-anchor arm — only the two anchored forms are retained (do not append
% original no-anchor people).
%
% Contaminant removal matches the event-years parse: drop estimates outside
% mean +/- 3 SD within each question (both F2026 forms pooled), then a
% second pass on McDonald's (Q8) and Pixar (Q11). The kept data are written
% to data/anchorYearsF2026Long.csv and data/anchorYearsF2026.mat.
% A parse-vs-IQR report is written under analyses/results/outlierRuleComparison/.

if nargin < 1 || isempty(repoRoot)
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

srcDir = '/home/mdlee/Dropbox/COGS140J/tasks/generalKnowledgeEstimation/data';
forms = {
    1, fullfile(srcDir, 'anchorF2026_1.xlsx')
    2, fullfile(srcDir, 'anchorF2026_2.xlsx')
    };

questionLabels = {
    'Thriller'
    'Internet'
    'Disneyland'
    'Great Depression'
    'iPhone'
    'Firefox'
    'Youtube'
    'McDonald''s'
    'Revolutionary War'
    'Reagan'
    'Pixar'
    };
% Firefox truth is 2004, the correction used in anchorYearsData.mat.
truth = [1983 1983 1955 1929 2007 2004 2005 1955 1775 1981 1995];
% Columns are form 1 and form 2. These are the rounded 1st/99th percentiles
% of the original no-anchor group (see no-anchor-percentile-years.pdf).
formAnchor = [
    1975 2003
    2004 1950
    1923 2013
    1980 1905
    1998 2012
    2010 1974
    1995 2011
    2004 1920
    1700 1890
    2010 1950
    2010 1960
    ];
nQuestions = numel(truth);
questionStartCol = col_number('U');
consentCol = col_number('AU');
maxMissing = 1;
nSD = 3;
secondPassQuestions = [8 11];

% ---- parse consented F2026 rows ----
blocks = cell(size(forms, 1), 1);
for f = 1:size(forms, 1)
    xlsx = forms{f, 2};
    if ~isfile(xlsx)
        error('Missing F2026 workbook: %s', xlsx);
    end
    warning('off', 'all');
    T = readtable(xlsx, 'Sheet', 'Raw Data');
    warning('on', 'all');
    if size(T, 2) < consentCol
        error('Unexpected columns in %s (width %d)', xlsx, size(T, 2));
    end
    nRows = size(T, 1);
    y = nan(nRows, nQuestions);
    hilo = nan(nRows, nQuestions);
    for q = 1:nQuestions
        hilo(:, q) = column_to_numeric(T{:, questionStartCol + 2 * (q - 1)});
        y(:, q) = column_to_numeric(T{:, questionStartCol + 2 * (q - 1) + 1});
    end
    consent = column_to_numeric(T{:, consentCol});
    keep = consent == 1 & sum(~isfinite(y), 2) <= maxMissing;
    blocks{f} = struct( ...
        'form', forms{f, 1}, ...
        'y', y(keep, :), ...
        'hilo', hilo(keep, :));
    fprintf('F2026 form %d: %d consented participants with at most %d missing\n', ...
        forms{f, 1}, sum(keep), maxMissing);
end

y = vertcat(blocks{1}.y, blocks{2}.y);
hilo = vertcat(blocks{1}.hilo, blocks{2}.hilo);
formId = [ones(size(blocks{1}.y, 1), 1); 2 * ones(size(blocks{2}.y, 1), 1)];
nPeople = size(y, 1);

% Long vectors over finite answers only (missing stays out of the SD rule).
questionLong = [];
personLong = [];
formLong = [];
estimateLong = [];
hiloLong = [];
for p = 1:nPeople
    for q = 1:nQuestions
        if ~isfinite(y(p, q))
            continue;
        end
        questionLong(end + 1, 1) = q; %#ok<AGROW>
        personLong(end + 1, 1) = p; %#ok<AGROW>
        formLong(end + 1, 1) = formId(p); %#ok<AGROW>
        estimateLong(end + 1, 1) = y(p, q); %#ok<AGROW>
        hiloLong(end + 1, 1) = hilo(p, q); %#ok<AGROW>
    end
end
nRaw = numel(estimateLong);

parseOut = false(nRaw, 1);
for q = 1:nQuestions
    match = find(questionLong == q);
    inBound = within_n_sd(estimateLong(match), nSD);
    parseOut(match(~inBound)) = true;
end
for k = 1:numel(secondPassQuestions)
    q = secondPassQuestions(k);
    match = find(questionLong == q & ~parseOut);
    inBound = within_n_sd(estimateLong(match), nSD);
    parseOut(match(~inBound)) = true;
end

iqrOut = false(nRaw, 1);
loFence = nan(nQuestions, 1);
hiFence = nan(nQuestions, 1);
for q = 1:nQuestions
    match = find(questionLong == q);
    yy = estimateLong(match);
    q1 = prctile(yy, 25);
    q3 = prctile(yy, 75);
    iqr = q3 - q1;
    loFence(q) = q1 - 1.5 * iqr;
    hiFence(q) = q3 + 1.5 * iqr;
    iqrOut(match(yy < loFence(q) | yy > hiFence(q))) = true;
end

kept = ~parseOut;
fprintf('F2026 contaminant removal: %d finite answers, %d removed by mean+/-3SD, %d kept\n', ...
    nRaw, sum(parseOut), sum(kept));

write_contaminant_report(repoRoot, questionLabels, questionLong, personLong, ...
    formLong, estimateLong, parseOut, iqrOut, loFence, hiFence, nPeople);

% ---- cleaned F2026 rows, reindexed ----
keepPerson = unique(personLong(kept));
newId = zeros(nPeople, 1);
newId(keepPerson) = 1:numel(keepPerson);

cQuestion = questionLong(kept);
cPerson = newId(personLong(kept));
cForm = formLong(kept);
cEstimate = estimateLong(kept);
cHilo = hiloLong(kept);
cAnchor = nan(numel(cEstimate), 1);
cTruth = nan(numel(cEstimate), 1);
cGroup = nan(numel(cEstimate), 1);
for i = 1:numel(cEstimate)
    q = cQuestion(i);
    cTruth(i) = truth(q);
    cAnchor(i) = formAnchor(q, cForm(i));
    if cAnchor(i) < cTruth(i)
        cGroup(i) = 1;
    elseif cAnchor(i) > cTruth(i)
        cGroup(i) = 2;
    else
        error('Anchor equals truth for question %d', q);
    end
end

nParticipants = numel(keepPerson);
participantGroup = 12 * ones(nParticipants, 1);  % all anchored (lo/hi)

% Stable order: participant, then question.
[~, order] = sortrows([cPerson, cQuestion]);
cPerson = cPerson(order);
cQuestion = cQuestion(order);
cForm = cForm(order);
cTruth = cTruth(order);
cAnchor = cAnchor(order);
cHilo = cHilo(order);
cEstimate = cEstimate(order);
cGroup = cGroup(order);

d.nQuestions = nQuestions;
d.questionLabels = questionLabels;
d.nGroups = 2;
d.groupLabels = {'lo', 'hi'};
d.nParticipants = nParticipants;
d.anchors = [min(formAnchor, [], 2), max(formAnchor, [], 2)];
d.participantLong = cPerson;
d.questionLong = cQuestion;
d.groupLong = cGroup;
d.truthLong = cTruth;
d.anchorLong = cAnchor;
d.hiloLong = cHilo;
d.estimateLong = cEstimate;
d.truth = truth(:);
d.estimate = cell(nQuestions, 2);
for q = 1:nQuestions
    d.estimate{q, 1} = cEstimate(cGroup == 1 & cQuestion == q)';
    d.estimate{q, 2} = cEstimate(cGroup == 2 & cQuestion == q)';
end
d.participantGroup = participantGroup;
d.participantError = nan(nParticipants, 1);
d.participantRMSE = nan(nParticipants, 1);
for p = 1:nParticipants
    err = cEstimate(cPerson == p) - cTruth(cPerson == p);
    d.participantError(p) = mean(abs(err));
    d.participantRMSE(p) = sqrt(mean(err .^ 2));
end

csvPath = fullfile(repoRoot, 'data', 'anchorYearsF2026Long.csv');
matPath = fullfile(repoRoot, 'data', 'anchorYearsF2026.mat');
Tout = table(cPerson, cQuestion, cForm, cTruth, cAnchor, cHilo, cEstimate, ...
    'VariableNames', {'participant', 'question', 'version', 'truth', 'anchor', 'highOrLow', 'estimate'});
writetable(Tout, csvPath);
save(matPath, 'd');

fprintf('Wrote %s\n', csvPath);
fprintf('Wrote %s\n', matPath);
fprintf('Participants: %d anchored (F2026; no no-anchor arm)\n', nParticipants);
fprintf('Trials: %d\n', numel(cEstimate));
for q = 1:nQuestions
    fprintf('  Q%-2d %-18s  nLo=%2d nHi=%2d  anchors %g / %g\n', ...
        q, questionLabels{q}, numel(d.estimate{q, 1}), numel(d.estimate{q, 2}), ...
        d.anchors(q, 1), d.anchors(q, 2));
end
end

function keep = within_n_sd(y, nSD)
y = y(:);
mn = mean(y);
sd = std(y);
keep = y >= mn - nSD * sd & y <= mn + nSD * sd;
end

function write_contaminant_report(repoRoot, questionLabels, questionLong, ...
    personLong, formLong, estimateLong, parseOut, iqrOut, loFence, hiFence, nPeople)

outDir = fullfile(repoRoot, 'analyses', 'results', 'outlierRuleComparison');
if ~isfolder(outDir)
    mkdir(outDir);
end
% Consolidated with the original comparison in contaminantVsOutlier.txt.
outTxt = fullfile(outDir, 'contaminantVsOutlier.txt');

nRaw = numel(estimateLong);
bothOut = parseOut & iqrOut;
parseOnly = parseOut & ~iqrOut;
iqrOnly = ~parseOut & iqrOut;
nQuestions = numel(questionLabels);

sec = sprintf('%s\n', '========== F2026 replication outlierRuleComparison ==========');
sec = [sec sprintf('COGS140J F2026 event-years: contaminant removal\n')];
sec = [sec sprintf('Same 11 questions as the original event-years study.\n')];
sec = [sec sprintf('Anchors are the 1st and 99th percentiles of that study''s no-anchor group.\n')];
sec = [sec sprintf('Parse rule: mean +/- 3 SD per question, both F2026 forms pooled;\n')];
sec = [sec sprintf('            second pass on Q8 (McDonald''s) and Q11 (Pixar).\n')];
sec = [sec sprintf('IQR rule:   outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR] per question (comparison only).\n')];
sec = [sec sprintf('Kept data use the parse rule. F2026 has no no-anchor arm (anchored forms only).\n')];
sec = [sec sprintf('\nConsented participants: %d\n', nPeople)];
sec = [sec sprintf('Finite answers before the parse: %d\n', nRaw)];
sec = [sec sprintf('\nPer-question counts:\n')];
sec = [sec sprintf('%-20s %5s %5s %5s %5s %5s %5s  %10s %10s\n', ...
    'Question', 'n', 'Parse', 'IQR', 'Both', 'Ponly', 'Ionly', 'IQR_lo', 'IQR_hi')];
for q = 1:nQuestions
    m = questionLong == q;
    sec = [sec sprintf('%-20s %5d %5d %5d %5d %5d %5d  %10.1f %10.1f\n', ...
        questionLabels{q}, sum(m), sum(parseOut(m)), sum(iqrOut(m)), ...
        sum(bothOut(m)), sum(parseOnly(m)), sum(iqrOnly(m)), ...
        loFence(q), hiFence(q))]; %#ok<AGROW>
end
sec = [sec sprintf('\nOverall:\n')];
sec = [sec sprintf('  Parse outliers     = %d  (kept %d)\n', sum(parseOut), sum(~parseOut))];
sec = [sec sprintf('  IQR outliers       = %d  (kept %d)\n', sum(iqrOut), sum(~iqrOut))];
sec = [sec sprintf('  Both methods       = %d\n', sum(bothOut))];
sec = [sec sprintf('  Parse only         = %d\n', sum(parseOnly))];
sec = [sec sprintf('  IQR only           = %d\n', sum(iqrOnly))];
agree = sum(parseOut == iqrOut);
sec = [sec sprintf('  Agreement on flag  = %d / %d (%.1f%%)\n', agree, nRaw, 100 * agree / nRaw)];
if any(parseOut)
    sec = [sec sprintf('\nRemoved by the parse rule:\n')];
    idx = find(parseOut);
    for i = 1:numel(idx)
        j = idx(i);
        sec = [sec sprintf('  Q%-2d %-18s  est=%g  form=%d  person=%d\n', ...
            questionLong(j), questionLabels{questionLong(j)}, ...
            estimateLong(j), formLong(j), personLong(j))]; %#ok<AGROW>
    end
end
if any(iqrOnly)
    sec = [sec sprintf('\nIQR-only (not removed; flagged by IQR but inside mean +/- 3 SD):\n')];
    idx = find(iqrOnly);
    for i = 1:numel(idx)
        j = idx(i);
        sec = [sec sprintf('  Q%-2d %-18s  est=%g  form=%d  person=%d\n', ...
            questionLong(j), questionLabels{questionLong(j)}, ...
            estimateLong(j), formLong(j), personLong(j))]; %#ok<AGROW>
    end
end
sec = [sec sprintf('========== end F2026 replication outlierRuleComparison ==========\n')];

origKeep = '';
if isfile(outTxt)
    old = fileread(outTxt);
    startTok = '========== F2026 replication outlierRuleComparison ==========';
    idx = strfind(old, startTok);
    if isempty(idx)
        origKeep = strtrim(old);
    else
        origKeep = strtrim(old(1:idx(1)-1));
    end
end
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
if ~isempty(origKeep)
    fprintf(fid, '%s\n\n', origKeep);
end
fprintf(fid, '%s', sec);
% Pointer stub for old path
ptr = fullfile(outDir, 'anchorYearsF2026.txt');
fidPtr = fopen(ptr, 'w');
if fidPtr >= 0
    fprintf(fidPtr, ['Moved: F2026 parse-vs-IQR comparison is now the F2026 section of ' ...
        'contaminantVsOutlier.txt\n']);
    fclose(fidPtr);
end
fprintf('Wrote F2026 section into %s\n', outTxt);
end

function y = column_to_numeric(col)
if isnumeric(col)
    y = double(col);
    return;
end
if iscell(col)
    y = nan(numel(col), 1);
    for i = 1:numel(col)
        y(i) = scalar_to_numeric(col{i});
    end
    return;
end
if isstring(col) || iscategorical(col)
    y = str2double(col);
    return;
end
y = double(col);
end

function v = scalar_to_numeric(x)
if isnumeric(x)
    if isempty(x)
        v = NaN;
    else
        v = double(x(1));
    end
elseif isstring(x) || ischar(x)
    v = str2double(x);
else
    v = NaN;
end
end

function n = col_number(letters)
n = 0;
letters = upper(letters);
for i = 1:numel(letters)
    n = n * 26 + (letters(i) - 'A' + 1);
end
end
