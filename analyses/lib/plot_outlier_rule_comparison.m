function plot_outlier_rule_comparison(repoRoot, printFigures, fineTune)
%PLOT_OUTLIER_RULE_COMPARISON Parse mean+/-3SD vs 1.5*IQR outlier rules.
% Writes analyses/results/outlierRuleComparison/contaminantVsOutlier.txt
% (and optional bar figure under png/eps).
% Ported from anchorYears_0.m case 'outlierRuleComparison'.

if nargin < 2
    printFigures = true;
end
if nargin < 3 || isempty(fineTune)
    fineTune = default_fine_tune();
end

dataDir = fullfile(repoRoot, 'data');
outDir = results_dir(repoRoot, 'outlierRuleComparison');
if ~isfolder(outDir)
    mkdir(outDir);
end

load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');

rawFile = fullfile(dataDir, 'anchoring140JW2024.mat');
if ~isfile(rawFile)
    error('plot_outlier_rule_comparison: missing raw file %s', rawFile);
end
Sraw = load(rawFile);
dRaw = Sraw.d;
dRaw.truth(6) = 2004; % same Firefox correction as parseAnchoryears_1.m

outTxt = fullfile(outDir, 'contaminantVsOutlier.txt');
% Keep any existing F2026 section so original regen does not drop replication.
f2026Block = extract_f2026_outlier_section(outTxt);

fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s for writing', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

writef = @(varargin) local_writef(fid, varargin{:});

writef('\n========== ORIGINAL event-years outlierRuleComparison ==========\n');
writef('Parse rule: mean+/-3SD per question; second pass on Q8,Q11\n');
writef('IQR rule:   outside [Q1-1.5*IQR, Q3+1.5*IQR] per question\n');

count = 0;
questionLongRaw = [];
groupLongRaw = [];
estimateLongRaw = [];
participantLongRaw = [];
for qIdx = 1:dRaw.nQuestions
    truth = dRaw.truth(qIdx);
    pCount = 0;
    for gIdx = 1:length(dRaw.nParticipants)
        for pIdx = 1:dRaw.nParticipants(gIdx)
            pCount = pCount + 1;
            if gIdx == 3
                group = 3;
            else
                anchor = dRaw.anchors{gIdx}(qIdx);
                if anchor > truth
                    group = 2;
                else
                    group = 1;
                end
            end
            count = count + 1;
            participantLongRaw(count) = pCount; %#ok<AGROW>
            questionLongRaw(count) = qIdx; %#ok<AGROW>
            groupLongRaw(count) = group; %#ok<AGROW>
            estimateLongRaw(count) = dRaw.answer{gIdx}(pIdx, qIdx); %#ok<AGROW>
        end
    end
end
nRaw = count;
writef('Raw observations (pre-parse): %d\n', nRaw);

nSD = 3;
parseOut = false(1, nRaw);
keepPass1 = [];
for questionIdx = 1:dRaw.nQuestions
    matchLong = find(questionLongRaw == questionIdx);
    y = estimateLongRaw(matchLong);
    mn = mean(y);
    sd = std(y);
    inBound = (y >= mn - nSD * sd) & (y <= mn + nSD * sd);
    keepPass1 = [keepPass1 matchLong(inBound)]; %#ok<AGROW>
    parseOut(matchLong(~inBound)) = true;
end

questionKeep = questionLongRaw(keepPass1);
estimateKeep = estimateLongRaw(keepPass1);
goAgain = [8 11]; % McDonald's, Pixar
furtherRemoveLocal = [];
for k = 1:numel(goAgain)
    questionIdx = goAgain(k);
    matchLong = find(questionKeep == questionIdx);
    y = estimateKeep(matchLong);
    mn = mean(y);
    sd = std(y);
    bad = (y < mn - nSD * sd) | (y > mn + nSD * sd);
    furtherRemoveLocal = [furtherRemoveLocal matchLong(bad)]; %#ok<AGROW>
end
parseOut(keepPass1(furtherRemoveLocal)) = true;

iqrOut = false(1, nRaw);
loFence = nan(dRaw.nQuestions, 1);
hiFence = nan(dRaw.nQuestions, 1);
for questionIdx = 1:dRaw.nQuestions
    matchLong = find(questionLongRaw == questionIdx);
    y = estimateLongRaw(matchLong);
    q1 = prctile(y, 25);
    q3 = prctile(y, 75);
    iqr = q3 - q1;
    lo = q1 - 1.5 * iqr;
    hi = q3 + 1.5 * iqr;
    loFence(questionIdx) = lo;
    hiFence(questionIdx) = hi;
    iqrOut(matchLong(y < lo | y > hi)) = true;
end

bothOut = parseOut & iqrOut;
parseOnly = parseOut & ~iqrOut;
iqrOnly = ~parseOut & iqrOut;

writef('\nPer-question outlier counts (grouping = question, all conditions pooled):\n');
writef('%-20s %5s %5s %5s %5s %5s %5s  %12s %12s\n', ...
    'Question', 'n', 'Parse', 'IQR', 'Both', 'Ponly', 'Ionly', 'IQR_lo', 'IQR_hi');
nParseQ = zeros(dRaw.nQuestions, 1);
nIqrQ = zeros(dRaw.nQuestions, 1);
nBothQ = zeros(dRaw.nQuestions, 1);
nPonlyQ = zeros(dRaw.nQuestions, 1);
nIonlyQ = zeros(dRaw.nQuestions, 1);
nQ = zeros(dRaw.nQuestions, 1);
for questionIdx = 1:dRaw.nQuestions
    m = questionLongRaw == questionIdx;
    nQ(questionIdx) = sum(m);
    nParseQ(questionIdx) = sum(parseOut(m));
    nIqrQ(questionIdx) = sum(iqrOut(m));
    nBothQ(questionIdx) = sum(bothOut(m));
    nPonlyQ(questionIdx) = sum(parseOnly(m));
    nIonlyQ(questionIdx) = sum(iqrOnly(m));
    writef('%-20s %5d %5d %5d %5d %5d %5d  %12.1f %12.1f\n', ...
        d.questionLabels{questionIdx}, nQ(questionIdx), ...
        nParseQ(questionIdx), nIqrQ(questionIdx), nBothQ(questionIdx), ...
        nPonlyQ(questionIdx), nIonlyQ(questionIdx), ...
        loFence(questionIdx), hiFence(questionIdx));
end

writef('\nOverall:\n');
writef('  Raw n              = %d\n', nRaw);
writef('  Parse outliers     = %d  (kept %d)\n', sum(parseOut), sum(~parseOut));
writef('  IQR outliers       = %d  (kept %d)\n', sum(iqrOut), sum(~iqrOut));
writef('  Both methods       = %d\n', sum(bothOut));
writef('  Parse only         = %d\n', sum(parseOnly));
writef('  IQR only           = %d\n', sum(iqrOnly));
writef('  Cleaned mat n      = %d (anchorYearsData.mat)\n', numel(d.estimateLong));
agree = sum(parseOut == iqrOut);
writef('  Agreement on flag  = %d / %d (%.1f%%)\n', agree, nRaw, 100 * agree / nRaw);

if any(parseOnly)
    writef('\nParse-only outliers (flagged by 3SD parse, not by IQR):\n');
    idx = find(parseOnly);
    for i = 1:numel(idx)
        j = idx(i);
        writef('  Q%-2d %-18s  est=%g  group=%d  person=%d\n', ...
            questionLongRaw(j), d.questionLabels{questionLongRaw(j)}, ...
            estimateLongRaw(j), groupLongRaw(j), participantLongRaw(j));
    end
end
if any(iqrOnly)
    writef('\nIQR-only outliers (flagged by IQR, not by 3SD parse):\n');
    idx = find(iqrOnly);
    for i = 1:numel(idx)
        j = idx(i);
        writef('  Q%-2d %-18s  est=%g  group=%d  person=%d\n', ...
            questionLongRaw(j), d.questionLabels{questionLongRaw(j)}, ...
            estimateLongRaw(j), groupLongRaw(j), participantLongRaw(j));
    end
end

writef('\nMean estimate by question x group (raw / after parse keep / after IQR keep):\n');
writef('%-20s %-4s %8s %8s %8s\n', 'Question', 'Grp', 'Raw', 'Parse', 'IQR');
for questionIdx = 1:dRaw.nQuestions
    for gIdx = 1:3
        m = questionLongRaw == questionIdx & groupLongRaw == gIdx;
        if ~any(m)
            continue
        end
        yRaw = estimateLongRaw(m);
        yP = estimateLongRaw(m & ~parseOut);
        yI = estimateLongRaw(m & ~iqrOut);
        writef('%-20s %-4d %8.1f %8.1f %8.1f   (n=%d/%d/%d)\n', ...
            d.questionLabels{questionIdx}, gIdx, ...
            mean(yRaw), mean(yP), mean(yI), ...
            numel(yRaw), numel(yP), numel(yI));
    end
end
writef('\n========== end ORIGINAL event-years outlierRuleComparison ==========\n');
if ~isempty(f2026Block)
    writef('\n%s', f2026Block);
    if f2026Block(end) ~= newline
        writef('\n');
    end
end

fprintf('Wrote %s\n', outTxt);

fontSize = 12;
if isfield(fineTune, 'font') && isfield(fineTune.font, 'outlierRuleComparison')
    fontSize = fineTune.font.outlierRuleComparison;
end
F = figure; clf; hold on;
setFigure(F, [0.2 0.3 0.6 0.45], '');
x = 1:dRaw.nQuestions;
barWidth = 0.35;
bar(x - barWidth / 2, nParseQ, barWidth, 'facecolor', pantone.ClassicBlue, 'edgecolor', 'none');
bar(x + barWidth / 2, nIqrQ, barWidth, 'facecolor', pantone.AuroraRed, 'edgecolor', 'none');
set(gca, ...
    'xtick', x, ...
    'xticklabel', d.questionLabels, ...
    'xticklabelrotation', 45, ...
    'tickdir', 'out', ...
    'box', 'off', ...
    'fontsize', fontSize);
ylabel('Outlier count');
legend({'Parse mean+/-3SD', 'Boxplot 1.5*IQR'}, 'location', 'northwest', 'box', 'off');
title('Outlier removal: parse vs boxplot rule');
print_figure(outDir, 'outlierRuleComparison_AllQuestions', printFigures);
close(gcf);
end

function local_writef(fid, varargin)
fprintf(varargin{:});
fprintf(fid, varargin{:});
end


function block = extract_f2026_outlier_section(outTxt)
block = '';
if ~isfile(outTxt)
    return;
end
txt = fileread(outTxt);
startTok = '========== F2026 replication outlierRuleComparison ==========';
idx = strfind(txt, startTok);
if isempty(idx)
    return;
end
block = txt(idx(1):end);
block = strtrim(block);
if ~isempty(block) && block(end) ~= newline
    block = [block newline];
end
end
