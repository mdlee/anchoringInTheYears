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
% Optional global performance font fills unspecified fields only (does not
% override panel-letter size or anything set under performanceOriginalReplication).
if isfield(fineTune, 'font') && isfield(fineTune.font, 'performance') ...
        && ~isempty(fineTune.font.performance)
    f0 = fineTune.font.performance;
    g.font = fill_missing_font(g.font, struct( ...
        'axis', f0, ...
        'xlabel', f0 + 2, ...
        'crowdLabel', f0, ...
        'inset', max(f0 - 2, 8), ...
        'insetLabel', max(f0 - 2, 8), ...
        'insetCorr', max(f0 - 2, 8)));
end
if isfield(fineTune, 'performanceOriginalReplication')
    g = merge_struct_local(g, fineTune.performanceOriginalReplication);
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
dual = '';
if isfield(g.figure, 'dual') && ~isempty(g.figure.dual)
    dual = g.figure.dual;
end
try
    set_figure_safe(F, g.figure.position, dual);
catch
    set(F, 'units', 'normalized', 'position', g.figure.position, 'color', 'w');
end
% Aspect for square insets from the actual on-screen window size.
g.figure.aspectRatio = figure_aspect_ratio(F, g);
% Painters keeps marker glyphs circular under export (OpenGL can squash them).
try, set(F, 'Renderer', 'painters'); catch, end

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

draw_panel_letter(F, g.panelLetter.A, g);
draw_panel_letter(F, g.panelLetter.B, g);

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
pos = inset_position(g, g.insetExpertise, panel);
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
% Equal data aspect + square Position (via inset.forceSquare) → circular markers.
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
pos = inset_position(g, g.insetAnchoring, panel);
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


function draw_panel_letter(F, letter, g)
% letter.position = [x y w h] in figure-normalized units; letter.fontSize
% overrides g.font.panelLetter when set.
pos = letter.position(:).';
if numel(pos) == 2
    pos = [pos(:).' 0.28 0.04];
end
fs = g.font.panelLetter;
if isfield(letter, 'fontSize') && ~isempty(letter.fontSize)
    fs = letter.fontSize;
end
fw = 'normal';
if isfield(letter, 'fontWeight') && ~isempty(letter.fontWeight)
    fw = letter.fontWeight;
end
annotation(F, 'textbox', pos, ...
    'String', letter.str, 'FontSize', fs, 'FontWeight', fw, ...
    'EdgeColor', 'none', 'VerticalAlignment', 'bottom', ...
    'HorizontalAlignment', 'left', 'Interpreter', 'none');
end


function pos = map_to_panel(rel, panel)
% Map panel-relative normalized [l b w h] into figure-normalized coords.
rel = rel(:).';
panel = panel(:).';
pos = [panel(1) + panel(3) * rel(1), ...
    panel(2) + panel(4) * rel(2), ...
    panel(3) * rel(3), ...
    panel(4) * rel(4)];
end


function pos = inset_position(g, inset, panel)
% Inset placement is fully normalized (no pixel coordinates).
% Prefer inset.position = [l b w h] relative to the panel.
% Else use inset.bottomLeft + g.insetWidth / g.insetHeight.
% If g.inset.forceSquare is true, height is derived from width using
% g.figure.aspectRatio (width/height) so the axes box is square on screen.
panel = panel(:).';
if isfield(inset, 'position') && ~isempty(inset.position) && numel(inset.position) == 4
    rel = inset.position(:).';
else
    bl = inset.bottomLeft(:).';
    wRel = g.insetWidth;
    hRel = g.insetHeight;
    rel = [bl(1) bl(2) wRel hRel];
end
forceSquare = isfield(g, 'inset') && isfield(g.inset, 'forceSquare') && g.inset.forceSquare;
if forceSquare
    aspect = 1;
    if isfield(g.figure, 'aspectRatio') && ~isempty(g.figure.aspectRatio)
        aspect = g.figure.aspectRatio; % figure width / height
    end
    % Square in figure-normalized units ⇒ Δx_fig / Δy_fig = aspect.
    % Δx_fig = panel(3)*wRel, Δy_fig = panel(4)*hRel.
    wRel = rel(3);
    hRel = (panel(3) * wRel) / max(panel(4) * aspect, eps);
    rel(3) = wRel;
    rel(4) = hRel;
end
pos = map_to_panel(rel, panel);
end


function font = fill_missing_font(font, defaults)
fn = fieldnames(defaults);
for i = 1:numel(fn)
    name = fn{i};
    if ~isfield(font, name) || isempty(font.(name))
        font.(name) = defaults.(name);
    end
end
end


function aspect = figure_aspect_ratio(F, g)
% Prefer an explicit override; else read the live pixel W/H.
if isfield(g.figure, 'aspectRatio') && ~isempty(g.figure.aspectRatio)
    aspect = g.figure.aspectRatio;
    return;
end
aspect = 1;
try
    units = get(F, 'Units');
    set(F, 'Units', 'pixels');
    pos = get(F, 'Position');
    set(F, 'Units', units);
    aspect = pos(3) / max(pos(4), eps);
catch
end
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
% Figure window and panel/axis/inset layout are all normalized.
% set_figure_safe maps figure.position onto dual monitors (auto-detect).
% Override via fineTune.performanceOriginalReplication in analyses.m.

% Figure: normalized [l b w h]; dual '' = auto ('leave'|'single'|'upDown'|'leftRight').
g.figure.position = [0.05 0.02 0.684 0.836];
g.figure.dual = '';
g.figure.aspectRatio = []; % filled from on-screen size after set_figure_safe



% Panel regions in figure-normalized coordinates [left bottom width height].
g.panel.A = [0.01 0.51 0.98 0.47];
g.panel.B = [0.01 0.02 0.98 0.47];

% A/B labels: figure-normalized textbox + dedicated fontSize.
g.panelLetter.A.position = [0.01 0.955 0.28 0.04];
g.panelLetter.B.position = [0.01 0.465 0.28 0.04];
g.panelLetter.A.str = 'A  Original';
g.panelLetter.B.str = 'B  Replication';
g.panelLetter.A.fontSize = 20;
g.panelLetter.B.fontSize = 20;
g.panelLetter.A.fontWeight = 'normal';
g.panelLetter.B.fontWeight = 'normal';

% Main histogram axes relative to each panel [l b w h].
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
g.font.panelLetter = 20; % fallback if panelLetter.*.fontSize unset
g.font.inset = 12;
g.font.insetLabel = 12;
g.font.insetCorr = 12;

% Insets: panel-relative normalized position [l b w h], or bottomLeft+width/height.
g.inset.forceSquare = true; % use figure.aspectRatio so markers stay circular
g.insetExpertise.position = [0.74 0.48 0.18 0.36];
g.insetAnchoring.position = [0.50 0.48 0.18 0.36];
g.insetExpertise.bottomLeft = [0.74 0.48]; % used only if .position empty
g.insetAnchoring.bottomLeft = [0.50 0.48];
g.insetWidth = 0.18;
g.insetHeight = 0.36;
g.insetTickLength = [0.025 0];
g.insetMarkerSize = 5.5;
g.insetMarkerEdge = 'k';
g.insetRaxes.x = 0.01;
g.insetRaxes.y = 0.01;
g.insetCorr.xFrac = 0.02;
g.insetCorr.yFrac = 0;
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
