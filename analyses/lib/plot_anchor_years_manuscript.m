function plot_anchor_years_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune)
%PLOT_ANCHOR_YEARS_MANUSCRIPT Event-years figures used by anchoringYears_R1_1.tex
% Ported from anchorYears_0.m / revision plot_anchor_years_figures.m

if nargin < 3
    printFigures = true;
end
if nargin < 4 || isempty(analysisList)
    analysisList = {
        'diversityPredictionTheorem'
        'anchoringIndex'
        'allQanchoring'
        'performance'
        'debiasingModel'
        'expertiseVsAnchoring'
        'outlierRuleComparison'
        'debiasingVsAnchoredPerQuestion'
        };
end
if nargin < 5 || isempty(fineTune)
    fineTune = default_fine_tune();
end

dataDir = fullfile(repoRoot, 'data');

load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
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
                qName = d.questionLabels{qIdx};
                plot_ay_diversityPredictionTheorem(d, qIdx, pantone, peopleColor, storageDirs, fineTune);
                print_figure(outDir, sprintf('diversityPredictionTheorem_%s', qName), printFigures);
                close(gcf);
            end

        case 'anchoringIndex'
            plot_ay_anchoring_index_density(storageDirs, 'Firefox', pantone, fineTune);
            print_figure(outDir, 'anchoringIndex_Firefox', printFigures);
            close(gcf);

        case 'allQanchoring'
            plot_ay_all_anchoring(d, pantone, storageDirs, fineTune);
            print_figure(outDir, 'allQanchoring_AllQuestions', printFigures);
            close(gcf);

        case 'performance'
            plot_ay_performance(d, pantone, peopleColor, storageDirs, fineTune);
            print_figure(outDir, 'allQPerformanceComparisonAnchor_AllQuestions', printFigures);
            close(gcf);

        case 'debiasingModel'
            plot_debiasing_model_schematic(pantone, fineTune);
            print_figure(outDir, 'debiasingModel_AllQuestions', printFigures);
            close(gcf);

        case 'expertiseVsAnchoring'
            plot_expertise_vs_anchoring(d, pantone, peopleColor, storageDirs, 'anchorYears', fineTune);
            print_figure(outDir, 'inferredExpertiseVsAnchoring_anchorYears', printFigures);
            close(gcf);

        case 'outlierRuleComparison'
            plot_outlier_rule_comparison(repoRoot, printFigures, fineTune);

        case 'debiasingVsAnchoredPerQuestion'
            report_debiasing_vs_anchored_per_question(repoRoot, storageDirs, 'anchorYears');

        otherwise
            warning('Unknown or inapplicable analysis for anchorYears: %s', analysisName);
    end
end

fprintf('Anchor-years selected outputs written under analyses/results/\n');
end

function plot_ay_diversityPredictionTheorem(d, qIdx, pantone, peopleColor, storageDirs, fineTune)
questionMatch = qIdx;
questionName = d.questionLabels{qIdx};
fontSize = fineTune.font.diversityPredictionTheorem;
height = 1; width = 1;
truthColor = 'k';
groupOrder = [2 3 1];

matchLong = find(d.questionLong == questionMatch);
y = d.estimateLong(matchLong);
group = d.groupLong(matchLong);
loAnchor = d.anchors(questionMatch, 1);
hiAnchor = d.anchors(questionMatch, 2);
truth = d.truth(questionMatch);
lo = min(min(y), loAnchor);
hi = max(max(y), hiAnchor);

F = figure; clf; hold on;
setFigure(F, [0.1 0.3 0.85 0.7], '');
set(F, 'Units', 'pixels', 'Position', [80 80 1600 700], 'PaperPositionMode', 'auto');

subplot(1, 2, 1); hold on;
set(gca, 'xlim', [lo hi], 'xtick', unique([loAnchor truth hiAnchor]), ...
    'XTickLabelRotation', 0, 'ycolor', 'none', 'box', 'off', 'tickdir', 'out', ...
    'layer', 'top', 'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
moveAxis(gca, [1 1 1.5 0.9], [-0.1 0.085 0 0]);
T = xlabel('Year', 'fontsize', fontSize + 2);
set(T, 'pos', get(T, 'pos') + [0 0.0325 0]);
Raxes(gca, 0.02, 0);

count = zeros(hi - lo + 1, 1);
for groupIdx = 1:3
    for idx = 1:length(y)
        if group(idx) == groupOrder(groupIdx)
            T(groupIdx) = rectangle(...
                'position', [y(idx) - width / 2, count(y(idx) - lo + 1) - height / 2, width, height], ...
                'facecolor', peopleColor{group(idx)}, ...
                'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
            count(y(idx) - lo + 1) = count(y(idx) - lo + 1) + height;
        end
    end
    count = ones(hi - lo + 1, 1) * (max(count) + 5);
end
for grpIdx = d.nGroups:-1:1
    T(grpIdx) = plot(-10, -10, 's', 'markersize', 12, ...
        'markerfacecolor', peopleColor{groupOrder(grpIdx)}, 'markeredgecolor', 'none');
end
legend(T(end:-1:1), {'low anchor', 'no anchor', 'high anchor'}, ...
    'autoupdate', 'off', 'box', 'on', 'edgecolor', 'none', 'location', 'southwest');
yLim = get(gca, 'ylim'); yLim(1) = 0; set(gca, 'ylim', yLim);
H = plot([truth truth], get(gca, 'ylim'), 'color', truthColor, 'linewidth', 2); uistack(H, 'bottom');
H = plot([hiAnchor hiAnchor], get(gca, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');
H = plot([loAnchor loAnchor], get(gca, 'ylim'), '--', 'color', truthColor, 'linewidth', 1); uistack(H, 'bottom');

noColor = peopleColor{3};
fullColor = pantone.LapisBlue;
omegaStyle = '-'; deltaStyle = '--'; epsilonStyle = ':'; lineWidth = 4;
offset = zeros(d.nQuestions, 6);
offset(1, 5) = 1.5;
offset(2, :) = [0 -2 1.5 -1.5 -2 1.5];
offset(3, 2) = -10;
offset(4, 2:3) = [-10 10];
offset(5, 6) = -0.25;
offset(6, 4) = 1.5;
offset(8, 2:3) = [-10 10];
offset(9, 2:3) = [-70 70];
offset(10, :) = [0 -1.5 1.5 -1.5 -2 1.5] * 2;
offset(11, :) = [0 0 0 -2 -1 0];

yHi = d.estimate{questionMatch, 2};
yLo = d.estimate{questionMatch, 1};
yNo = d.estimate{questionMatch, 3};
yHiLo = [yHi yLo];
[omegaHL, omegaN, deltaHL, deltaN, epsilon2HL, epsilon2N] = load_or_compute_diversity( ...
    storageDirs, sprintf('diversityAccuracy_%s.mat', questionName), yLo, yHi, yNo, truth);

yLim = [0, ceil(max(max(epsilon2HL(:)), max(epsilon2N(:))))];
subplot(1, 2, 2); hold on;
set(gca, 'xlim', [2 length(yHiLo)], 'xtick', [2 length(yNo) length(yHiLo)], ...
    'XTickLabelRotation', 0, 'ylim', yLim, 'ytick', yLim, 'box', 'off', ...
    'tickdir', 'out', 'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
xlabel('Crowd Size', 'fontsize', fontSize);
T = ylabel('Mean of Squared Error', 'fontsize', fontSize);
set(T, 'pos', get(T, 'pos') + [0.03 0 0]);
moveAxis(gca, [1 1 0.42 0.9], [0.05 0.075 0 0]);
Raxes(gca, 0, 0.01);
set(gca, 'Clipping', 'off', 'XTickLabelRotation', 0);
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

function plot_ay_anchoring_index_density(storageDirs, questionName, pantone, fineTune)
CI = 95; critical = 0; fontSize = fineTune.font.anchoringIndex; lineWidth = 2; markerSize = 6;
posteriorColor = pantone.ClassicBlue;
priorColor = pantone.Titanium;
[chains, priorField, postField] = load_anchoring_chains(storageDirs, questionName);
if isempty(chains)
    error('Missing anchoring-index MCMC for %s', questionName);
end
binLo = 0; binHi = 1; binWidth = 0.005; binTick = 0.1;
binCenter = binLo:binWidth:binHi;
[~, criticalIdx] = min(abs(binCenter - critical));

F = figure; clf; hold on;
setFigure(F, [0.2 0.3 0.6 0.4], '');
set(gca, 'ycolor', 'none', 'xlim', [binLo binHi], 'xtick', binLo:binTick:binHi, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', [0.01 0], 'fontsize', fontSize);
moveAxis(gca, [1 1 1 0.8], [0 0.1 0 0]);
xlabel('Anchoring Index', 'fontsize', fontSize + 2);

densityPrior = histcounts(chains.(priorField)(:), ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
plot(binCenter, densityPrior, '--', 'color', priorColor, 'linewidth', lineWidth);
densityPosterior = histcounts(chains.(postField)(:), ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
plot(binCenter, densityPosterior, '-', 'color', posteriorColor, 'linewidth', lineWidth);
legend('prior', 'posterior', 'box', 'off', 'fontsize', fontSize, 'location', 'northeast', 'autoupdate', 'off');
BF = exp(log(densityPrior(criticalIdx)) - log(densityPosterior(criticalIdx)));
plot(binCenter(criticalIdx) * ones(1, 2), [densityPrior(criticalIdx) densityPosterior(criticalIdx)], 'k-');
plot(binCenter(criticalIdx), densityPrior(criticalIdx), 'o', 'linewidth', lineWidth, ...
    'markeredgecolor', priorColor, 'markerfacecolor', 'w', 'markersize', markerSize);
plot(binCenter(criticalIdx), densityPosterior(criticalIdx), 'o', 'linewidth', lineWidth, ...
    'markeredgecolor', posteriorColor, 'markerfacecolor', 'w', 'markersize', markerSize);
bounds = prctile(chains.(postField)(:), [(100 - CI) / 2, CI + (100 - CI) / 2]);
fprintf('Firefox anchoring index mean %1.2f, 95%% CI (%1.2f, %1.2f), BF=%1.1f\n', ...
    mean(chains.(postField)(:)), bounds, BF);
end

function plot_ay_all_anchoring(d, pantone, storageDirs, fineTune)
CI = 95; critical = 0; fontSize = fineTune.font.allQanchoring;
bounds = zeros(d.nQuestions, 2);
BF = zeros(d.nQuestions, 1);
mn = zeros(d.nQuestions, 1);
[~, srtIdx] = sort(d.truth);

for qIdx = 1:d.nQuestions
    [chains, priorField, postField] = load_anchoring_chains(storageDirs, d.questionLabels{qIdx});
    if isempty(chains)
        [chains, priorField, postField] = load_anchoring_chains(storageDirs, qIdx);
    end
    if isempty(chains)
        error('Missing anchoring-index MCMC for question %d (%s)', qIdx, d.questionLabels{qIdx});
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
setFigure(F, [0.2 0.3 0.56 0.61], '');
set(F, 'renderer', 'opengl');
set(gca, 'ytick', 1:d.nQuestions, 'ylim', [1 d.nQuestions], ...
    'yticklabel', d.questionLabels(srtIdx), 'ydir', 'rev', 'xlim', [0 1], ...
    'xtick', 0:0.1:1, 'xticklabelrot', 0, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.01 0], 'fontsize', fontSize);
moveAxis(gca, [1 1 0.9 0.9], [0.05 0.1 0 0]);
xlabel('Anchoring Index', 'fontsize', fontSize + 2);
Raxes(gca, 0.05, 0.01);
for qIdx = 1:d.nQuestions
    plot(bounds(srtIdx(qIdx), :), [qIdx qIdx], '-', 'color', pantone.Aluminum, 'linewidth', 4);
    plot(mn(srtIdx(qIdx)), qIdx, 'o', 'markerfacecolor', pantone.PottersClay, ...
        'markeredgecolor', 'w', 'markersize', 12, 'linewidth', 1);
    if BF(srtIdx(qIdx)) > 1000
        str = sprintf(' BF_{10} > 1000\n');
    elseif BF(srtIdx(qIdx)) > 1
        str = sprintf(' BF_{10} = %1.1f\n', BF(srtIdx(qIdx)));
    else
        str = sprintf(' BF_{01} = %1.1f\n', 1 / BF(srtIdx(qIdx)));
    end
    text(0.9, qIdx + 0.5, str, 'vert', 'mid', 'fontsize', fontSize - 2);
end
end

function plot_ay_performance(d, pantone, peopleColor, storageDirs, fineTune)
fontSize = fineTune.font.performance; height = 1; width = 1;
fullCrowdColor = 'k';
noCrowdColor = peopleColor{3};
anchorCrowdColor = pantone.LapisBlue;
modelAColor = pantone.Sandstone;
rng(1);
e = d.participantRMSE;
crowdEst = zeros(d.nQuestions, 1);
crowdHLEst = zeros(d.nQuestions, 1);
crowdNEst = zeros(d.nQuestions, 1);
for qIdx = 1:d.nQuestions
    matchLong = find(d.questionLong == qIdx);
    y = d.estimateLong(matchLong);
    crowdEst(qIdx) = mean(y);
    % Match anchorYears_0.m / manuscript performance figure definition
    crowdHLEst(qIdx) = mean([d.estimate{qIdx, 2}, d.estimate{qIdx, 3}]);
    crowdNEst(qIdx) = mean(d.estimate{qIdx, 3});
end
omegaCrowd = sqrt(mean((crowdEst(:) - d.truth(:)).^2));
omegaHLCrowd = sqrt(mean((crowdHLEst(:) - d.truth(:)).^2));
omegaNCrowd = sqrt(mean((crowdNEst(:) - d.truth(:)).^2));

jagsCandidates = {
    'debiasing_anchorYears_jags.mat'
    'anchorYears_7b2_anchorYears_jags.mat'
    };
jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath), break; end
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for anchorYears');
end
fprintf('Loading %s\n', jagsPath);
S = load(jagsPath, 'chains');
chains = S.chains;
sigmaA = codatable(chains, 'sigma', @mean);
alphaA = codatable(chains, 'alpha', @mean);
[omegaAModel, omegaAModelCI] = model_rmse_from_mu(chains, d.truth, 'PosteriorCI', true);

empiricalAtmp = nan(d.nParticipants, d.nQuestions);
for pIdx = 1:d.nParticipants
    for qIdx = 1:d.nQuestions
        match = find(d.participantLong == pIdx & d.questionLong == qIdx);
        empiricalAtmp(pIdx, qIdx) = (d.estimateLong(match) - d.truth(qIdx)) / (d.anchorLong(match) - d.truth(qIdx));
    end
end
keepAnchored = find(d.participantGroup == 12);
tmp = nanmean(empiricalAtmp, 2);
empiricalA = tmp(keepAnchored);
alphaA = alphaA(keepAnchored);

F = figure; clf; hold on;
setFigure(F, [0.2 0.3 0.65 0.45], '');
set(F, 'renderer', 'opengl');  % FaceAlpha on model CI patch
set(gca, 'ycolor', 'none', 'xlim', [0 max(e) + 1], ...
    'xtick', unique(0:10:round(max(e), -1)), 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.01 0], 'clipping', 'off', 'fontsize', fontSize);
xlabel('Root Mean Squared Error', 'fontsize', fontSize + 2);
moveAxis(gca, [1 1 1 0.9], [0 0.075 0 0]);
Raxes(gca, 0.01, 0.01);
[count, ~, a] = histcounts(e, -0.5:ceil(max(e)) + 0.5);
for idx = 1:length(count)
    for i = 1:count(idx)
        match = find(a == idx);
        match = match(ceil(rand * length(match)));
        H = rectangle('position', [idx - 1 - width / 2, i - height / 2 - 0.5, width, height], ...
            'facecolor', pantone.DuskBlue, 'edgecolor', 0.2 * ones(1, 3), 'curvature', [0.2 0.2]);
        if d.participantGroup(match) == 3
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
text(omegaAModel, mult * yLim(2), ' anchoring model', 'fontsize', fontSize);
mult = 0.9;
H = plot([omegaHLCrowd omegaHLCrowd], mult * get(gca, 'ylim'), 'color', anchorCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(omegaHLCrowd, mult * yLim(2), ' anchor crowd', 'fontsize', fontSize);
mult = 0.85;
H = plot([omegaNCrowd omegaNCrowd], mult * get(gca, 'ylim'), 'color', noCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(omegaNCrowd, mult * yLim(2), ' no-anchor crowd', 'fontsize', fontSize);
mult = 0.95;
H = plot([omegaCrowd omegaCrowd], mult * get(gca, 'ylim'), 'color', fullCrowdColor, 'linewidth', 4); uistack(H, 'bottom');
text(omegaCrowd, mult * yLim(2), ' full crowd', 'fontsize', fontSize);

A = axes; hold on;
set(A, 'units', 'norm', 'position', [0.75 0.5 0.2 0.4], 'xlim', [0 75], 'xtick', [0 75], ...
    'xticklabel', {'hi', 'lo'}, 'xticklabelrot', 0, 'ylim', [0 75], 'ytick', [0 75], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', 'ticklength', [0.02 0], 'fontsize', fontSize);
axis square;
xlabel('inferred expertise', 'fontsize', fontSize);
ylabel('observed error', 'fontsize', fontSize);
shuffle = randperm(d.nParticipants);
for idx2 = 1:d.nParticipants
    idx = shuffle(idx2);
    H = plot(sigmaA(idx), d.participantRMSE(idx), 'o', 'markerfacecolor', pantone.DuskBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
    if d.participantGroup(idx) == 3
        set(H, 'markerfacecolor', peopleColor{3});
    end
end
Raxes(gca, 0.01, 0.01);
rS = corrcoef(sigmaA(:), d.participantRMSE(:), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rS(1, 2)), 'fontsize', fontSize, 'hor', 'left', 'vert', 'top');

A = axes; hold on;
set(A, 'units', 'norm', 'position', [0.5 0.5 0.2 0.4], 'xlim', [-1 1], 'xtick', [-1 0 1], ...
    'xticklabelrot', 0, 'ylim', [-1 1], 'ytick', [-1 0 1], 'box', 'off', 'tickdir', 'out', ...
    'ticklength', [0.02 0], 'fontsize', fontSize);
axis square;
xlabel('inferred anchoring', 'fontsize', fontSize);
ylabel('observed anchoring', 'fontsize', fontSize);
shuffle = randperm(length(keepAnchored));
for idx2 = 1:length(keepAnchored)
    idx = shuffle(idx2);
    plot(alphaA(idx), empiricalA(idx), 'o', 'markerfacecolor', pantone.DuskBlue, ...
        'markersize', 6, 'markeredgecolor', 'k');
end
Raxes(gca, 0.01, 0.01);
rA = corrcoef(alphaA(:), empiricalA(:), 'Rows', 'complete');
xl = xlim; yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', rA(1, 2)), 'fontsize', fontSize, 'hor', 'left', 'vert', 'top');
fprintf('Correlations (anchorYears): anchoring=%.4f, expertise=%.4f\n', rA(1, 2), rS(1, 2));
end

function plot_debiasing_model_schematic(pantone, fineTune)
% Schematic from anchorYears_0.m case 'debiasingModel'
fontSize = fineTune.font.debiasingModel;
anchor = 0.2; mu = 0.7;
muPrime = [0.74 0.575];
sigma = [0.025 0.1];
estimated = [0.58 0.39];
scale = 0.015; threshold = 1e-2; step = 0.001;
alphaList = [0.3 0.5];
rng(1);

F = figure;
setFigure(F, [.2 .2 .55 .55], ''); hold on;
set(F, 'renderer', 'opengl');
set(gca, 'units', 'norm', 'pos', [0.2 0.125 0.4 0.6], 'xlim', [0 1], 'ylim', [0 1], ...
    'xtick', [anchor mu], 'xticklabel', {'A', '\mu'}, 'yticklabel', {'A', '\mu'}, ...
    'ytick', [anchor mu], 'xticklabelrot', 0, 'tickdir', 'in', 'clipping', 'off', ...
    'box', 'off', 'xgrid', 'off', 'ygrid', 'off', 'xaxisloc', 'bot', 'fontsize', fontSize);
xlabel('True Value', 'Fontsize', fontSize + 2, 'vert', 'top');
ylabel('Estimated Value', 'Fontsize', fontSize + 2);
moveAxis(gca, [1 1 1 1], [0 0.025 0 0]);
Raxes(gca, 0.02, 0.01);

plot([0 1], [0 1], '--', 'color', pantone.GlacierGray);
plot([anchor 1], [anchor anchor], '--', 'color', pantone.GlacierGray);
x = anchor:step:1 - step;
xx = [x 1 1 x(end:-1:1)];
yy = [0.7 * anchor + (1 - 0.7) * x, 0.7 * anchor + (1 - 0.7) * 1, 0.1 * anchor + (1 - 0.1) * 1, 0.1 * anchor + (1 - 0.1) * x(end:-1:1)];
ph = patch(xx, yy, 'g'); set(ph, 'facecolor', pantone.Aquamarine, 'edgecolor', pantone.Aquamarine);
yy = [0.5 * anchor + (1 - 0.5) * x, 0.6 * anchor + (1 - 0.5) * 1, 0.3 * anchor + (1 - 0.3) * 1, 0.3 * anchor + (1 - 0.3) * x(end:-1:1)];
ph = patch(xx, yy, 'g'); set(ph, 'facecolor', pantone.DuskBlue, 'edgecolor', pantone.DuskBlue);
for idx = 1:numel(alphaList)
    text(1.02, (1 - alphaList(idx)) * 1 + alphaList(idx) * anchor, sprintf('$\\alpha_%d$', idx), ...
        'vert', 'mid', 'hor', 'left', 'interp', 'latex', 'fontsize', fontSize);
end
line(ones(1, 2) * muPrime(1), [1 estimated(1)], 'color', pantone.Marsala, 'linestyle', '--', 'linewidth', 2);
line([0.0 muPrime(1)], ones(1, 2) * estimated(1), 'color', pantone.Marsala, 'linestyle', '--', 'linewidth', 2);
line(ones(1, 2) * muPrime(2), [1 estimated(2)], 'color', pantone.Marsala, 'linestyle', '--', 'linewidth', 2);
line([0.0 muPrime(2)], ones(1, 2) * estimated(2), 'color', pantone.Marsala, 'linestyle', '--', 'linewidth', 2);
text(muPrime(1) + 0.01, 0.855, '$\mu^\prime_1$', 'vert', 'mid', 'hor', 'left', 'interp', 'latex', 'fontsize', fontSize + 2);
text(muPrime(2) - 0.01, 0.855, '$\mu^\prime_2$', 'vert', 'mid', 'hor', 'right', 'interp', 'latex', 'fontsize', fontSize + 2);
for sigmaIdx = 1:length(sigma)
    y = 0.6 * 1 / sigma(sigmaIdx) * exp(-(mu - x).^2 / sigma(sigmaIdx)^2);
    keep = find(y > threshold);
    patch([x(keep) 1 x(keep(1))], 1.025 + scale * [y(keep) 0 y(keep(1))], '-', ...
        'facecolor', pantone.SpicyMustard, 'facealpha', 0.5, 'edgecolor', 'none', 'linewidth', 2);
    plot(x(keep), 1.025 + scale * y(keep), '-', 'color', pantone.SpicyMustard, 'linewidth', 2);
end
plot(mu, 1.025, 'o', 'markerfacecolor', pantone.Greenery, 'markeredgecolor', 'w', 'markersize', 12);
text(mu, 1, '$\mu$', 'vert', 'top', 'hor', 'cen', 'interp', 'latex', 'fontsize', fontSize + 2);
for idx = 1:numel(estimated)
    plot(-0.025, estimated(idx), '+', 'color', pantone.AuroraRed, 'linewidth', 4, 'markersize', 12);
    text(0.02, estimated(idx) + 0.02, sprintf('$y_%d$', idx), 'vert', 'bot', 'hor', 'cen', ...
        'interp', 'latex', 'fontsize', fontSize + 2);
end
plot(mu + [1 -1] * 0.08, ones(1, 2) * 1.075, '-', 'color', pantone.AuroraRed, 'linewidth', 1);
text(mu + 0.08 + 0.04, 1.075, '$\sigma_2$', 'vert', 'mid', 'hor', 'cen', 'interp', 'latex', 'fontsize', fontSize + 2);
plot(mu + [1 -1] * 0.02, ones(1, 2) * 1.25, '-', 'color', pantone.AuroraRed, 'linewidth', 1);
text(mu + 0.02 + 0.04, 1.25, '$\sigma_1$', 'vert', 'mid', 'hor', 'cen', 'interp', 'latex', 'fontsize', fontSize + 2);
end
