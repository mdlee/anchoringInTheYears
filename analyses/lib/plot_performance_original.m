function plot_performance_original(repoRoot, storageDirs, printFigures, fineTune)
%PLOT_PERFORMANCE_ORIGINAL Single-panel WOC figure for the original event-years study.
% Person RMSE histogram (anchored vs no-anchor), debiasing model + CI,
% full / anchor / no-anchor aggregates, and expertise + anchoring insets.
% Matches the original-submission performance figure layout.
%
% Graphics: default_performance_original_graphics; override via
% fineTune.performanceOriginal.

if nargin < 3 || isempty(printFigures), printFigures = true; end
if nargin < 4 || isempty(fineTune), fineTune = default_fine_tune(); end

dataDir = fullfile(repoRoot, 'data');
load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');

g = default_performance_original_graphics(pantone);
if isfield(fineTune, 'performanceOriginal')
    g = merge_struct_local(g, fineTune.performanceOriginal);
end
% Optional legacy fineTune.performance inset / font knobs (not xlim/xtick —
% those are for percentageEstimationF2025).
if isfield(fineTune, 'performance')
    p = fineTune.performance;
    if isfield(p, 'insetExpertise') && isfield(p.insetExpertise, 'bottomLeft')
        g.insetExpertise.bottomLeft = p.insetExpertise.bottomLeft;
    end
    if isfield(p, 'insetAnchoring') && isfield(p.insetAnchoring, 'bottomLeft')
        g.insetAnchoring.bottomLeft = p.insetAnchoring.bottomLeft;
    end
    if isfield(p, 'insetWidth'), g.insetWidth = p.insetWidth; end
    if isfield(p, 'insetHeight'), g.insetHeight = p.insetHeight; end
    if isfield(p, 'font')
        if isfield(p.font, 'axis'), g.font.axis = p.font.axis; end
        if isfield(p.font, 'xlabel'), g.font.xlabel = p.font.xlabel; end
        if isfield(p.font, 'crowdLabel'), g.font.crowdLabel = p.font.crowdLabel; end
        if isfield(p.font, 'insetAxis'), g.font.inset = p.font.insetAxis; end
        if isfield(p.font, 'insetLabel'), g.font.insetLabel = p.font.insetLabel; end
        if isfield(p.font, 'insetCorr'), g.font.insetCorr = p.font.insetCorr; end
    end
end
if isfield(fineTune, 'font') && isfield(fineTune.font, 'performance') ...
        && ~isempty(fineTune.font.performance)
    g.font.axis = fineTune.font.performance;
    g.font.xlabel = fineTune.font.performance + 2;
    g.font.crowdLabel = fineTune.font.performance;
    g.font.inset = fineTune.font.performance;
    g.font.insetLabel = fineTune.font.performance;
    g.font.insetCorr = fineTune.font.performance;
end

S = compute_original_stats(d, storageDirs, { ...
    'debiasing_anchorYears_jags.mat'
    'anchorYears_7b2_anchorYears_jags.mat'
    });

xMax = max([max(S.e), S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel]) + g.xlimPad;
xMax = max(xMax, g.xlimMin);
if ~isempty(g.xlim) && numel(g.xlim) == 2
    xLim = g.xlim;
else
    xLim = [0 xMax];
end
if ~isempty(g.xtick)
    xTick = g.xtick;
else
    xTick = unique(0:g.xtickStep:round(xLim(2), -1));
end

F = figure; clf;
try
    set_figure_safe(F, g.figure.position, '');
catch
    set(F, 'units', 'normalized', 'position', g.figure.position, 'color', 'w');
end
set(F, 'Units', 'pixels', 'Position', g.figure.pixelPosition, 'PaperPositionMode', 'auto');
try, set(F, 'renderer', 'opengl'); catch, end

draw_original_panel(F, S, g, xLim, xTick);

outDir = results_dir(repoRoot, 'performance');
print_figure(outDir, 'allQPerformanceComparisonAnchor_AllQuestions', printFigures);
write_original_report(outDir, S);
end


function S = compute_original_stats(d, storageDirs, jagsCandidates)
S.tag = 'original';
S.e = d.participantRMSE(:);
S.participantGroup = d.participantGroup(:);

crowdEst = zeros(d.nQuestions, 1);
crowdHLEst = zeros(d.nQuestions, 1);
crowdNEst = zeros(d.nQuestions, 1);
for qIdx = 1:d.nQuestions
    y = d.estimateLong(d.questionLong == qIdx);
    crowdEst(qIdx) = mean(y);
    crowdHLEst(qIdx) = mean([d.estimate{qIdx, 1}(:); d.estimate{qIdx, 2}(:)]);
    crowdNEst(qIdx) = mean(d.estimate{qIdx, 3}(:));
end
S.omegaCrowd = sqrt(mean((crowdEst(:) - d.truth(:)) .^ 2));
S.omegaHLCrowd = sqrt(mean((crowdHLEst(:) - d.truth(:)) .^ 2));
S.omegaNCrowd = sqrt(mean((crowdNEst(:) - d.truth(:)) .^ 2));

jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath), break; end
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for original event-years');
end
fprintf('Loading %s (original)\n', jagsPath);
Sj = load(jagsPath, 'chains');
chains = Sj.chains;
S.sigmaA = codatable(chains, 'sigma', @mean);
S.alphaA = codatable(chains, 'alpha', @mean);
[S.omegaAModel, S.omegaAModelCI] = model_rmse_from_mu(chains, d.truth, 'PosteriorCI', true);

keepAnchored = find(d.participantGroup == 12 | d.participantGroup == 1 | d.participantGroup == 2);
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
S.keepAnchored = keepAnchored(:);
S.empiricalA = mean(empiricalAtmp(keepAnchored, :), 2, 'omitnan');
S.alphaPlot = S.alphaA(keepAnchored);
S.sigmaPlot = S.sigmaA(:);
S.eExpertise = S.e;
S.groupExpertise = S.participantGroup;

fprintf('original RMSE: full=%.2f  anchor=%.2f  no-anchor=%.2f  debiasing=%.2f', ...
    S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel);
if ~isempty(S.omegaAModelCI)
    fprintf(' [%.2f, %.2f]', S.omegaAModelCI(1), S.omegaAModelCI(2));
end
fprintf('\n');
end


function draw_original_panel(F, S, g, xLim, xTick)
rng(g.rngSeed);
height = g.person.height;
width = g.person.width;

ax = axes('Parent', F, 'Units', 'normalized', 'Position', g.mainAxis.position);
hold(ax, 'on');
set(ax, 'ycolor', 'none', 'xlim', xLim, 'xtick', xTick, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', g.tickLength, ...
    'clipping', 'off', 'fontsize', g.font.axis);
xlabel(ax, g.xlabel, 'fontsize', g.font.xlabel);
try, Raxes(ax, g.raxes.x, g.raxes.y); catch, end
set(ax, 'clipping', 'off');

e = S.e(:);
grp = S.participantGroup(:);
binEdges = -0.5:ceil(max(e)) + 0.5;
[~, ~, binIdx] = histcounts(e, binEdges);
nBins = numel(binEdges) - 1;
stack = zeros(nBins, 1);
order = [find(grp == 3); find(grp ~= 3)];
for ii = 1:numel(order)
    i = order(ii);
    b = binIdx(i);
    if b < 1 || b > nBins, continue; end
    xPos = binEdges(b) + 0.5;
    if xPos < xLim(1) || xPos > xLim(2), continue; end
    stack(b) = stack(b) + height;
    if grp(i) == 3
        face = g.color.personNoAnchor;
    else
        face = g.color.personAnchored;
    end
    rectangle(ax, 'position', ...
        [xPos - width / 2, stack(b) - height / 2 - 0.5, width, height], ...
        'facecolor', face, 'edgecolor', g.person.edgeColor, ...
        'curvature', g.person.curvature, 'clipping', 'off', ...
        'linewidth', g.person.edgeWidth);
end

yLim = get(ax, 'ylim');
yLim(1) = 0;
yLim(2) = max(max(stack) * g.yLimPad, g.yLimMin);
if ~isempty(g.ylim) && numel(g.ylim) == 2 && isfinite(g.ylim(2))
    yLim(2) = g.ylim(2);
end
set(ax, 'ylim', yLim);

if ~isempty(S.omegaAModelCI) && all(isfinite(S.omegaAModelCI))
    Hci = patch(ax, ...
        [S.omegaAModelCI(1) S.omegaAModelCI(2) S.omegaAModelCI(2) S.omegaAModelCI(1)], ...
        [yLim(1) yLim(1) yLim(2) yLim(2)], g.color.model, ...
        'EdgeColor', 'none', 'FaceAlpha', g.ci.faceAlpha);
    uistack(Hci, 'bottom');
end

refs = {
    S.omegaAModel,   g.color.model,          g.label.model,    g.line.modelMult
    S.omegaHLCrowd,  g.color.anchorCrowd,    g.label.anchor,   g.line.anchorMult
    S.omegaCrowd,    g.color.fullCrowd,      g.label.full,     g.line.fullMult
    S.omegaNCrowd,   g.color.noAnchorCrowd,  g.label.noAnchor, g.line.noAnchorMult
    };
for k = 1:size(refs, 1)
    xk = refs{k, 1};
    if ~isfinite(xk), continue; end
    plot(ax, [xk xk], [yLim(1), refs{k, 4} * yLim(2)], ...
        'color', refs{k, 2}, 'linewidth', g.lineWidth);
    text(ax, xk, refs{k, 4} * yLim(2), refs{k, 3}, ...
        'fontsize', g.font.crowdLabel, 'color', refs{k, 2}, ...
        'Clipping', 'off', 'vert', 'bottom', 'hor', 'left');
end

draw_expertise_inset(F, S, g);
draw_anchoring_inset(F, S, g);
end


function draw_expertise_inset(F, S, g)
bl = g.insetExpertise.bottomLeft(:).';
pos = [bl(1), bl(2), g.insetWidth, g.insetHeight];
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
xHi = max(g.insetExpertise.xlim(2), ceil(max(S.sigmaPlot)));
yHi = max(g.insetExpertise.ylim(2), ceil(max(S.eExpertise)));
set(A, 'xlim', [0 xHi], 'xtick', [0 xHi], 'xticklabel', {'hi', 'lo'}, ...
    'xticklabelrot', 0, 'ylim', [0 yHi], 'ytick', [0 yHi], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', g.insetTickLength, 'clipping', 'off', 'fontsize', g.font.inset);
axis(A, 'square');
xlabel(A, 'inferred expertise', 'fontsize', g.font.insetLabel);
ylabel(A, 'observed error', 'fontsize', g.font.insetLabel);

shuffle = randperm(numel(S.eExpertise));
for idx2 = 1:numel(S.eExpertise)
    idx = shuffle(idx2);
    if S.groupExpertise(idx) == 3
        face = g.color.personNoAnchor;
    else
        face = g.color.personAnchored;
    end
    plot(A, S.sigmaPlot(idx), S.eExpertise(idx), 'o', ...
        'markerfacecolor', face, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge);
end
try, Raxes(A, 0.01, 0.01); catch, end
set(A, 'clipping', 'off');
rS = corrcoef(S.sigmaPlot(:), S.eExpertise(:), 'Rows', 'complete');
xl = xlim(A); yl = ylim(A);
text(A, xl(1), yl(2), sprintf('r=%.2f', rS(1, 2)), ...
    'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');
end


function draw_anchoring_inset(F, S, g)
bl = g.insetAnchoring.bottomLeft(:).';
pos = [bl(1), bl(2), g.insetWidth, g.insetHeight];
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
set(A, 'xlim', [-1 1], 'xtick', [-1 0 1], 'xticklabelrot', 0, ...
    'ylim', [-1 1], 'ytick', [-1 0 1], 'box', 'off', 'tickdir', 'out', ...
    'ticklength', g.insetTickLength, 'clipping', 'off', 'fontsize', g.font.inset);
axis(A, 'square');
xlabel(A, 'inferred anchoring', 'fontsize', g.font.insetLabel);
ylabel(A, 'observed anchoring', 'fontsize', g.font.insetLabel);

shuffle = randperm(numel(S.keepAnchored));
for idx2 = 1:numel(S.keepAnchored)
    idx = shuffle(idx2);
    plot(A, S.alphaPlot(idx), S.empiricalA(idx), 'o', ...
        'markerfacecolor', g.color.personAnchored, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge);
end
try, Raxes(A, 0.01, 0.01); catch, end
set(A, 'clipping', 'off');
rA = corrcoef(S.alphaPlot(:), S.empiricalA(:), 'Rows', 'complete');
xl = xlim(A); yl = ylim(A);
text(A, xl(1), yl(2), sprintf('r=%.2f', rA(1, 2)), ...
    'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');
end


function write_original_report(outDir, S)
outTxt = fullfile(outDir, 'original.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    warning('Could not write %s', outTxt);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
ci = '';
if ~isempty(S.omegaAModelCI) && all(isfinite(S.omegaAModelCI))
    ci = sprintf(' [%.2f, %.2f]', S.omegaAModelCI(1), S.omegaAModelCI(2));
end
fprintf(fid, 'original event-years: WOC / debiasing RMSE\n\n');
fprintf(fid, 'full=%.2f  anchor=%.2f  no-anchor=%.2f  debiasing=%.2f%s\n', ...
    S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel, ci);
fprintf('Wrote %s\n', outTxt);
end


function g = default_performance_original_graphics(pantone)
g.figure.position = [0.2 0.3 0.65 0.45];
g.figure.pixelPosition = [80 80 1200 700];
g.mainAxis.position = [0.08 0.14 0.88 0.78];
g.xlabel = 'Root Mean Squared Error';
g.tickLength = [0.01 0];
g.raxes.x = 0.01;
g.raxes.y = 0.01;
g.rngSeed = 1;

g.xlim = [];
g.xlimMin = 40;
g.xlimPad = 1;
g.xtick = [];
g.xtickStep = 10;
g.ylim = [0 NaN];
g.yLimPad = 1.35;
g.yLimMin = 8;

g.person.width = 1;
g.person.height = 1;
g.person.curvature = [0.2 0.2];
g.person.edgeColor = 0.2 * ones(1, 3);
g.person.edgeWidth = 0.5;
g.color.personAnchored = pantone.DuskBlue;
g.color.personNoAnchor = pantone.Hazelnut;
g.color.model = pantone.Sandstone;
g.color.anchorCrowd = pantone.LapisBlue;
g.color.fullCrowd = [0 0 0];
g.color.noAnchorCrowd = pantone.Hazelnut;
g.ci.faceAlpha = 0.22;

g.lineWidth = 4;
g.line.modelMult = 1.05;
g.line.anchorMult = 0.95;
g.line.fullMult = 0.90;
g.line.noAnchorMult = 0.85;
g.label.model = ' debiasing';
g.label.anchor = ' anchor crowd';
g.label.full = ' full crowd';
g.label.noAnchor = ' no-anchor crowd';

g.font.axis = 16;
g.font.xlabel = 18;
g.font.crowdLabel = 16;
g.font.inset = 16;
g.font.insetLabel = 16;
g.font.insetCorr = 16;

% Classic upper-right insets (figure-normalized)
g.insetExpertise.bottomLeft = [0.75 0.50];
g.insetAnchoring.bottomLeft = [0.50 0.50];
g.insetWidth = 0.20;
g.insetHeight = 0.40;
g.insetTickLength = [0.02 0];
g.insetMarkerSize = 6;
g.insetMarkerEdge = 'k';
g.insetExpertise.xlim = [0 75];
g.insetExpertise.ylim = [0 75];
end


function out = merge_struct_local(base, over)
out = base;
if isempty(over), return; end
fn = fieldnames(over);
for i = 1:numel(fn)
    name = fn{i};
    if isstruct(over.(name)) && isfield(out, name) && isstruct(out.(name))
        out.(name) = merge_struct_local(out.(name), over.(name));
    else
        out.(name) = over.(name);
    end
end
end
