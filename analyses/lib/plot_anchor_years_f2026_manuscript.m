function plot_anchor_years_f2026_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune)
%PLOT_ANCHOR_YEARS_F2026_MANUSCRIPT F2026 event-years figures and reports.
% Same 11 questions as the original event-years study. Low/high anchors are
% the 1st and 99th percentiles of that study's no-anchor group. F2026 has no
% no-anchor arm (anchored forms only).

if nargin < 3
    printFigures = true;
end
if nargin < 4 || isempty(analysisList)
    analysisList = {
        'diversityPredictionTheorem'
        'allQanchoring'
        'performance'
        'expertiseVsAnchoring'
        'outlierRuleComparison'
        'debiasingVsAnchoredPerQuestion'
        'constrainedDebiasing'
        };
end
if nargin < 5 || isempty(fineTune)
    fineTune = default_fine_tune();
end

dataDir = fullfile(repoRoot, 'data');
figTag = 'anchorYearsF2026';
chainTag = 'anchorYearsF2026';

load(fullfile(dataDir, 'anchorYearsF2026.mat'), 'd');
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');
peopleColor = {pantone.Flame; pantone.Greenery; pantone.Hazelnut};

for analysisIdx = 1:numel(analysisList)
    analysisName = analysisList{analysisIdx};
    fprintf('  analysis: %s\n', analysisName);
    resultsName = analysisName;
    if strcmp(analysisName, 'allQanchoring')
        resultsName = 'anchoringIndex';
    end
    outDir = results_dir(repoRoot, resultsName);
    switch analysisName
        case 'diversityPredictionTheorem'
            fprintf(['  (skipping diversityPredictionTheorem for replication — ', ...
                'no no-anchor arm to compare against)\n']);

        case 'allQanchoring'
            plot_f2026_all_anchoring(d, pantone, storageDirs, fineTune, chainTag);
            print_figure(outDir, ['allQanchoring_', figTag], printFigures);
            close(gcf);

        case 'anchoringIndex'
            plot_f2026_anchoring_density(d, pantone, storageDirs, fineTune, chainTag, 6);
            print_figure(outDir, ['anchoringIndex_', figTag, '_Firefox'], printFigures);
            close(gcf);

        case 'performance'
            % Replication has no no-anchor arm, so the "diverse / anchored-only"
            % comparison is not meaningful — only the full+debiasing figure.
            plot_f2026_performance(d, pantone, peopleColor, storageDirs, fineTune, false);
            print_figure(outDir, ['allQPerformanceComparisonAnchor_', figTag], printFigures);
            close(gcf);

        case 'expertiseVsAnchoring'
            plot_expertise_vs_anchoring(d, pantone, peopleColor, storageDirs, chainTag, fineTune);
            print_figure(outDir, ['inferredExpertiseVsAnchoring_', figTag], printFigures);
            close(gcf);

        case 'outlierRuleComparison'
            reportPath = fullfile(repoRoot, 'analyses', 'results', 'outlierRuleComparison', 'anchorYearsF2026.txt');
            if ~isfile(reportPath)
                prepare_anchor_years_f2026(repoRoot);
            end
            fprintf('Contaminant report: %s\n', reportPath);

        case 'debiasingVsAnchoredPerQuestion'
            report_debiasing_vs_anchored_per_question(repoRoot, storageDirs, chainTag);

        case 'constrainedDebiasing'
            report_constrained_debiasing(repoRoot, storageDirs, chainTag);

        case {'allQanchoringReplication', 'performanceReplication', ...
                'performanceOriginalReplication', 'performanceOriginal'}
            % Handled once from analyses.m (needs original + replication fits).
            fprintf('  (skipping %s here — run via analyses.m)\n', analysisName);

        case {'debiasingModel', 'aggregateAnchorBF'}
            fprintf('  (skipping %s for anchorYearsF2026 — not applicable)\n', analysisName);

        otherwise
            warning('Unknown or inapplicable analysis for anchorYearsF2026: %s', analysisName);
    end
end

fprintf('anchorYearsF2026 selected outputs written under analyses/results/\n');
end

function row = plot_f2026_diversity(d, qIdx, pantone, peopleColor, storageDirs, fineTune, chainTag)
fontSize = fineTune.font.diversityPredictionTheorem;
height = 1;
width = 1;
truthColor = 'k';
groupOrder = [2 3 1];

matchLong = find(d.questionLong == qIdx);
y = d.estimateLong(matchLong);
group = d.groupLong(matchLong);
yPlot = round(y);
loAnchor = d.anchors(qIdx, 1);
hiAnchor = d.anchors(qIdx, 2);
truth = d.truth(qIdx);
lo = min([yPlot(:); loAnchor; hiAnchor]);
hi = max([yPlot(:); loAnchor; hiAnchor]);

F = figure; clf; hold on;
set_figure_safe(F, [0.1 0.3 0.85 0.7], '');
set(F, 'Units', 'pixels', 'Position', [80 80 1600 700], 'PaperPositionMode', 'auto');

axLeft = subplot(1, 2, 1); hold on;
set(axLeft, 'xlim', [lo hi], 'xtick', unique([loAnchor truth hiAnchor]), ...
    'XTickLabelRotation', 0, 'ycolor', 'none', 'box', 'off', 'tickdir', 'out', ...
    'layer', 'top', 'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
moveAxis(axLeft, [1 1 1.5 0.9], [-0.1 0.085 0 0]);
xlabel(axLeft, 'Year', 'fontsize', fontSize + 2);
Raxes(axLeft, 0.02, 0);

span = hi - lo + 1;
count = zeros(span, 1);
T = gobjects(1, 3);
for groupIdx = 1:3
    for idx = 1:numel(yPlot)
        if group(idx) ~= groupOrder(groupIdx)
            continue;
        end
        bin = yPlot(idx) - lo + 1;
        if bin < 1 || bin > span
            continue;
        end
        T(groupIdx) = rectangle( ...
            'position', [yPlot(idx) - width / 2, count(bin) - height / 2, width, height], ...
            'facecolor', peopleColor{group(idx)}, ...
            'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
        count(bin) = count(bin) + height;
    end
    count = ones(span, 1) * (max(count) + 5);
end
for grpIdx = 3:-1:1
    T(grpIdx) = plot(nan, nan, 's', 'markersize', 12, ...
        'markerfacecolor', peopleColor{groupOrder(grpIdx)}, 'markeredgecolor', 'none');
end
legend(T(end:-1:1), {'low anchor', 'no anchor', 'high anchor'}, ...
    'autoupdate', 'off', 'box', 'off', 'edgecolor', 'none');
yLim = get(axLeft, 'ylim'); yLim(1) = 0; set(axLeft, 'ylim', yLim);
H = plot([truth truth], get(axLeft, 'ylim'), 'color', truthColor, 'linewidth', 2); uistack(H, 'bottom');
H = plot([hiAnchor hiAnchor], get(axLeft, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');
H = plot([loAnchor loAnchor], get(axLeft, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');

noColor = peopleColor{3};
fullColor = pantone.LapisBlue;
omegaStyle = '-';
deltaStyle = '--';
epsilonStyle = ':';
lineWidth = 4;
yLo = d.estimateLong(d.groupLong == 1 & d.questionLong == qIdx);
yHi = d.estimateLong(d.groupLong == 2 & d.questionLong == qIdx);
yNo = d.estimateLong(d.groupLong == 3 & d.questionLong == qIdx);
yHiLo = [yHi(:)', yLo(:)'];
[omegaHL, omegaN, deltaHL, deltaN, epsilon2HL, epsilon2N] = load_or_compute_diversity( ...
    storageDirs, sprintf('diversityAccuracy_%s_%d.mat', chainTag, qIdx), ...
    yLo, yHi, yNo, truth);

labelY = [
    epsilon2HL
    epsilon2N
    mean(deltaHL(end, :))
    mean(deltaN(end, :))
    mean(omegaHL(end, :))
    mean(omegaN(end, :))
    ];
labelY = separate_label_ys(labelY, 0.16 * max(labelY));
yTop = max([max(epsilon2HL(:)), max(epsilon2N(:)), max(labelY)]);
yLim = [0, ceil(yTop * 1.08)];
if ~isfinite(yLim(2)) || yLim(2) <= 0
    yLim(2) = 1;
end
xTickVals = sort(unique([2, numel(yNo), numel(yHiLo)]));
axRight = subplot(1, 2, 2); hold on;
set(axRight, 'xlim', [2 max(numel(yHiLo), 3)], 'xtick', xTickVals, 'XTickLabelRotation', 0, ...
    'ylim', yLim, 'ytick', [0 yLim(2)], 'box', 'off', 'tickdir', 'out', 'ticklength', [0.01 0], ...
    'clipping', 'off', 'fontsize', fontSize);
xlabel(axRight, 'Crowd Size', 'fontsize', fontSize + 2);
ylabel(axRight, 'Mean of Squared Error', 'fontsize', fontSize);
moveAxis(axRight, [1 1 0.42 0.9], [0.05 0.085 0 0]);
Raxes(axRight, 0, 0.01);
set(axRight, 'Clipping', 'off');
labelSize = fontSize - 8;
xLab = numel(yHiLo) + 1;
labels = {
    'anchor individual error'
    'no anchor individual error'
    'anchor crowd diversity'
    'no anchor crowd diversity'
    'anchor crowd error'
    'no anchor crowd error'
    };
labelColor = {fullColor, noColor, fullColor, noColor, fullColor, noColor};
plot([2 numel(yHiLo)], ones(1, 2) * epsilon2HL, epsilonStyle, 'color', fullColor, 'linewidth', lineWidth);
plot([2 numel(yNo)], ones(1, 2) * epsilon2N, epsilonStyle, 'color', noColor, 'linewidth', lineWidth);
plot(2:numel(yHiLo), mean(deltaHL(2:end, :), 2), deltaStyle, 'color', fullColor, 'linewidth', lineWidth);
plot(2:numel(yNo), mean(deltaN(2:end, :), 2), deltaStyle, 'color', noColor, 'linewidth', lineWidth);
plot(2:numel(yHiLo), mean(omegaHL(2:end, :), 2), omegaStyle, 'color', fullColor, 'linewidth', lineWidth);
plot(2:numel(yNo), mean(omegaN(2:end, :), 2), omegaStyle, 'color', noColor, 'linewidth', lineWidth);
for labIdx = 1:numel(labels)
    text(xLab, labelY(labIdx), labels{labIdx}, 'hor', 'left', 'vert', 'middle', ...
        'fontsize', labelSize, 'color', labelColor{labIdx}, 'Clipping', 'off');
end

row.question = d.questionLabels{qIdx};
row.epsilonHL = epsilon2HL;
row.epsilonN = epsilon2N;
row.deltaHL = mean(deltaHL(end, :));
row.deltaN = mean(deltaN(end, :));
row.omegaHL = mean(omegaHL(end, :));
row.omegaN = mean(omegaN(end, :));
end

function write_diversity_cases(repoRoot, d, caseRows)
outDir = results_dir(repoRoot, 'diversityPredictionTheorem');
if ~isfolder(outDir)
    mkdir(outDir);
end
outTxt = fullfile(outDir, 'anchorYearsF2026_cases.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
w = @(varargin) fprintf(fid, varargin{:});

w('COGS140J F2026 event-years: individual-error and diversity cases\n');
w('Anchor crowd = F2026 low and high anchors (percentile anchors).\n');
w('No-anchor crowd = the original event-years no-anchor group.\n');
w('Squared-error decomposition: individual error = crowd error + diversity.\n');
w('A positive change means the anchor crowd is larger than the no-anchor crowd.\n\n');
w('%-18s %10s %10s %10s %10s %10s %10s  %s\n', ...
    'Question', 'dInd', 'dDiv', 'dCrowd', 'ind', 'div', 'crowd', 'Case');

for qIdx = 1:d.nQuestions
    row = caseRows{qIdx};
    dInd = row.epsilonHL - row.epsilonN;
    dDiv = row.deltaHL - row.deltaN;
    dCrowd = row.omegaHL - row.omegaN;
    caseName = diversity_case_name(dInd, dDiv, dCrowd);
    w('%-18s %10.1f %10.1f %10.1f %10s %10s %10s  %s\n', ...
        row.question, dInd, dDiv, dCrowd, ...
        change_word(dInd), change_word(dDiv), change_word(dCrowd), caseName);
    fprintf('  %s: individual %s, diversity %s, crowd error %s\n  %s\n', ...
        row.question, change_word(dInd), change_word(dDiv), change_word(dCrowd), caseName);
end
fprintf('Wrote %s\n', outTxt);
end

function name = diversity_case_name(dInd, dDiv, dCrowd)
if dInd > 0 && dDiv < 0
    name = 'both changes hurt the crowd (individual error up, diversity down)';
elseif dInd < 0 && dDiv > 0
    name = 'both changes help the crowd (individual error down, diversity up)';
elseif dInd > 0 && dDiv > 0
    if dCrowd < 0
        name = 'diversity gain outweighs the rise in individual error';
    elseif dCrowd > 0
        name = 'rise in individual error outweighs the diversity gain';
    else
        name = 'diversity gain matches the rise in individual error';
    end
elseif dInd < 0 && dDiv < 0
    if dCrowd < 0
        name = 'drop in individual error outweighs the loss of diversity';
    elseif dCrowd > 0
        name = 'loss of diversity outweighs the drop in individual error';
    else
        name = 'drop in individual error matches the loss of diversity';
    end
else
    name = 'one component is unchanged';
end
end

function ys = separate_label_ys(ys, gap)
% Push nearby labels apart so the six curve names stay readable.
if gap <= 0
    return;
end
[sorted, order] = sort(ys(:));
for i = 2:numel(sorted)
    if sorted(i) < sorted(i - 1) + gap
        sorted(i) = sorted(i - 1) + gap;
    end
end
ys(order) = sorted;
end

function word = change_word(delta)
if delta > 0
    word = 'up';
elseif delta < 0
    word = 'down';
else
    word = 'same';
end
end

function plot_f2026_all_anchoring(d, pantone, storageDirs, fineTune, chainTag)
CI = 95;
critical = 0;
fontSize = fineTune.font.allQanchoringBarrera;
bounds = zeros(d.nQuestions, 2);
BF = zeros(d.nQuestions, 1);
mn = zeros(d.nQuestions, 1);
[~, srtIdx] = sort(d.truth(:), 'ascend');

for qIdx = 1:d.nQuestions
    [chains, priorField, postField] = load_f2026_chains(storageDirs, chainTag, qIdx);
    binLo = 0;
    binHi = 1;
    binWidth = 0.01;
    binCenter = binLo:binWidth:binHi;
    [~, criticalIdx] = min(abs(binCenter - critical));
    densityPrior = histcounts(chains.(priorField)(:), ...
        'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
        'binwidth', binWidth, 'normalization', 'pdf');
    densityPosterior = histcounts(chains.(postField)(:), ...
        'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
        'binwidth', binWidth, 'normalization', 'pdf');
    BF(qIdx) = exp(log(densityPrior(criticalIdx)) - log(densityPosterior(criticalIdx)));
    bounds(qIdx, :) = prctile(chains.(postField)(:), [(100 - CI) / 2, CI + (100 - CI) / 2]);
    mn(qIdx) = mean(chains.(postField)(:));
end

F = figure; clf; hold on;
set_figure_safe(F, [0.05 0.02 0.72 0.96], '');
set(F, 'Units', 'pixels', 'Position', [40 40 1100 900], 'PaperPositionMode', 'auto');
set(gca, 'ytick', 1:d.nQuestions, 'ylim', [0.5 d.nQuestions + 0.5], ...
    'yticklabel', d.questionLabels(srtIdx), 'ydir', 'rev', 'xlim', [0 1.55], ...
    'xtick', 0:0.2:1, 'xticklabelrot', 0, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.01 0], 'fontsize', fontSize, 'clipping', 'off');
moveAxis(gca, [1 1 0.72 0.95], [0.16 0.02 0 0]);
xlabel('Anchoring Index', 'fontsize', fontSize + 2);
Raxes(gca, 0.025, 0.01);
for qIdx = 1:d.nQuestions
    qi = srtIdx(qIdx);
    ciPlot = [max(0, bounds(qi, 1)), min(1, bounds(qi, 2))];
    plot(ciPlot, [qIdx qIdx], '-', 'color', pantone.Aluminum, 'LineWidth', 4);
    plot(mn(qi), qIdx, 'o', 'markerfacecolor', pantone.PottersClay, ...
        'markeredgecolor', 'w', 'markersize', 10, 'linewidth', 1);
    if BF(qi) > 1000
        str = sprintf('BF_{10} > 1000');
    elseif BF(qi) > 1
        str = sprintf('BF_{10} = %1.1f', BF(qi));
    else
        str = sprintf('BF_{01} = %1.1f', 1 / BF(qi));
    end
    text(1.05, qIdx, str, 'vert', 'mid', 'fontsize', fontSize - 4, 'Clipping', 'off');
end
write_anchoring_bf(storageDirs, d, mn, bounds, BF);
end

function plot_f2026_anchoring_density(d, pantone, storageDirs, fineTune, chainTag, qIdx)
CI = 95;
critical = 0;
fontSize = fineTune.font.anchoringIndex;
lineWidth = 2;
markerSize = 6;
binLo = 0;
binHi = 1;
binWidth = 0.005;
binTick = 0.1;
binCenter = binLo:binWidth:binHi;
[~, criticalIdx] = min(abs(binCenter - critical));
[chains, priorField, postField] = load_f2026_chains(storageDirs, chainTag, qIdx);

F = figure; clf; hold on;
set_figure_safe(F, [0.2 0.3 0.6 0.4], '');
set(gca, 'ycolor', 'none', 'xlim', [binLo binHi], 'xtick', binLo:binTick:binHi, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', [0.01 0], 'fontsize', fontSize);
moveAxis(gca, [1 1 1 0.8], [0 0.1 0 0]);
xlabel('Anchoring Index', 'fontsize', fontSize + 2);
densityPrior = histcounts(chains.(priorField)(:), ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
plot(binCenter, densityPrior, '--', 'color', pantone.Titanium, 'linewidth', lineWidth);
densityPosterior = histcounts(chains.(postField)(:), ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
plot(binCenter, densityPosterior, '-', 'color', pantone.ClassicBlue, 'linewidth', lineWidth);
legend('prior', 'posterior', 'box', 'off', 'fontsize', fontSize, 'location', 'northeast', 'autoupdate', 'off');
BF = exp(log(densityPrior(criticalIdx)) - log(densityPosterior(criticalIdx)));
plot(binCenter(criticalIdx) * ones(1, 2), [densityPrior(criticalIdx) densityPosterior(criticalIdx)], 'k-');
bounds = prctile(chains.(postField)(:), [(100 - CI) / 2, CI + (100 - CI) / 2]);
fprintf('%s anchoring index mean %1.2f, 95%% CI (%1.2f, %1.2f), BF10=%1.1f\n', ...
    d.questionLabels{qIdx}, mean(chains.(postField)(:)), bounds(1), bounds(2), BF);
end

function write_anchoring_bf(~, d, mn, bounds, BF)
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
outDir = fullfile(repoRoot, 'analyses', 'results', 'anchoringIndex');
if ~isfolder(outDir)
    mkdir(outDir);
end
outTxt = fullfile(outDir, 'anchorYearsF2026.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'COGS140J F2026 event-years: anchoring-index Bayes factors\n');
fprintf(fid, 'BF10 is the Savage-Dickey factor against anchoring index = 0.\n\n');
fprintf(fid, '%-18s %8s %18s %s\n', 'Question', 'mean', '95% CI', 'BF');
for qIdx = 1:d.nQuestions
    if BF(qIdx) > 1000
        bfStr = 'BF10 > 1000';
    elseif BF(qIdx) > 1
        bfStr = sprintf('BF10 = %.1f', BF(qIdx));
    else
        bfStr = sprintf('BF01 = %.1f', 1 / BF(qIdx));
    end
    fprintf(fid, '%-18s %8.2f %8.2f to %6.2f  %s\n', ...
        d.questionLabels{qIdx}, mn(qIdx), bounds(qIdx, 1), bounds(qIdx, 2), bfStr);
    fprintf('  %s anchoring index %.2f, BF %s\n', d.questionLabels{qIdx}, mn(qIdx), bfStr);
end
fprintf('Wrote %s\n', outTxt);
end

function [chains, priorField, postField] = load_f2026_chains(storageDirs, chainTag, qIdx)
path = resolve_storage_file(storageDirs, sprintf('anchoringIndex_%s_%d_jags.mat', chainTag, qIdx));
if isempty(path)
    error('Missing anchoring-index MCMC for anchorYearsF2026 Q%d', qIdx);
end
S = load(path, 'chains');
chains = S.chains;
priorField = 'Aprior';
postField = 'A';
end

function plot_f2026_performance(d, pantone, peopleColor, storageDirs, fineTune, includeDiverse)
fontSize = fineTune.font.performance;
height = 1;
width = 1;
% Replication: no no-anchor arm; all person marks / lines in one blue.
repBlue = pantone.LapisBlue;
modelAColor = repBlue;
fullCrowdColor = repBlue;
diverseColor = repBlue;
rng(1);

e = d.participantRMSE;
crowdEst = zeros(d.nQuestions, 1);
crowdHLEst = zeros(d.nQuestions, 1);
for qIdx = 1:d.nQuestions
    y = d.estimateLong(d.questionLong == qIdx);
    crowdEst(qIdx) = mean(y);
    crowdHLEst(qIdx) = mean([d.estimate{qIdx, 1}(:); d.estimate{qIdx, 2}(:)]);
end
omegaCrowd = sqrt(mean((crowdEst(:) - d.truth(:)) .^ 2));
omegaHLCrowd = sqrt(mean((crowdHLEst(:) - d.truth(:)) .^ 2));

% Prefer anchored-only chains: F2026 has no no-anchor arm, and older
% debiasing_anchorYearsF2026_jags.mat fits may still include borrowed
% original no-anchor people.
jagsPath = resolve_storage_file(storageDirs, 'debiasing_anchorYearsF2026AnchoredOnly_jags.mat');
if isempty(jagsPath)
    jagsPath = resolve_storage_file(storageDirs, 'debiasing_anchorYearsF2026_jags.mat');
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for anchorYearsF2026');
end
fprintf('Loading %s\n', jagsPath);
S = load(jagsPath, 'chains');
chains = S.chains;
sigmaA = codatable(chains, 'sigma', @mean);
alphaA = codatable(chains, 'alpha', @mean);
[omegaAModel, omegaAModelCI] = model_rmse_from_mu(chains, d.truth, 'PosteriorCI', true);

omegaDiverse = NaN;
omegaDiverseCI = [];
if includeDiverse
    aoPath = resolve_storage_file(storageDirs, 'debiasing_anchorYearsF2026AnchoredOnly_jags.mat');
    if isempty(aoPath)
        error('Missing anchored-only debiasing MCMC for anchorYearsF2026');
    end
    fprintf('Loading %s\n', aoPath);
    Sao = load(aoPath, 'chains');
    [omegaDiverse, omegaDiverseCI] = model_rmse_from_mu(Sao.chains, d.truth, 'PosteriorCI', true);
    sigmaDiverse = codatable(Sao.chains, 'sigma', @mean);
    alphaDiverse = codatable(Sao.chains, 'alpha', @mean);
end

keepAnchored = find(d.participantGroup == 12);
empiricalAtmp = nan(d.nParticipants, d.nQuestions);
for pIdx = 1:d.nParticipants
    for qIdx = 1:d.nQuestions
        match = find(d.participantLong == pIdx & d.questionLong == qIdx, 1);
        if isempty(match) || ~isfinite(d.anchorLong(match))
            continue;
        end
        denom = d.anchorLong(match) - d.truth(qIdx);
        if denom == 0
            continue;
        end
        empiricalAtmp(pIdx, qIdx) = (d.estimateLong(match) - d.truth(qIdx)) / denom;
    end
end
empiricalA = mean(empiricalAtmp(keepAnchored, :), 2, 'omitnan');
if includeDiverse
    if numel(alphaDiverse) ~= numel(keepAnchored)
        error('Diverse debiasing alpha length (%d) != n anchored (%d)', ...
            numel(alphaDiverse), numel(keepAnchored));
    end
    alphaPlot = alphaDiverse(:);
    sigmaPlot = sigmaDiverse(:);
    eExpertise = e(keepAnchored);
    groupExpertise = d.participantGroup(keepAnchored);
else
    alphaPlot = alphaA(keepAnchored);
    sigmaPlot = sigmaA;
    eExpertise = e;
    groupExpertise = d.participantGroup;
end

F = figure; clf; hold on;
set_figure_safe(F, [0.2 0.3 0.65 0.45], '');
set(F, 'renderer', 'opengl');
xMax = max(e) + 1;
set(gca, 'ycolor', 'none', 'xlim', [0 xMax], ...
    'xtick', unique(0:10:round(max(e), -1)), 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
xlabel('Root Mean Squared Error', 'fontsize', fontSize + 2);
moveAxis(gca, [1 1 1 0.9], [0 0.075 0 0]);
Raxes(gca, 0.01, 0.01);
[count, ~, a] = histcounts(e, -0.5:ceil(max(e)) + 0.5);
for idx = 1:numel(count)
    for i = 1:count(idx)
        match = find(a == idx);
        match = match(ceil(rand * numel(match)));
        rectangle('position', [idx - 1 - width / 2, i - height / 2 - 0.5, width, height], ...
            'facecolor', repBlue, 'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
    end
end
yLim = get(gca, 'yLim');
yLim(2) = yLim(2) * (1.35 + 0.1 * includeDiverse);
set(gca, 'ylim', yLim);
if includeDiverse
    mult = 1.22;
    Hci = patch([omegaDiverseCI(1) omegaDiverseCI(2) omegaDiverseCI(2) omegaDiverseCI(1)], ...
        [yLim(1) yLim(1) yLim(2) yLim(2)], diverseColor, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.2);
    uistack(Hci, 'bottom');
    fprintf('Diverse debiasing RMSE: %.2f; 95%% CI: [%.2f, %.2f]\n', ...
        omegaDiverse, omegaDiverseCI(1), omegaDiverseCI(2));
    H = plot([omegaDiverse omegaDiverse], mult * get(gca, 'ylim'), 'color', diverseColor, 'linewidth', 4);
    uistack(H, 'bottom');
    text(omegaDiverse, mult * yLim(2), ' diverse debiasing', ...
        'fontsize', fontSize, 'Clipping', 'off', 'vert', 'bottom', 'color', diverseColor);
end
% Replication: only debiasing + full crowd (no no-anchor arm; omit separate anchor-crowd line)
mult = 1.05;
if ~isempty(omegaAModelCI)
    Hci = patch([omegaAModelCI(1) omegaAModelCI(2) omegaAModelCI(2) omegaAModelCI(1)], ...
        [yLim(1) yLim(1) yLim(2) yLim(2)], modelAColor, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.2);
    uistack(Hci, 'bottom');
    fprintf('Debiasing RMSE: %.2f; 95%% CI: [%.2f, %.2f]\n', ...
        omegaAModel, omegaAModelCI(1), omegaAModelCI(2));
end
H = plot([omegaAModel omegaAModel], mult * get(gca, 'ylim'), 'color', modelAColor, 'linewidth', 4);
uistack(H, 'bottom');
text(omegaAModel, mult * yLim(2), ' debiasing', 'fontsize', fontSize, ...
    'Clipping', 'off', 'color', modelAColor);
mult = 0.90;
H = plot([omegaCrowd omegaCrowd], mult * get(gca, 'ylim'), 'color', fullCrowdColor, 'linewidth', 4);
uistack(H, 'bottom');
text(omegaCrowd, mult * yLim(2), ' full crowd', 'fontsize', fontSize, 'color', fullCrowdColor);

g = fineTune.performance;
A = axes; hold on;
set(A, 'units', 'norm', 'position', [g.insetExpertise.bottomLeft g.insetWidth g.insetHeight], ...
    'xlim', [0 max(75, ceil(max(sigmaPlot)))], 'xtick', [0 max(75, ceil(max(sigmaPlot)))], ...
    'xticklabel', {'hi', 'lo'}, 'xticklabelrot', 0, ...
    'ylim', [0 max(eExpertise)], 'ytick', [0 max(eExpertise)], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.02 0], 'fontsize', g.font.insetAxis);
axis square;
xlabel('inferred expertise', 'fontsize', g.font.insetLabel);
ylabel('observed error', 'fontsize', g.font.insetLabel);
shuffle = randperm(numel(eExpertise));
for idx2 = 1:numel(eExpertise)
    idx = shuffle(idx2);
    plot(sigmaPlot(idx), eExpertise(idx), 'o', 'markerfacecolor', repBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
end
Raxes(gca, 0.01, 0.01);
rS = corrcoef(sigmaPlot(:), eExpertise(:), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rS(1, 2)), 'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');

A = axes; hold on;
set(A, 'units', 'norm', 'position', [g.insetAnchoring.bottomLeft g.insetWidth g.insetHeight], ...
    'xlim', [-1 1], 'xtick', [-1 0 1], 'xticklabelrot', 0, ...
    'ylim', [-1 1], 'ytick', [-1 0 1], 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.02 0], 'fontsize', g.font.insetAxis);
axis square;
xlabel('inferred anchoring', 'fontsize', g.font.insetLabel);
ylabel('observed anchoring', 'fontsize', g.font.insetLabel);
shuffle = randperm(numel(keepAnchored));
for idx2 = 1:numel(keepAnchored)
    idx = shuffle(idx2);
    plot(alphaPlot(idx), empiricalA(idx), 'o', 'markerfacecolor', repBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
end
Raxes(gca, 0.01, 0.01);
rA = corrcoef(alphaPlot(:), empiricalA(:), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rA(1, 2)), 'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');
fprintf('Correlations (replication): anchoring=%.4f, expertise=%.4f\n', rA(1, 2), rS(1, 2));
fprintf('Crowd RMSE: full=%.2f anchor=%.2f; debiasing=%.2f\n', ...
    omegaCrowd, omegaHLCrowd, omegaAModel);
end
