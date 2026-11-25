function plot_performance_original_replication(repoRoot, storageDirs, printFigures, fineTune)
%PLOT_PERFORMANCE_ORIGINAL_REPLICATION 2x1 WOC: original (A) vs replication (B).
% Each panel: person RMSE histogram, debiasing model RMSE + shaded CI,
% full / anchor / no-anchor crowd aggregates, and expertise + anchoring insets.
%
% The original study's no-anchor cohort is shared: it appears in both
% histograms (Hazelnut) and supplies the no-anchor aggregate in both panels.
% Replication "full" crowd = F2026 anchored answers + original no-anchor
% answers; replication "anchor" = F2026 lo/hi only.
%
% Graphics: default_performance_original_replication_graphics; override via
% fineTune.performanceOriginalReplication.

if nargin < 3 || isempty(printFigures), printFigures = true; end
if nargin < 4 || isempty(fineTune), fineTune = default_fine_tune(); end

dataDir = fullfile(repoRoot, 'data');
load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
dOrig = d;
load(fullfile(dataDir, 'anchorYearsF2026.mat'), 'd');
dRep = d;
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');

g = default_performance_original_replication_graphics(pantone);
if isfield(fineTune, 'performanceOriginalReplication')
    g = merge_struct_local(g, fineTune.performanceOriginalReplication);
end
if isfield(fineTune, 'font') && isfield(fineTune.font, 'performance') ...
        && ~isempty(fineTune.font.performance)
    g.font.axis = fineTune.font.performance;
    g.font.xlabel = fineTune.font.performance + 2;
    g.font.crowdLabel = fineTune.font.performance;
    g.font.inset = fineTune.font.performance - 2;
    g.font.insetLabel = fineTune.font.performance - 2;
    g.font.insetCorr = fineTune.font.performance - 2;
    g.font.panelLetter = max(fineTune.font.performance + 2, 18);
end

Sorig = compute_panel_stats(dOrig, storageDirs, { ...
    'debiasing_anchorYears_jags.mat'
    'anchorYears_7b2_anchorYears_jags.mat'
    }, 'original', []);
Srep = compute_panel_stats(dRep, storageDirs, { ...
    'debiasing_anchorYearsF2026_jags.mat'
    'debiasing_anchorYearsF2026AnchoredOnly_jags.mat'
    }, 'replication', dOrig);

xMax = max([max(Sorig.eHist), max(Srep.eHist), ...
    Sorig.omegaCrowd, Sorig.omegaHLCrowd, Sorig.omegaNCrowd, Sorig.omegaAModel, ...
    Srep.omegaCrowd, Srep.omegaHLCrowd, Srep.omegaNCrowd, Srep.omegaAModel]) + g.xlimPad;
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
% Painters keeps marker glyphs circular under export (OpenGL can squash them).
try, set(F, 'renderer', 'painters'); catch, end

% Replication expertise inset shares original no-anchor points (Hazelnut),
% matching the histogram / crowd aggregates.
noMask = Sorig.groupExpertise(:) == 3;
if any(noMask)
    Srep.sigmaPlot = [Srep.sigmaPlot(:); Sorig.sigmaPlot(noMask)];
    Srep.eExpertise = [Srep.eExpertise(:); Sorig.eExpertise(noMask)];
    Srep.groupExpertise = [Srep.groupExpertise(:); Sorig.groupExpertise(noMask)];
end

draw_panel(F, g.panel.A, Sorig, g, xLim, xTick, false);
draw_panel(F, g.panel.B, Srep, g, xLim, xTick, true);

annotation(F, 'textbox', [g.panelLetter.A.xy 0.28 0.04], ...
    'String', g.panelLetter.A.str, 'FontSize', g.font.panelLetter, ...
    'FontWeight', 'bold', 'EdgeColor', 'none', 'VerticalAlignment', 'bottom');
annotation(F, 'textbox', [g.panelLetter.B.xy 0.28 0.04], ...
    'String', g.panelLetter.B.str, 'FontSize', g.font.panelLetter, ...
    'FontWeight', 'bold', 'EdgeColor', 'none', 'VerticalAlignment', 'bottom');

outDir = results_dir(repoRoot, 'performance');
print_figure(outDir, 'allQPerformanceComparison_originalReplication_2x1', printFigures);
write_report(outDir, Sorig, Srep);
end


function S = compute_panel_stats(d, storageDirs, jagsCandidates, tag, dNoAnchorSrc)
% dNoAnchorSrc: [] for original; original d for replication (shared no-anchor).

S.tag = tag;
S.isReplication = ~isempty(dNoAnchorSrc);

if S.isReplication
    dNo = dNoAnchorSrc;
    noMask = dNo.participantGroup(:) == 3;
    S.eNo = dNo.participantRMSE(noMask);
    S.eNo = S.eNo(:);
    S.eAnchored = d.participantRMSE(:);
    S.eHist = [S.eAnchored; S.eNo];
    S.groupHist = [12 * ones(numel(S.eAnchored), 1); 3 * ones(numel(S.eNo), 1)];

    crowdEst = zeros(d.nQuestions, 1);
    crowdHLEst = zeros(d.nQuestions, 1);
    crowdNEst = zeros(d.nQuestions, 1);
    for qIdx = 1:d.nQuestions
        yA = d.estimateLong(d.questionLong == qIdx);
        yNo = dNo.estimateLong(dNo.groupLong == 3 & dNo.questionLong == qIdx);
        crowdHLEst(qIdx) = mean(yA);
        crowdNEst(qIdx) = mean(yNo);
        crowdEst(qIdx) = mean([yA(:); yNo(:)]);
    end
    S.omegaHLCrowd = sqrt(mean((crowdHLEst(:) - d.truth(:)) .^ 2));
    S.omegaNCrowd = sqrt(mean((crowdNEst(:) - d.truth(:)) .^ 2));
    S.omegaCrowd = sqrt(mean((crowdEst(:) - d.truth(:)) .^ 2));
else
    S.eHist = d.participantRMSE(:);
    S.groupHist = d.participantGroup(:);
    S.eNo = d.participantRMSE(d.participantGroup(:) == 3);
    S.eNo = S.eNo(:);
    S.eAnchored = d.participantRMSE(d.participantGroup(:) ~= 3);
    S.eAnchored = S.eAnchored(:);

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
end

jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath), break; end
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for %s', tag);
end
fprintf('Loading %s (%s)\n', jagsPath, tag);
Sj = load(jagsPath, 'chains');
chains = Sj.chains;
S.sigmaA = codatable(chains, 'sigma', @mean);
S.alphaA = codatable(chains, 'alpha', @mean);
[S.omegaAModel, S.omegaAModelCI] = model_rmse_from_mu(chains, d.truth, 'PosteriorCI', true);

% Inset data from the model dataset d (not the shared no-anchor people).
keepAnchored = find(d.participantGroup == 12 | d.participantGroup == 1 | d.participantGroup == 2);
if isempty(keepAnchored)
    keepAnchored = (1:d.nParticipants)';
end
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
nAlpha = numel(S.alphaA);
if nAlpha == numel(keepAnchored)
    S.alphaPlot = S.alphaA(:);
elseif nAlpha >= max(keepAnchored)
    S.alphaPlot = S.alphaA(keepAnchored);
else
    error('%s: alpha length %d incompatible with nAnchored %d', tag, nAlpha, numel(keepAnchored));
end
nSigma = numel(S.sigmaA);
if nSigma == d.nParticipants
    S.sigmaPlot = S.sigmaA(:);
    S.eExpertise = d.participantRMSE(:);
    S.groupExpertise = d.participantGroup(:);
elseif nSigma == numel(keepAnchored)
    S.sigmaPlot = S.sigmaA(:);
    S.eExpertise = d.participantRMSE(keepAnchored);
    S.eExpertise = S.eExpertise(:);
    S.groupExpertise = d.participantGroup(keepAnchored);
    S.groupExpertise = S.groupExpertise(:);
else
    error('%s: sigma length %d incompatible with nPart %d / nAnchored %d', ...
        tag, nSigma, d.nParticipants, numel(keepAnchored));
end

fprintf('%s RMSE: full=%.2f  anchor=%.2f  no-anchor=%.2f  debiasing=%.2f', ...
    tag, S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel);
if ~isempty(S.omegaAModelCI)
    fprintf(' [%.2f, %.2f]', S.omegaAModelCI(1), S.omegaAModelCI(2));
end
fprintf('\n');
end


function draw_panel(F, panel, S, g, xLim, xTick, isReplication)
rng(g.rngSeed);
% Bottom panel has fewer people, so autoscaled ylim would inflate rectangles;
% use half height and keep ylim as if full height so they match the top visually.
heightScale = 1;
if isReplication
    heightScale = g.person.replicationHeightScale;
end
height = g.person.height * heightScale;
width = g.person.width;

axPos = map_to_panel(g.mainAxis.position, panel);
ax = axes('Parent', F, 'Units', 'normalized', 'Position', axPos);
hold(ax, 'on');
set(ax, 'ycolor', 'none', 'xlim', xLim, 'xtick', xTick, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', g.tickLength, ...
    'clipping', 'off', 'fontsize', g.font.axis);
if isReplication
    xlabel(ax, g.xlabel, 'fontsize', g.font.xlabel);
end
try, Raxes(ax, g.raxes.x, g.raxes.y); catch, end
set(ax, 'clipping', 'off');

e = S.eHist(:);
grp = S.groupHist(:);
binEdges = -0.5:ceil(max(e)) + 0.5;
[~, ~, binIdx] = histcounts(e, binEdges);
nBins = numel(binEdges) - 1;
stack = zeros(nBins, 1);

order = [find(grp == 3); find(grp ~= 3)];
for ii = 1:numel(order)
    i = order(ii);
    b = binIdx(i);
    if b < 1 || b > nBins
        continue;
    end
    xPos = binEdges(b) + 0.5;
    if xPos < xLim(1) || xPos > xLim(2)
        continue;
    end
    stack(b) = stack(b) + height;
    if grp(i) == 3
        face = g.color.personNoAnchor;
    elseif isReplication
        face = g.color.personReplication;
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
yLim(2) = max(max(stack) / heightScale * g.yLimPad, g.yLimMin);
if ~isempty(g.ylim) && numel(g.ylim) == 2 && isfinite(g.ylim(2))
    yLim(2) = g.ylim(2);
end
set(ax, 'ylim', yLim);

if isReplication
    modelCol = g.color.modelReplication;
    ciAlpha = g.ci.replicationAlpha;
else
    modelCol = g.color.modelOriginal;
    ciAlpha = g.ci.originalAlpha;
end

if ~isempty(S.omegaAModelCI) && all(isfinite(S.omegaAModelCI))
    Hci = patch(ax, ...
        [S.omegaAModelCI(1) S.omegaAModelCI(2) S.omegaAModelCI(2) S.omegaAModelCI(1)], ...
        [yLim(1) yLim(1) yLim(2) yLim(2)], modelCol, ...
        'EdgeColor', 'none', 'FaceAlpha', ciAlpha);
    uistack(Hci, 'bottom');
end

refs = {
    S.omegaAModel,   modelCol,                 g.label.model,    g.line.modelMult
    S.omegaHLCrowd,  g.color.anchorCrowd,      g.label.anchor,   g.line.anchorMult
    S.omegaCrowd,    g.color.fullCrowd,        g.label.full,     g.line.fullMult
    S.omegaNCrowd,   g.color.noAnchorCrowd,    g.label.noAnchor, g.line.noAnchorMult
    };
for k = 1:size(refs, 1)
    xk = refs{k, 1};
    if ~isfinite(xk), continue; end
    col = refs{k, 2};
    lab = refs{k, 3};
    mult = refs{k, 4};
    plot(ax, [xk xk], [yLim(1), mult * yLim(2)], ...
        'color', col, 'linewidth', g.lineWidth);
    text(ax, xk + g.label.xOffset, mult * yLim(2), lab, ...
        'fontsize', g.font.crowdLabel, 'color', col, 'Clipping', 'off', ...
        'vert', g.label.vert, 'hor', g.label.hor);
end

draw_expertise_inset(F, panel, S, g, isReplication);
draw_anchoring_inset(F, panel, S, g, isReplication);
end


function draw_expertise_inset(F, panel, S, g, isReplication)
pos = inset_pos_square_pixels(g, g.insetExpertise.bottomLeft, panel);
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
xHi = max(g.insetExpertise.xlim(2), ceil(max(S.sigmaPlot)));
yHi = max(g.insetExpertise.ylim(2), ceil(max(S.eExpertise)));
limHi = max(xHi, yHi); % equal spans so plot box top matches anchoring inset
set(A, 'xlim', [0 limHi], 'xtick', [0 limHi], 'xticklabel', {'hi', 'lo'}, ...
    'xticklabelrot', 0, 'ylim', [0 limHi], 'ytick', [0 limHi], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', g.insetTickLength, 'clipping', 'off', 'fontsize', g.font.inset);
xlabel(A, g.insetExpertise.xlabel, 'fontsize', g.font.insetLabel);
ylabel(A, g.insetExpertise.ylabel, 'fontsize', g.font.insetLabel);

shuffle = randperm(numel(S.eExpertise));
for idx2 = 1:numel(S.eExpertise)
    idx = shuffle(idx2);
    if S.groupExpertise(idx) == 3
        face = g.color.personNoAnchor;
    elseif isReplication
        face = g.color.personReplication;
    else
        face = g.color.personAnchored;
    end
    plot(A, S.sigmaPlot(idx), S.eExpertise(idx), 'o', ...
        'markerfacecolor', face, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge, 'Marker', 'o');
end
try, Raxes(A, g.insetRaxes.x, g.insetRaxes.y); catch, end
% Equal data aspect + fixed Position (already square in pixels) → circular markers.
set(A, 'Units', 'normalized', 'Position', pos, 'clipping', 'off', ...
    'DataAspectRatio', [1 1 1], 'DataAspectRatioMode', 'manual', ...
    'PlotBoxAspectRatio', [1 1 1], 'PlotBoxAspectRatioMode', 'manual');
rS = corrcoef(S.sigmaPlot(:), S.eExpertise(:), 'Rows', 'complete');
% Same normalized corner as anchoring inset → matching on-screen y within each panel.
text(A, g.insetCorr.xFrac, 1, sprintf('r=%.2f', rS(1, 2)), ...
    'Units', 'normalized', 'fontsize', g.font.insetCorr, ...
    'hor', 'left', 'vert', 'top');
end


function draw_anchoring_inset(F, panel, S, g, isReplication)
pos = inset_pos_square_pixels(g, g.insetAnchoring.bottomLeft, panel);
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
set(A, 'xlim', g.insetAnchoring.xlim, 'xtick', g.insetAnchoring.xtick, ...
    'xticklabelrot', 0, 'ylim', g.insetAnchoring.ylim, 'ytick', g.insetAnchoring.ytick, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', g.insetTickLength, ...
    'clipping', 'off', 'fontsize', g.font.inset);
xlabel(A, g.insetAnchoring.xlabel, 'fontsize', g.font.insetLabel);
ylabel(A, g.insetAnchoring.ylabel, 'fontsize', g.font.insetLabel);

if isReplication
    face = g.color.personReplication;
else
    face = g.color.personAnchored;
end
shuffle = randperm(numel(S.keepAnchored));
for idx2 = 1:numel(S.keepAnchored)
    idx = shuffle(idx2);
    plot(A, S.alphaPlot(idx), S.empiricalA(idx), 'o', ...
        'markerfacecolor', face, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge, 'Marker', 'o');
end
try, Raxes(A, g.insetRaxes.x, g.insetRaxes.y); catch, end
set(A, 'Units', 'normalized', 'Position', pos, 'clipping', 'off', ...
    'DataAspectRatio', [1 1 1], 'DataAspectRatioMode', 'manual', ...
    'PlotBoxAspectRatio', [1 1 1], 'PlotBoxAspectRatioMode', 'manual');
rA = corrcoef(S.alphaPlot(:), S.empiricalA(:), 'Rows', 'complete');
text(A, g.insetCorr.xFrac, 1, sprintf('r=%.2f', rA(1, 2)), ...
    'Units', 'normalized', 'fontsize', g.font.insetCorr, ...
    'hor', 'left', 'vert', 'top');
end


function pos = map_to_panel(rel, panel)
rel = rel(:).';
panel = panel(:).';
pos = [panel(1) + panel(3) * rel(1), ...
    panel(2) + panel(4) * rel(2), ...
    panel(3) * rel(3), ...
    panel(4) * rel(4)];
end


function pos = inset_pos_square_pixels(g, bottomLeft, panel)
% Map inset into panel with on-screen width == height (circular markers),
% without letting axis square relocate the axes box.
panel = panel(:).';
figW = g.figure.pixelPosition(3);
figH = g.figure.pixelPosition(4);
panelPxW = panel(3) * figW;
panelPxH = panel(4) * figH;
wRel = g.insetWidth;
hRel = (wRel * panelPxW) / max(panelPxH, eps);
pos = map_to_panel([bottomLeft(:).' wRel hRel], panel);
end


function write_report(outDir, Sorig, Srep)
outTxt = fullfile(outDir, 'originalReplication_2x1.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    warning('Could not write %s', outTxt);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'original vs replication (2x1): WOC / debiasing RMSE\n');
fprintf(fid, 'Replication shares the original no-anchor cohort for the histogram\n');
fprintf(fid, 'and for no-anchor / full-crowd aggregates.\n\n');
fprintf(fid, '%-14s %10s %10s %12s %10s\n', ...
    'dataset', 'full', 'anchor', 'no-anchor', 'debiasing');
write_row(fid, Sorig);
write_row(fid, Srep);
fprintf('Wrote %s\n', outTxt);
end


function write_row(fid, S)
ci = '';
if ~isempty(S.omegaAModelCI) && all(isfinite(S.omegaAModelCI))
    ci = sprintf(' [%.2f, %.2f]', S.omegaAModelCI(1), S.omegaAModelCI(2));
end
fprintf(fid, '%-14s %10.2f %10.2f %12.2f %10.2f%s\n', ...
    S.tag, S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel, ci);
end


function g = default_performance_original_replication_graphics(pantone)
g.figure.position = [0.05 0.02 0.72*0.95 0.88*0.95];
g.figure.pixelPosition = [40 40 round(1600*0.95) round(1120*0.95)];
g.panel.A = [0.01 0.51 0.98 0.47];
g.panel.B = [0.01 0.02 0.98 0.47];
g.panelLetter.A.xy = [0.01 0.955];
g.panelLetter.B.xy = [0.01 0.465];
g.panelLetter.A.str = 'A  Original';
g.panelLetter.B.str = 'B  Replication';
g.mainAxis.position = [0.09 0.14 0.84 0.74];
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
g.yLimPad = 1.48;
g.yLimMin = 8;

g.person.width = 1;
g.person.height = 1;
g.person.replicationHeightScale = 0.5;
g.person.curvature = [0.2 0.2];
g.person.edgeColor = 0.2 * ones(1, 3);
g.person.edgeWidth = 0.5;
g.color.personAnchored = pantone.DuskBlue;
g.color.personNoAnchor = pantone.Hazelnut;
g.color.personReplication = pantone.DuskBlue;

g.color.modelOriginal = pantone.Treetop;
g.color.modelReplication = pantone.Treetop;
g.color.anchorCrowd = pantone.LapisBlue;
g.color.fullCrowd = [0 0 0];
g.color.noAnchorCrowd = pantone.Hazelnut;
g.ci.originalAlpha = 0.22;
g.ci.replicationAlpha = 0.22;

g.lineWidth = 4;
g.line.modelMult = 1.08;
g.line.anchorMult = 0.96;
g.line.fullMult = 0.86;
g.line.noAnchorMult = 0.76;
g.label.model = ' debiasing';
g.label.anchor = ' anchor crowd';
g.label.full = ' full crowd';
g.label.noAnchor = ' no-anchor crowd';
g.label.xOffset = 0;
g.label.vert = 'bottom';
g.label.hor = 'left';

g.font.axis = 15;
g.font.xlabel = 17;
g.font.crowdLabel = 14;
g.font.panelLetter = 20;
g.font.inset = 12;
g.font.insetLabel = 12;
g.font.insetCorr = 12;

% Insets relative to each panel; height is set for square on-screen pixels.
g.insetExpertise.bottomLeft = [0.74 0.48];
g.insetAnchoring.bottomLeft = [0.50 0.48];
g.insetWidth = 0.18; % 10% smaller than 0.20; square pixels keep circular markers
g.insetHeight = 0.36; % nominal; inset_pos_square_pixels overrides height
g.insetTickLength = [0.025 0];
g.insetMarkerSize = 5.5;
g.insetMarkerEdge = 'k';
g.insetRaxes.x = 0.01;
g.insetRaxes.y = 0.01;
g.insetCorr.xFrac = 0.02;
g.insetCorr.yFrac = 0; % r= top aligned with max y tick
g.insetExpertise.xlim = [0 75];
g.insetExpertise.ylim = [0 75];
g.insetExpertise.xlabel = 'inferred expertise';
g.insetExpertise.ylabel = 'observed error';
g.insetAnchoring.xlim = [-1 1];
g.insetAnchoring.xtick = [-1 0 1];
g.insetAnchoring.ylim = [-1 1];
g.insetAnchoring.ytick = [-1 0 1];
g.insetAnchoring.xlabel = 'inferred anchoring';
g.insetAnchoring.ylabel = 'observed anchoring';
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
