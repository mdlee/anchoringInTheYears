function plot_all_q_anchoring_replication(repoRoot, storageDirs, printFigures, fineTune)
%PLOT_ALL_Q_ANCHORING_REPLICATION Forest of anchoring indices: original vs replication.
% Same 11 event-year questions. The replication (COGS140J F2026) used percentile
% anchors from the original no-anchor group (see prepare_anchor_years_f2026.m).
% For each question, the original mean/CI/BF is drawn slightly above the row
% center and the replication slightly below, in different colors (BF text matches).

if nargin < 3 || isempty(printFigures), printFigures = true; end
if nargin < 4 || isempty(fineTune), fineTune = default_fine_tune(); end

dataDir = fullfile(repoRoot, 'data');
load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
dOrig = d;
load(fullfile(dataDir, 'anchorYearsF2026.mat'), 'd');
dRep = d;
load(fullfile(dataDir, 'pantoneColors.mat'), 'pantone');

g = default_replication_graphics(pantone);
if isfield(fineTune, 'allQanchoringReplication')
    g = merge_struct_local(g, fineTune.allQanchoringReplication);
end
if isfield(fineTune, 'font') && isfield(fineTune.font, 'allQanchoringReplication') ...
        && ~isempty(fineTune.font.allQanchoringReplication)
    g.font.axis = fineTune.font.allQanchoringReplication;
end

nQ = dOrig.nQuestions;
if dRep.nQuestions ~= nQ
    error('original and replication question counts differ (%d vs %d)', nQ, dRep.nQuestions);
end
for q = 1:nQ
    if ~strcmp(dOrig.questionLabels{q}, dRep.questionLabels{q})
        error('Question label mismatch at %d: "%s" vs "%s"', ...
            q, dOrig.questionLabels{q}, dRep.questionLabels{q});
    end
end

[~, srtIdx] = sort(dOrig.truth(:));
statsOrig = summarize_anchoring(storageDirs, dOrig, 'original');
statsRep = summarize_anchoring(storageDirs, dRep, 'anchorYearsF2026');

F = figure; clf; hold on;
try
    set_figure_safe(F, g.figure.position, '');
catch
    set(F, 'units', 'normalized', 'position', g.figure.position, 'color', 'w');
end
set(F, 'Units', 'pixels', 'Position', g.figure.pixelPosition, 'PaperPositionMode', 'auto');
set(gca, ...
    'ytick', 1:nQ, ...
    'ylim', [0.5 nQ + 0.5], ...
    'yticklabel', dOrig.questionLabels(srtIdx), ...
    'ydir', 'rev', ...
    'xlim', g.xlim, ...
    'xtick', g.xtick, ...
    'xticklabelrot', 0, ...
    'box', 'off', ...
    'tickdir', 'out', ...
    'ticklength', g.tickLength, ...
    'clipping', 'off', ...
    'fontsize', g.font.axis);
try, moveAxis(gca, g.moveAxis, g.moveAxisShift); catch, end
xlabel('Anchoring Index', 'fontsize', g.font.axis + 2);
try, Raxes(gca, 0.025, 0.01); catch, end
% Axis ends at 1; BF labels sit just past the right edge with clipping off.
set(gca, 'xlim', g.xlim, 'xtick', g.xtick, 'clipping', 'off');

dy = g.rowOffset;
Hleg = gobjects(1, 2);
for row = 1:nQ
    qi = srtIdx(row);
    yOrig = row - dy;
    yRep = row + dy;

    Hleg(1) = plot_row(statsOrig, qi, yOrig, g.color.original, g);
    Hleg(2) = plot_row(statsRep, qi, yRep, g.color.replication, g);

    text(g.bfX, yOrig, bf_string(statsOrig.BF(qi)), ...
        'vert', 'mid', 'fontsize', g.font.bf, 'color', g.color.original, ...
        'Clipping', 'off');
    text(g.bfX, yRep, bf_string(statsRep.BF(qi)), ...
        'vert', 'mid', 'fontsize', g.font.bf, 'color', g.color.replication, ...
        'Clipping', 'off');
end

L = legend(Hleg, g.legend, 'box', 'off', 'fontsize', g.font.legend, ...
    'location', g.legendLocation);
try, set(L, 'AutoUpdate', 'off'); catch, end
if ~isempty(g.legendPosition) && numel(g.legendPosition) == 4
    set(L, 'Units', 'normalized', 'Position', g.legendPosition);
elseif numel(g.legendShift) == 4
    set(L, 'pos', get(L, 'pos') + g.legendShift);
end

outDir = results_dir(repoRoot, 'anchoringIndex');
print_figure(outDir, 'allQanchoring_originalVsF2026', printFigures);
write_replication_report(outDir, dOrig, srtIdx, statsOrig, statsRep);
end


function H = plot_row(stats, qi, y, col, g)
ci = [max(g.xlim(1), stats.bounds(qi, 1)), min(1, stats.bounds(qi, 2))];
plot(ci, [y y], '-', 'color', col, 'LineWidth', g.lineWidthCI);
H = plot(stats.mn(qi), y, 'o', ...
    'markerfacecolor', col, ...
    'markeredgecolor', 'w', ...
    'markersize', g.markerSize, ...
    'linewidth', 1);
end


function str = bf_string(bf)
if bf > 1000
    str = 'BF_{10} > 1000';
elseif bf > 1
    str = sprintf('BF_{10} = %1.1f', bf);
else
    str = sprintf('BF_{01} = %1.1f', 1 / bf);
end
end


function stats = summarize_anchoring(storageDirs, d, whichSet)
CI = 95;
critical = 0;
nQ = d.nQuestions;
stats.mn = nan(nQ, 1);
stats.bounds = nan(nQ, 2);
stats.BF = nan(nQ, 1);

binLo = 0;
binHi = 1;
binWidth = 0.01;
binCenter = binLo:binWidth:binHi;
[~, criticalIdx] = min(abs(binCenter - critical));

for qIdx = 1:nQ
    if strcmp(whichSet, 'anchorYearsF2026')
        [chains, priorField, postField] = load_tagged_chains(storageDirs, whichSet, qIdx);
    else
        [chains, priorField, postField] = load_anchoring_chains(storageDirs, d.questionLabels{qIdx});
        if isempty(chains)
            [chains, priorField, postField] = load_anchoring_chains(storageDirs, qIdx);
        end
        if isempty(chains)
            error('Missing original anchoring-index MCMC for Q%d (%s)', ...
                qIdx, d.questionLabels{qIdx});
        end
    end
    densityPrior = histcounts(chains.(priorField)(:), ...
        'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
        'binwidth', binWidth, 'normalization', 'pdf');
    densityPosterior = histcounts(chains.(postField)(:), ...
        'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
        'binwidth', binWidth, 'normalization', 'pdf');
    stats.BF(qIdx) = exp(log(densityPrior(criticalIdx)) - log(densityPosterior(criticalIdx)));
    stats.bounds(qIdx, :) = prctile(chains.(postField)(:), [(100 - CI) / 2, CI + (100 - CI) / 2]);
    stats.mn(qIdx) = mean(chains.(postField)(:));
end
end


function [chains, priorField, postField] = load_tagged_chains(storageDirs, chainTag, qIdx)
path = resolve_storage_file(storageDirs, sprintf('anchoringIndex_%s_%d_jags.mat', chainTag, qIdx));
if isempty(path)
    error('Missing anchoring-index MCMC for %s Q%d', chainTag, qIdx);
end
S = load(path, 'chains');
chains = S.chains;
if isfield(chains, 'A') && isfield(chains, 'Aprior')
    postField = 'A';
    priorField = 'Aprior';
elseif isfield(chains, 'alpha') && isfield(chains, 'alphaPrior')
    postField = 'alpha';
    priorField = 'alphaPrior';
else
    error('Unrecognized chain fields in %s', path);
end
end


function write_replication_report(outDir, d, srtIdx, statsOrig, statsRep)
outTxt = fullfile(outDir, 'originalVsF2026.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    warning('Could not write %s', outTxt);
    return;
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'original vs replication event-years: anchoring-index means, CIs, and BFs\n');
fprintf(fid, 'BF10 is the Savage-Dickey factor against anchoring index = 0.\n');
fprintf(fid, 'Questions ordered by ascending truth (same order as the figure).\n\n');
fprintf(fid, '%-18s  %-28s  %s\n', 'Question', 'original', 'replication');
for row = 1:d.nQuestions
    qi = srtIdx(row);
    fprintf(fid, '%-18s  %s  %s\n', d.questionLabels{qi}, ...
        format_stats(statsOrig, qi), format_stats(statsRep, qi));
end
fprintf('Wrote %s\n', outTxt);
end


function s = format_stats(stats, qi)
if stats.BF(qi) > 1000
    bfStr = 'BF10 > 1000';
elseif stats.BF(qi) > 1
    bfStr = sprintf('BF10 = %.1f', stats.BF(qi));
else
    bfStr = sprintf('BF01 = %.1f', 1 / stats.BF(qi));
end
s = sprintf('mean %.2f [%.2f, %.2f] %s', ...
    stats.mn(qi), stats.bounds(qi, 1), stats.bounds(qi, 2), bfStr);
end


function g = default_replication_graphics(pantone)
g.figure.position = [0.05 0.02 0.72 0.96];
g.figure.pixelPosition = [40 40 1100 900];
g.xlim = [0 1];
g.xtick = 0:0.2:1;
g.tickLength = [0.01 0];
g.moveAxis = [1 1 0.70 0.95];
g.moveAxisShift = [0.16 0.02 0 0];
g.rowOffset = 0.18;
g.lineWidthCI = 4;
g.markerSize = 10;
g.bfX = 1.04;
g.font.axis = 18;
g.font.bf = 14;
g.font.legend = 16;
g.legend = {'original', 'replication'};
% Bottom-right whitespace inside the axes (right of data, above x-axis).
g.legendLocation = 'southeast';
g.legendShift = [0 0 0 0];
g.legendPosition = [0.58 0.12 0.14 0.08];  % figure-normalized; [] to use location+shift
g.color.original = pantone.PottersClay;
g.color.replication = pantone.LapisBlue;
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
