function plot_barrera_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune)
%PLOT_BARRERA_MANUSCRIPT Barrera-Lemarchand Exp 2 figures for anchoringYears_R1_1.tex
% Ported from anchorYearsNavajas_0.m / revision navajas Exp2 plotters.

if nargin < 3
    printFigures = true;
end
if nargin < 4 || isempty(analysisList)
    analysisList = {
        'diversityPredictionTheorem'
        'allQanchoring'
        'performance'
        'expertiseVsAnchoring'
        'debiasingVsAnchoredPerQuestion'
        };
end
if nargin < 5 || isempty(fineTune)
    fineTune = default_fine_tune();
end

dataDir = fullfile(repoRoot, 'data');
figTag = 'barreraLemarchandExperiment2';

load(fullfile(dataDir, 'barreraEtAlExp2.mat'), 'd');
d = ensure_navajas_estimate_cells(d);
if ~isfield(d, 'questionLabels') || numel(d.questionLabels) < d.nQuestions
    d.questionLabels = navajas_exp2_question_labels();
end
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');
peopleColor = {pantone.Flame; pantone.Greenery; pantone.Hazelnut};

for analysisIdx = 1:numel(analysisList)
    analysisName = analysisList{analysisIdx};
    fprintf('  analysis: %s\n', analysisName);
    % allQanchoring shares the anchoringIndex results folder
    resultsName = analysisName;
    if strcmp(analysisName, 'allQanchoring')
        resultsName = 'anchoringIndex';
    end
    outDir = results_dir(repoRoot, resultsName);
    switch analysisName
        case 'diversityPredictionTheorem'
            for qIdx = 1:d.nQuestions
                plot_be_diversityPredictionTheorem(d, qIdx, pantone, peopleColor, storageDirs, fineTune);
                stem = sprintf('diversityPredictionTheorem_%s_%s', figTag, camelcase_label(d.questionLabels{qIdx}));
                print_figure(outDir, stem, printFigures);
                close(gcf);
            end

        case 'allQanchoring'
            plot_be_all_anchoring(d, pantone, storageDirs, fineTune);
            print_figure(outDir, ['allQanchoring_', figTag], printFigures);
            close(gcf);

        case 'performance'
            plot_be_performance(d, pantone, peopleColor, storageDirs, fineTune);
            print_figure(outDir, ['allQPerformanceComparisonAnchor_', figTag], printFigures);
            close(gcf);

        case 'expertiseVsAnchoring'
            plot_expertise_vs_anchoring(d, pantone, peopleColor, storageDirs, 'barreraEtAlExperiment2', fineTune);
            print_figure(outDir, 'inferredExpertiseVsAnchoring_barreraLemarchandExperiment2', printFigures);
            close(gcf);

        case 'debiasingVsAnchoredPerQuestion'
            report_debiasing_vs_anchored_per_question(repoRoot, storageDirs, 'barrera');

        case {'anchoringIndex', 'debiasingModel', 'outlierRuleComparison'}
            fprintf('  (skipping %s for barrera — not applicable)\n', analysisName);

        otherwise
            warning('Unknown or inapplicable analysis for barrera: %s', analysisName);
    end
end

fprintf('Barrera Exp 2 selected outputs written under analyses/results/\n');
end

function plot_be_diversityPredictionTheorem(d, qIdx, pantone, peopleColor, storageDirs, fineTune)
questionMatch = qIdx;
fontSize = fineTune.font.diversityPredictionTheorem;
height = 1; width = 1;
truthColor = 'k';
groupOrder = [2 3 1];

matchLong = find(d.questionLong == questionMatch);
y = d.estimateLong(matchLong);
group = d.groupLong(matchLong);
yPlot = round(y);
loAnchor = d.anchors(questionMatch, 1);
hiAnchor = d.anchors(questionMatch, 2);
truth = d.truth(questionMatch);
lo = 0; hi = 100;
xTick = unique([0:10:100, loAnchor, hiAnchor, truth]);
xTickLabel = repmat({''}, 1, numel(xTick));
for iTick = 1:numel(xTick)
    if abs(xTick(iTick) - truth) < 1e-9
        xTickLabel{iTick} = sprintf('%g', truth);
    elseif abs(xTick(iTick) - loAnchor) < 1e-9 || abs(xTick(iTick) - hiAnchor) < 1e-9
        xTickLabel{iTick} = sprintf('%g', xTick(iTick));
    end
end

F = figure; clf; hold on;
setFigure(F, [0.1 0.3 0.85 0.7], '');
set(F, 'Units', 'pixels', 'Position', [80 80 1600 700], 'PaperPositionMode', 'auto');

axLeft = subplot(1, 2, 1); hold on;
set(axLeft, 'xlim', [lo hi], 'xtick', xTick, 'xticklabel', xTickLabel, ...
    'XTickLabelRotation', 0, 'ycolor', 'none', 'box', 'off', 'tickdir', 'out', ...
    'layer', 'top', 'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
moveAxis(axLeft, [1 1 1.5 0.9], [-0.1 0.085 0 0]);
xlabel(axLeft, 'Estimate', 'fontsize', fontSize + 2);
Raxes(axLeft, 0.02, 0);

count = zeros(hi - lo + 1, 1);
for groupIdx = 1:3
    for idx = 1:length(yPlot)
        if group(idx) == groupOrder(groupIdx) && yPlot(idx) >= lo && yPlot(idx) <= hi
            T(groupIdx) = rectangle(...
                'position', [yPlot(idx) - width / 2, count(yPlot(idx) - lo + 1) - height / 2, width, height], ...
                'facecolor', peopleColor{group(idx)}, ...
                'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
            count(yPlot(idx) - lo + 1) = count(yPlot(idx) - lo + 1) + height;
        end
    end
    count = ones(hi - lo + 1, 1) * (max(count) + 5);
end
for grpIdx = 3:-1:1
    T(grpIdx) = plot(-10, -10, 's', 'markersize', 12, ...
        'markerfacecolor', peopleColor{groupOrder(grpIdx)}, 'markeredgecolor', 'none');
end
L = legend(T(end:-1:1), {'low anchor', 'no anchor', 'high anchor'}, ...
    'autoupdate', 'off', 'box', 'off', 'edgecolor', 'none');
yLim = get(axLeft, 'ylim'); yLim(1) = 0; set(axLeft, 'ylim', yLim);
H = plot([truth truth], get(axLeft, 'ylim'), 'color', truthColor, 'linewidth', 2); uistack(H, 'bottom');
H = plot([hiAnchor hiAnchor], get(axLeft, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');
H = plot([loAnchor loAnchor], get(axLeft, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');

noColor = peopleColor{3};
fullColor = pantone.LapisBlue;
omegaStyle = '-'; deltaStyle = '--'; epsilonStyle = ':'; lineWidth = 4;
offset = navajas_diversity_offsets(d.nQuestions);
yLo = d.estimateLong(d.groupLong == 1 & d.questionLong == questionMatch);
yHi = d.estimateLong(d.groupLong == 2 & d.questionLong == questionMatch);
yNo = d.estimateLong(d.groupLong == 3 & d.questionLong == questionMatch);
yHiLo = [yHi, yLo];
[omegaHL, omegaN, deltaHL, deltaN, epsilon2HL, epsilon2N] = load_or_compute_diversity( ...
    storageDirs, sprintf('diversityAccuracy_navajasExperiment2_%d.mat', qIdx), ...
    yLo, yHi, yNo, truth);

yLim = [0, ceil(max([max(epsilon2HL(:)), max(epsilon2N(:))], [], 'omitnan'))];
if ~isfinite(yLim(2)) || yLim(2) <= 0
    yLim(2) = 1;
end
xTickVals = sort(unique([2, length(yNo), length(yHiLo)]));
axRight = subplot(1, 2, 2); hold on;
set(axRight, 'xlim', [2 length(yHiLo)], 'xtick', xTickVals, 'XTickLabelRotation', 0, ...
    'ylim', yLim, 'ytick', yLim, 'box', 'off', 'tickdir', 'out', 'ticklength', [0.01 0], ...
    'clipping', 'off', 'fontsize', fontSize);
xlabel(axRight, 'Crowd Size', 'fontsize', fontSize + 2);
T = ylabel(axRight, 'Mean of Squared Error', 'fontsize', fontSize);
set(T, 'pos', get(T, 'pos') + [0.03 0 0]);
moveAxis(axRight, [1 1 0.42 0.9], [0.05 0.085 0 0]);
Raxes(axRight, 0, 0.01);
set(axRight, 'Clipping', 'off', 'XTickLabelRotation', 0);
fontSize = fontSize - 2;
plot([2 length(yHiLo)], ones(1, 2) * epsilon2HL, epsilonStyle, 'color', fullColor, 'linewidth', lineWidth);
text(length(yHiLo) + 1, epsilon2HL + offset(questionMatch, 3), 'anchor individual error', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
plot([2 length(yNo)], ones(1, 2) * epsilon2N, epsilonStyle, 'color', noColor, 'linewidth', lineWidth);
text(length(yNo) + 1, epsilon2N + offset(questionMatch, 6), 'no anchor individual error', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
plot(2:length(yHiLo), mean(deltaHL(2:end, :), 2), deltaStyle, 'color', fullColor, 'linewidth', lineWidth);
text(length(yHiLo) + 1, mean(deltaHL(end, :)) + offset(questionMatch, 2), 'anchor crowd diversity', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
plot(2:length(yNo), mean(deltaN(2:end, :), 2), deltaStyle, 'color', noColor, 'linewidth', lineWidth);
text(length(yNo) + 1, mean(deltaN(end, :)) + offset(questionMatch, 5), 'no anchor crowd diversity', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
plot(2:length(yHiLo), mean(omegaHL(2:end, :), 2), omegaStyle, 'color', fullColor, 'linewidth', lineWidth);
text(length(yHiLo) + 1, mean(omegaHL(end, :)) + offset(questionMatch, 1), 'anchor crowd error', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
plot(2:length(yNo), mean(omegaN(2:end, :), 2), omegaStyle, 'color', noColor, 'linewidth', lineWidth);
text(length(yNo) + 1, mean(omegaN(end, :)) + offset(questionMatch, 4), 'no anchor crowd error', 'hor', 'left', 'fontsize', fontSize, 'Clipping', 'off');
end

function plot_be_all_anchoring(d, pantone, storageDirs, fineTune)
CI = 95; critical = 0; fontSize = fineTune.font.allQanchoringBarrera;
bounds = zeros(d.nQuestions, 2);
BF = zeros(d.nQuestions, 1);
mn = zeros(d.nQuestions, 1);
[~, srtIdx] = sort(d.truth(:), 'ascend');

for qIdx = 1:d.nQuestions
    [chains, priorField, postField] = load_anchoring_chains(storageDirs, d.questionLabels{qIdx});
    if isempty(chains)
        error('Missing anchoring-index MCMC for Barrera question %s', d.questionLabels{qIdx});
    end
    binLo = 0; binHi = 1; binWidth = 0.01;
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
setFigure(F, [0.2 0.05 0.5 0.9], '');
set(F, 'renderer', 'opengl');
set(gca, 'ytick', 1:d.nQuestions, 'ylim', [0.5 d.nQuestions + 0.5], ...
    'yticklabel', d.questionLabels(srtIdx), 'ydir', 'rev', 'xlim', [0 1], ...
    'xtick', 0:0.1:1, 'xticklabelrot', 0, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.01 0], 'fontsize', fontSize);
moveAxis(gca, [1 1 0.9 0.95], [0.08 0.02 0 0]);
xlabel('Anchoring Index', 'fontsize', fontSize + 2);
Raxes(gca, 0.025, 0.01);
for qIdx = 1:d.nQuestions
    qi = srtIdx(qIdx);
    plot(bounds(qi, :), [qIdx qIdx], '-', 'color', pantone.Aluminum, 'LineWidth', 4);
    plot(mn(qi), qIdx, 'o', 'markerfacecolor', pantone.PottersClay, ...
        'markeredgecolor', 'w', 'markersize', 10, 'linewidth', 1);
    if BF(qi) > 1000
        str = sprintf(' BF_{10} > 1000');
    elseif BF(qi) > 1
        str = sprintf(' BF_{10} = %1.1f', BF(qi));
    else
        str = sprintf(' BF_{01} = %1.1f', 1 / BF(qi));
    end
    text(0.88, qIdx, str, 'vert', 'mid', 'fontsize', fontSize - 4);
end
end

function plot_be_performance(d, pantone, peopleColor, storageDirs, fineTune)
fontSize = fineTune.font.performance; height = 1; width = 1;
fullCrowdColor = 'k';
noCrowdColor = peopleColor{3};
anchorCrowdColor = pantone.LapisBlue;
modelAColor = pantone.Sandstone;
rng(1);

crowdEst = zeros(d.nQuestions, 1);
crowdHLEst = zeros(d.nQuestions, 1);
crowdNEst = zeros(d.nQuestions, 1);
for qIdx = 1:d.nQuestions
    yAll = d.estimateLong(d.questionLong == qIdx);
    yLo = d.estimateLong(d.groupLong == 1 & d.questionLong == qIdx);
    yHi = d.estimateLong(d.groupLong == 2 & d.questionLong == qIdx);
    yNo = d.estimateLong(d.groupLong == 3 & d.questionLong == qIdx);
    crowdEst(qIdx) = mean(yAll);
    crowdHLEst(qIdx) = mean([yHi, yLo]);
    crowdNEst(qIdx) = mean(yNo);
end
e = d.participantRMSE(:);
omegaCrowd = sqrt(mean((crowdEst - d.truth).^2));
omegaHLCrowd = sqrt(mean((crowdHLEst - d.truth).^2));
omegaNCrowd = sqrt(mean((crowdNEst - d.truth).^2));

jagsCandidates = {
    'debiasing_barreraEtAlExperiment2_jags.mat'
    'debiasingNavajas_6_navajasExperiment2_jags.mat'
    };
jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath), break; end
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for Barrera Exp 2');
end
fprintf('Loading %s\n', jagsPath);
S = load(jagsPath, 'chains');
chains = S.chains;
sigmaA = codatable(chains, 'sigma', @mean);
alphaA = codatable(chains, 'alpha', @mean);
[omegaAModel, omegaAModelCI] = model_rmse_from_mu(chains, d.truth, 'PosteriorCI', true);
sigmaPlot = sigmaA(:);

empiricalAtmp = nan(d.nParticipants, d.nQuestions);
for pIdx = 1:d.nParticipants
    for qIdx = 1:d.nQuestions
        match = find(d.participantLong == pIdx & d.questionLong == qIdx);
        if isempty(match), continue; end
        empiricalAtmp(pIdx, qIdx) = (d.estimateLong(match) - d.truth(qIdx)) / (d.anchorLong(match) - d.truth(qIdx));
    end
end
keepAnchored = find(d.participantGroup == 2);
empiricalA = nanmean(empiricalAtmp, 2);
empiricalA = empiricalA(keepAnchored);
alphaA = alphaA(keepAnchored);

F = figure; clf; hold on;
setFigure(F, [0.2 0.3 0.65 0.45], '');
set(F, 'renderer', 'opengl');  % FaceAlpha on model CI patch
xMin = 10; xMax = 65; xTick = unique(10:10:70);
set(gca, 'ycolor', 'none', 'xlim', [xMin xMax], 'xtick', xTick, 'box', 'off', ...
    'tickdir', 'out', 'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
xlabel('Root Mean Squared Error', 'fontsize', fontSize + 2);
moveAxis(gca, [1 1 1 0.9], [0 0.075 0 0]);
Raxes(gca, 0.01, 0.01);
[count, ~, a] = histcounts(e, -0.5:ceil(max(e)) + 0.5);
xCenters = (0:length(count) - 1)';
for idx = 1:length(count)
    for i = 1:count(idx)
        match = find(a == idx);
        match = match(ceil(rand * length(match)));
        xPos = xCenters(idx);
        if xPos < xMin - width / 2 || xPos > xMax + width / 2
            continue;
        end
        H = rectangle('position', [xPos - width / 2, i - height / 2 - 0.5, width, height], ...
            'facecolor', pantone.DuskBlue, 'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
        if d.participantGroup(match) == 1
            set(H, 'facecolor', peopleColor{3});
        end
    end
end
yLim = get(gca, 'yLim'); yLim(2) = yLim(2) * 1.2; set(gca, 'ylim', yLim);
mult = 1.05;
if ~isempty(omegaAModelCI)
    Hci = patch([omegaAModelCI(1) omegaAModelCI(2) omegaAModelCI(2) omegaAModelCI(1)], ...
        [yLim(1) yLim(1) yLim(2) yLim(2)], modelAColor, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.2);
    uistack(Hci, 'bottom');
    fprintf('Model RMSE (posterior mean of mu): %.2f; 95%% CI from mu draws: [%.2f, %.2f]\n', ...
        omegaAModel, omegaAModelCI(1), omegaAModelCI(2));
end
H = plot([omegaAModel omegaAModel], mult * get(gca, 'ylim'), 'color', modelAColor, 'linewidth', 4); uistack(H, 'bottom');
text(min(omegaAModel, xMax * 0.95), mult * yLim(2), ' anchoring model', 'fontsize', fontSize);
mult = 1;
H = plot([omegaHLCrowd omegaHLCrowd], mult * get(gca, 'ylim'), 'color', anchorCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(min(omegaHLCrowd, xMax * 0.95), mult * yLim(2), ' anchor crowd', 'fontsize', fontSize);
mult = 0.9;
H = plot([omegaNCrowd omegaNCrowd], mult * get(gca, 'ylim'), 'color', noCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(min(omegaNCrowd, xMax * 0.95), mult * yLim(2), ' no-anchor crowd', 'fontsize', fontSize);
mult = 0.95;
H = plot([omegaCrowd omegaCrowd], mult * get(gca, 'ylim'), 'color', fullCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(min(omegaCrowd, xMax * 0.95), mult * yLim(2), ' full crowd', 'fontsize', fontSize);

insetKeep = isfinite(e) & isfinite(sigmaPlot) & e <= xMax & e >= xMin;
A = axes; hold on;
expertiseYMax = ceil(max(e(insetKeep), [], 'omitnan') * 1.05);
expertiseXMax = ceil(max(sigmaPlot(insetKeep), [], 'omitnan') * 1.05);
expertiseYMax = max(expertiseYMax, 1);
expertiseXMax = max(expertiseXMax, 1);
set(A, 'units', 'norm', 'position', [0.75 0.5 0.2 0.4], ...
    'xlim', [0 expertiseXMax], 'xtick', [0 expertiseXMax], 'xticklabel', {'hi', 'lo'}, ...
    'xticklabelrot', 0, 'ylim', [0 expertiseYMax], 'ytick', [0 expertiseYMax], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', 'ticklength', [0.02 0], 'fontsize', fontSize);
axis square;
xlabel('inferred expertise', 'fontsize', fontSize);
ylabel('observed error', 'fontsize', fontSize);
insetIdx = find(insetKeep);
shuffle = randperm(numel(insetIdx));
for idx2 = 1:numel(insetIdx)
    idx = insetIdx(shuffle(idx2));
    H = plot(sigmaPlot(idx), e(idx), 'o', 'markerfacecolor', pantone.DuskBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
    if d.participantGroup(idx) == 1
        set(H, 'markerfacecolor', peopleColor{3});
    end
end
Raxes(gca, 0.01, 0.01);
rS = corrcoef(sigmaPlot(insetKeep), e(insetKeep), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rS(1, 2)), 'fontsize', fontSize, 'hor', 'left', 'vert', 'top');

A = axes; hold on;
errAnchored = e(keepAnchored);
insetAnchorKeep = isfinite(alphaA) & isfinite(empiricalA) & isfinite(errAnchored) & ...
    errAnchored <= xMax & errAnchored >= xMin;
set(A, 'units', 'norm', 'position', [0.5 0.5 0.2 0.4], 'xlim', [0 1], 'xtick', [-1 0 1], ...
    'xticklabelrot', 0, 'ylim', [-1 1], 'ytick', [-1 0 1], 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.02 0], 'fontsize', fontSize);
axis square;
xlabel('inferred anchoring', 'fontsize', fontSize);
ylabel('observed anchoring', 'fontsize', fontSize);
anchorIdx = find(insetAnchorKeep);
shuffle = randperm(numel(anchorIdx));
for idx2 = 1:numel(anchorIdx)
    idx = anchorIdx(shuffle(idx2));
    plot(alphaA(idx), empiricalA(idx), 'o', 'markerfacecolor', pantone.DuskBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
end
Raxes(gca, 0.01, 0.01);
rA = corrcoef(alphaA(insetAnchorKeep), empiricalA(insetAnchorKeep), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rA(1, 2)), 'fontsize', fontSize, 'hor', 'left', 'vert', 'top');
fprintf('Correlations (barrera): anchoring=%.4f, expertise=%.4f\n', rA(1, 2), rS(1, 2));
end
