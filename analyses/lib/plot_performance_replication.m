function plot_performance_replication(repoRoot, storageDirs, printFigures, fineTune)
%PLOT_PERFORMANCE_REPLICATION Combined original + replication WOC figure.
% Single RMSE histogram: original people keep anchored/no-anchor colors;
% replication people use a light version of the anchored color. Aggregate
% lines for both datasets (model + CI, full, and original anchor /
% no-anchor). 2x2 insets: expertise and anchoring for each dataset.
%
% Graphics: defaults in default_performance_replication_graphics; override
% via fineTune.performanceReplication (see analyses.m).

if nargin < 3 || isempty(printFigures), printFigures = true; end
if nargin < 4 || isempty(fineTune), fineTune = default_fine_tune(); end

dataDir = fullfile(repoRoot, 'data');
load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
dOrig = d;
load(fullfile(dataDir, 'anchorYearsF2026.mat'), 'd');
dRep = d;
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');

g = default_performance_replication_graphics(pantone);
if isfield(fineTune, 'performanceReplication')
    g = merge_struct_local(g, fineTune.performanceReplication);
end
if isfield(fineTune, 'font') && isfield(fineTune.font, 'performance') ...
        && ~isempty(fineTune.font.performance)
    g.font.axis = fineTune.font.performance;
    g.font.xlabel = fineTune.font.performance + 2;
    g.font.crowdLabel = fineTune.font.performance;
    g.font.inset = fineTune.font.performance;
    g.font.legend = fineTune.font.performance - 2;
end

Sorig = compute_woc_stats(dOrig, storageDirs, { ...
    'debiasing_anchorYears_jags.mat'
    'anchorYears_7b2_anchorYears_jags.mat'
    }, 'original');
Srep = compute_woc_stats(dRep, storageDirs, { ...
    'debiasing_anchorYearsF2026_jags.mat'
    'debiasing_anchorYearsF2026AnchoredOnly_jags.mat'
    }, 'replication');

xMax = max([max(Sorig.e), max(Srep.e), ...
    Sorig.omegaCrowd, Sorig.omegaHLCrowd, Sorig.omegaNCrowd, Sorig.omegaAModel, ...
    Srep.omegaCrowd, Srep.omegaAModel]) + g.xlimPad;
xMax = max(xMax, g.xlimMin);
if ~isempty(g.xlim) && numel(g.xlim) == 2
    xMax = g.xlim(2);
    xLim = g.xlim;
else
    xLim = [0 xMax];
end
if ~isempty(g.xtick)
    xTick = g.xtick;
else
    xTick = unique(0:g.xtickStep:round(xMax, -1));
end

F = figure; clf;
try
    set_figure_safe(F, g.figure.position, '');
catch
    set(F, 'units', 'normalized', 'position', g.figure.position, 'color', 'w');
end
set(F, 'Units', 'pixels', 'Position', g.figure.pixelPosition, 'PaperPositionMode', 'auto');
try, set(F, 'renderer', 'opengl'); catch, end

draw_combined_woc(F, Sorig, Srep, g, xLim, xTick);

outDir = results_dir(repoRoot, 'performance');
print_figure(outDir, 'allQPerformanceComparison_originalVsReplication', printFigures);
write_performance_report(outDir, Sorig, Srep);
end


function S = compute_woc_stats(d, storageDirs, jagsCandidates, tag)
S.tag = tag;
S.e = d.participantRMSE(:);
S.hasNoAnchor = size(d.estimate, 2) >= 3 && any(d.groupLong(:) == 3);
crowdEst = zeros(d.nQuestions, 1);
crowdHLEst = zeros(d.nQuestions, 1);
crowdNEst = nan(d.nQuestions, 1);
for qIdx = 1:d.nQuestions
    y = d.estimateLong(d.questionLong == qIdx);
    crowdEst(qIdx) = mean(y);
    crowdHLEst(qIdx) = mean([d.estimate{qIdx, 1}(:); d.estimate{qIdx, 2}(:)]);
    if S.hasNoAnchor
        crowdNEst(qIdx) = mean(d.estimate{qIdx, 3}(:));
    end
end
S.omegaCrowd = sqrt(mean((crowdEst(:) - d.truth(:)) .^ 2));
S.omegaHLCrowd = sqrt(mean((crowdHLEst(:) - d.truth(:)) .^ 2));
if S.hasNoAnchor
    S.omegaNCrowd = sqrt(mean((crowdNEst(:) - d.truth(:)) .^ 2));
else
    S.omegaNCrowd = NaN;
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
    S.eExpertise = S.e;
    S.groupExpertise = d.participantGroup(:);
elseif nSigma == numel(keepAnchored)
    S.sigmaPlot = S.sigmaA(:);
    S.eExpertise = S.e(keepAnchored);
    S.groupExpertise = d.participantGroup(keepAnchored);
else
    error('%s: sigma length %d incompatible with nPart %d / nAnchored %d', ...
        tag, nSigma, d.nParticipants, numel(keepAnchored));
end
S.participantGroup = d.participantGroup(:);

fprintf('%s RMSE: full=%.2f', tag, S.omegaCrowd);
if S.hasNoAnchor
    fprintf('  HL=%.2f  no-anchor=%.2f', S.omegaHLCrowd, S.omegaNCrowd);
else
    fprintf('  HL=%.2f', S.omegaHLCrowd);
end
fprintf('  debiasing=%.2f', S.omegaAModel);
if ~isempty(S.omegaAModelCI)
    fprintf(' [%.2f, %.2f]', S.omegaAModelCI(1), S.omegaAModelCI(2));
end
fprintf('\n');
end


function draw_combined_woc(F, Sorig, Srep, g, xLim, xTick)
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

% Person tiles: original anchored / original no-anchor / replication
people = [ ...
    struct('e', Sorig.e, 'group', Sorig.participantGroup, 'kind', 'original')
    struct('e', Srep.e, 'group', Srep.participantGroup, 'kind', 'replication')
    ];
eAll = [Sorig.e(:); Srep.e(:)];
binEdges = -0.5:ceil(max(eAll)) + 0.5;
nBins = numel(binEdges) - 1;
stack = zeros(nBins, 1);

for p = 1:numel(people)
    e = people(p).e(:);
    grp = people(p).group(:);
    [~, ~, binIdx] = histcounts(e, binEdges);
    for i = 1:numel(e)
        b = binIdx(i);
        if b < 1 || b > nBins
            continue;
        end
        xPos = binEdges(b) + 0.5;  % integer RMSE center
        if xPos < xLim(1) || xPos > xLim(2)
            continue;
        end
        stack(b) = stack(b) + height;
        face = person_face(people(p).kind, grp(i), g);
        rectangle(ax, 'position', ...
            [xPos - width / 2, stack(b) - height / 2 - 0.5, width, height], ...
            'facecolor', face, 'edgecolor', g.person.edgeColor, ...
            'curvature', g.person.curvature, 'clipping', 'off', ...
            'linewidth', g.person.edgeWidth);
    end
end

yLim = get(ax, 'ylim');
yLim(1) = g.ylim(1);
yLim(2) = max(max(stack) * g.yLimPad, g.yLimMin);
if ~isempty(g.ylim) && numel(g.ylim) == 2 && isfinite(g.ylim(2))
    yLim(2) = g.ylim(2);
end
set(ax, 'ylim', yLim);

% CI patches under lines (models)
draw_ci_band(ax, Sorig.omegaAModelCI, yLim, g.color.modelOriginal, g.ci.originalAlpha);
draw_ci_band(ax, Srep.omegaAModelCI, yLim, g.color.modelReplication, g.ci.replicationAlpha);

% Aggregate reference lines (order = bottom→top of label stack intent)
refs = {
    Sorig.omegaAModel, g.color.modelOriginal,      g.label.modelOriginal,      g.line.modelOriginalMult
    Srep.omegaAModel,  g.color.modelReplication,   g.label.modelReplication,   g.line.modelReplicationMult
    Sorig.omegaHLCrowd, g.color.anchorOriginal,    g.label.anchorOriginal,     g.line.anchorOriginalMult
    Sorig.omegaCrowd,  g.color.fullOriginal,       g.label.fullOriginal,       g.line.fullOriginalMult
    Srep.omegaCrowd,   g.color.fullReplication,    g.label.fullReplication,    g.line.fullReplicationMult
    Sorig.omegaNCrowd, g.color.noAnchorOriginal,   g.label.noAnchorOriginal,   g.line.noAnchorOriginalMult
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
        'vert', g.label.vert, 'hor', g.label.hor, ...
        'rotation', g.label.rotation);
end

draw_person_legend(F, g);
draw_inset_grid(F, Sorig, Srep, g);
end


function face = person_face(kind, group, g)
if strcmp(kind, 'replication')
    face = g.color.personReplication;
elseif group == 3
    face = g.color.personNoAnchor;
else
    face = g.color.personAnchored;
end
end


function draw_ci_band(ax, ci, yLim, col, faceAlpha)
if isempty(ci) || ~all(isfinite(ci))
    return;
end
Hci = patch(ax, ...
    [ci(1) ci(2) ci(2) ci(1)], ...
    [yLim(1) yLim(1) yLim(2) yLim(2)], col, ...
    'EdgeColor', 'none', 'FaceAlpha', faceAlpha);
uistack(Hci, 'bottom');
end


function draw_person_legend(F, g)
if ~g.legend.show
    return;
end
ax = axes('Parent', F, 'Units', 'normalized', 'Position', g.legend.position, ...
    'Visible', 'off');
hold(ax, 'on');
entries = {
    g.color.personAnchored,    g.legend.anchored
    g.color.personNoAnchor,    g.legend.noAnchor
    g.color.personReplication, g.legend.replication
    };
for i = 1:size(entries, 1)
    y = size(entries, 1) - i + 1;
    rectangle(ax, 'position', [0, y - 0.35, 0.55, 0.7], ...
        'facecolor', entries{i, 1}, 'edgecolor', g.person.edgeColor, ...
        'curvature', g.person.curvature, 'linewidth', g.person.edgeWidth);
    text(ax, 0.75, y, entries{i, 2}, 'fontsize', g.font.legend, ...
        'vert', 'middle', 'hor', 'left', 'color', g.legend.textColor);
end
set(ax, 'xlim', [0 4], 'ylim', [0.3 size(entries, 1) + 0.7], 'Visible', 'off');
end


function draw_inset_grid(F, Sorig, Srep, g)
% 2x2:  [orig expertise] [orig anchoring]
%       [rep expertise]  [rep anchoring]
% showTitle: dataset title only on left column (expertise)
cells = {
    g.inset.origExpertise, Sorig, 'expertise', 'original',    true
    g.inset.origAnchoring, Sorig, 'anchoring', 'original',    false
    g.inset.repExpertise,  Srep,  'expertise', 'replication', true
    g.inset.repAnchoring,  Srep,  'anchoring', 'replication', false
    };
for i = 1:size(cells, 1)
    pos = cells{i, 1};
    S = cells{i, 2};
    kind = cells{i, 3};
    dataset = cells{i, 4};
    showTitle = cells{i, 5} && g.inset.showDatasetTitle;
    if strcmp(kind, 'expertise')
        draw_expertise_inset(F, pos, S, g, dataset, showTitle);
    else
        draw_anchoring_inset(F, pos, S, g, dataset, showTitle);
    end
end
end


function draw_expertise_inset(F, pos, S, g, dataset, showTitle)
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
xHi = max(g.insetExpertise.xlim(2), ceil(max(S.sigmaPlot)));
yHi = max(g.insetExpertise.ylim(2), ceil(max(S.eExpertise)));
set(A, 'xlim', [0 xHi], 'xtick', [0 xHi], 'xticklabel', {'hi', 'lo'}, ...
    'xticklabelrot', 0, 'ylim', [0 yHi], 'ytick', [0 yHi], ...
    'yticklabel', {'lo', 'hi'}, 'box', 'off', 'tickdir', 'out', ...
    'ticklength', g.insetTickLength, 'clipping', 'off', 'fontsize', g.font.inset);
axis(A, 'square');
xlabel(A, g.insetExpertise.xlabel, 'fontsize', g.font.insetLabel);
ylabel(A, g.insetExpertise.ylabel, 'fontsize', g.font.insetLabel);
if showTitle
    if strcmp(dataset, 'original')
        title(A, g.inset.titleOriginal, 'fontsize', g.font.insetTitle, 'fontweight', 'normal');
    else
        title(A, g.inset.titleReplication, 'fontsize', g.font.insetTitle, 'fontweight', 'normal');
    end
end

shuffle = randperm(numel(S.eExpertise));
for idx2 = 1:numel(S.eExpertise)
    idx = shuffle(idx2);
    face = person_face(dataset, S.groupExpertise(idx), g);
    plot(A, S.sigmaPlot(idx), S.eExpertise(idx), 'o', ...
        'markerfacecolor', face, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge);
end
try, Raxes(A, g.insetRaxes.x, g.insetRaxes.y); catch, end
set(A, 'clipping', 'off');
rS = corrcoef(S.sigmaPlot(:), S.eExpertise(:), 'Rows', 'complete');
xl = xlim(A); yl = ylim(A);
text(A, xl(1) + g.insetCorr.xFrac * diff(xl), ...
    yl(2) - g.insetCorr.yFrac * diff(yl), ...
    sprintf('r=%.2f', rS(1, 2)), ...
    'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');
end


function draw_anchoring_inset(F, pos, S, g, dataset, showTitle)
A = axes('Parent', F, 'Units', 'normalized', 'Position', pos);
hold(A, 'on');
set(A, 'xlim', g.insetAnchoring.xlim, 'xtick', g.insetAnchoring.xtick, ...
    'xticklabelrot', 0, 'ylim', g.insetAnchoring.ylim, 'ytick', g.insetAnchoring.ytick, ...
    'box', 'off', 'tickdir', 'out', 'ticklength', g.insetTickLength, ...
    'clipping', 'off', 'fontsize', g.font.inset);
axis(A, 'square');
xlabel(A, g.insetAnchoring.xlabel, 'fontsize', g.font.insetLabel);
ylabel(A, g.insetAnchoring.ylabel, 'fontsize', g.font.insetLabel);
if showTitle
    if strcmp(dataset, 'original')
        title(A, g.inset.titleOriginal, 'fontsize', g.font.insetTitle, 'fontweight', 'normal');
    else
        title(A, g.inset.titleReplication, 'fontsize', g.font.insetTitle, 'fontweight', 'normal');
    end
end

face = g.color.personAnchored;
if strcmp(dataset, 'replication')
    face = g.color.personReplication;
end
shuffle = randperm(numel(S.keepAnchored));
for idx2 = 1:numel(S.keepAnchored)
    idx = shuffle(idx2);
    plot(A, S.alphaPlot(idx), S.empiricalA(idx), 'o', ...
        'markerfacecolor', face, 'markersize', g.insetMarkerSize, ...
        'markeredgecolor', g.insetMarkerEdge);
end
try, Raxes(A, g.insetRaxes.x, g.insetRaxes.y); catch, end
set(A, 'clipping', 'off');
rA = corrcoef(S.alphaPlot(:), S.empiricalA(:), 'Rows', 'complete');
xl = xlim(A); yl = ylim(A);
text(A, xl(1) + g.insetCorr.xFrac * diff(xl), ...
    yl(2) - g.insetCorr.yFrac * diff(yl), ...
    sprintf('r=%.2f', rA(1, 2)), ...
    'fontsize', g.font.insetCorr, 'hor', 'left', 'vert', 'top');
end


function write_performance_report(outDir, Sorig, Srep)
outTxt = fullfile(outDir, 'originalVsReplication.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    warning('Could not write %s', outTxt);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'original vs replication: WOC / debiasing RMSE\n');
fprintf(fid, 'replication has no no-anchor arm (anchored forms only).\n\n');
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
if isfinite(S.omegaNCrowd)
    fprintf(fid, '%-14s %10.2f %10.2f %12.2f %10.2f%s\n', ...
        S.tag, S.omegaCrowd, S.omegaHLCrowd, S.omegaNCrowd, S.omegaAModel, ci);
else
    fprintf(fid, '%-14s %10.2f %10.2f %12s %10.2f%s\n', ...
        S.tag, S.omegaCrowd, S.omegaHLCrowd, '—', S.omegaAModel, ci);
end
end


function g = default_performance_replication_graphics(pantone)
%DEFAULT_PERFORMANCE_REPLICATION_GRAPHICS All tunable knobs for the combined figure.
% Override any field via fineTune.performanceReplication in analyses.m.

% ---- figure / layout ----
g.figure.position = [0.06 0.04 0.70 0.90];       % normalized screen position
g.figure.pixelPosition = [40 40 1400 900];        % pixel size for print
g.mainAxis.position = [0.07 0.12 0.58 0.78];      % [left bottom width height]
g.xlabel = 'Root Mean Squared Error';
g.tickLength = [0.01 0];
g.raxes.x = 0.01;                                 % Raxes x trim
g.raxes.y = 0.01;
g.rngSeed = 1;

% ---- axis limits ----
g.xlim = [];                                      % [] → auto [0, xMax]; or [lo hi]
g.xlimMin = 40;
g.xlimPad = 1;
g.xtick = [];                                     % [] → auto 0:xtickStep:...
g.xtickStep = 10;
g.ylim = [0 NaN];                                 % NaN hi → auto from stack
g.yLimPad = 1.45;
g.yLimMin = 8;

% ---- person tiles ----
g.person.width = 1;
g.person.height = 1;
g.person.curvature = [0.2 0.2];
g.person.edgeColor = 0.2 * ones(1, 3);
g.person.edgeWidth = 0.5;
g.color.personAnchored = pantone.DuskBlue;        % original anchored
g.color.personNoAnchor = pantone.Hazelnut;        % original no-anchor
g.color.personReplication = lighten_color(pantone.DuskBlue, 0.45);  % light anchored

% ---- aggregate line colors ----
g.color.modelOriginal = pantone.Sandstone;
g.color.modelReplication = pantone.ClassicBlue;
g.color.fullOriginal = [0 0 0];
g.color.fullReplication = pantone.StormyWeather;
g.color.anchorOriginal = pantone.LapisBlue;
g.color.noAnchorOriginal = pantone.Hazelnut;

% ---- CI shading ----
g.ci.originalAlpha = 0.22;
g.ci.replicationAlpha = 0.18;

% ---- lines / labels ----
g.lineWidth = 3.5;
g.line.modelOriginalMult = 1.10;
g.line.modelReplicationMult = 1.02;
g.line.anchorOriginalMult = 0.94;
g.line.fullOriginalMult = 0.86;
g.line.fullReplicationMult = 0.78;
g.line.noAnchorOriginalMult = 0.70;
g.label.modelOriginal = ' orig. debiasing';
g.label.modelReplication = ' rep. debiasing';
g.label.anchorOriginal = ' orig. anchor';
g.label.fullOriginal = ' orig. full';
g.label.fullReplication = ' rep. full';
g.label.noAnchorOriginal = ' orig. no-anchor';
g.label.xOffset = 0;
g.label.vert = 'bottom';
g.label.hor = 'left';
g.label.rotation = 0;

% ---- fonts ----
g.font.axis = 14;
g.font.xlabel = 16;
g.font.crowdLabel = 12;
g.font.legend = 12;
g.font.inset = 11;
g.font.insetLabel = 11;
g.font.insetTitle = 12;
g.font.insetCorr = 11;

% ---- person legend ----
g.legend.show = true;
g.legend.position = [0.07 0.88 0.22 0.10];        % figure-normalized
g.legend.anchored = 'original anchored';
g.legend.noAnchor = 'original no-anchor';
g.legend.replication = 'replication';
g.legend.textColor = 0.15 * ones(1, 3);

% ---- 2x2 inset grid (figure-normalized positions) ----
% Layout:  [orig expertise] [orig anchoring]
%          [rep expertise]  [rep anchoring]
insetW = 0.155;
insetH = 0.195;
insetX0 = 0.68;
insetY0 = 0.12;
insetGapX = 0.015;
insetGapY = 0.055;
g.inset.origExpertise = [insetX0, insetY0 + insetH + insetGapY, insetW, insetH];
g.inset.origAnchoring = [insetX0 + insetW + insetGapX, insetY0 + insetH + insetGapY, insetW, insetH];
g.inset.repExpertise  = [insetX0, insetY0, insetW, insetH];
g.inset.repAnchoring  = [insetX0 + insetW + insetGapX, insetY0, insetW, insetH];
g.inset.titleOriginal = 'original';
g.inset.titleReplication = 'replication';
g.inset.showDatasetTitle = true;   % titles on left column only
g.insetWidth = insetW;   % kept for merge compatibility
g.insetHeight = insetH;
g.insetTickLength = [0.025 0];
g.insetMarkerSize = 5;
g.insetMarkerEdge = 'k';
g.insetRaxes.x = 0.01;
g.insetRaxes.y = 0.01;
g.insetCorr.xFrac = 0.02;
g.insetCorr.yFrac = 0.02;

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


function c = lighten_color(c, amount)
%LIGHTEN_COLOR Blend RGB toward white. amount in [0,1] (0=unchanged, 1=white).
c = c(:).';
if numel(c) ~= 3
    error('lighten_color expects a 1x3 RGB vector');
end
amount = max(0, min(1, amount));
c = (1 - amount) * c + amount * [1 1 1];
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
