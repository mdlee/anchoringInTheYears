function plot_expertise_vs_anchoring(d, pantone, peopleColor, storageDirs, dataset, fineTune)
%PLOT_EXPERTISE_VS_ANCHORING Inferred expertise vs anchoring scatter.
if nargin < 6 || isempty(fineTune)
    fineTune = default_fine_tune();
end
fontSize = fineTune.font.expertiseVsAnchoring;
rng(1);
switch dataset
    case 'anchorYears'
        jagsCandidates = {'debiasing_anchorYears_jags.mat', 'anchorYears_7b2_anchorYears_jags.mat'};
        anchoredGroup = 12;
        noAnchorGroup = 3;
        xMaxFloor = 75;
    case 'barreraEtAlExperiment2'
        jagsCandidates = {'debiasing_barreraEtAlExperiment2_jags.mat', 'debiasingNavajas_6_navajasExperiment2_jags.mat'};
        anchoredGroup = 2;
        noAnchorGroup = 1;
        xMaxFloor = 1;
    case 'percentageEstimationF2025'
        jagsCandidates = {'debiasing_percentageEstimationF2025_jags.mat'};
        anchoredGroup = 2;
        noAnchorGroup = 1;  % W2024 no-anchor
        xMaxFloor = 1;
    case 'anchorYearsF2026'
        jagsCandidates = {'debiasing_anchorYearsF2026_jags.mat'};
        anchoredGroup = 12;
        noAnchorGroup = 3;
        xMaxFloor = 75;
    otherwise
        error('Unknown dataset %s', dataset);
end
jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath)
        break;
    end
end
if isempty(jagsPath)
    error('Missing debiasing MCMC for %s', dataset);
end
S = load(jagsPath, 'chains');
sigmaA = codatable(S.chains, 'sigma', @mean);
alphaA = codatable(S.chains, 'alpha', @mean);
keepAnchored = find(d.participantGroup == anchoredGroup);
sigmaPlot = sigmaA(keepAnchored);
alphaPlot = alphaA(keepAnchored);
keep = isfinite(sigmaPlot) & isfinite(alphaPlot);
sigmaPlot = sigmaPlot(keep);
alphaPlot = alphaPlot(keep);
groups = d.participantGroup(keepAnchored);
groups = groups(keep);
r = corrcoef(sigmaPlot, alphaPlot, 'Rows', 'complete');

F = figure; clf; hold on;
set_figure_safe(F, [0.35 0.3 0.35 0.45], '');
xMax = max(ceil(max(sigmaPlot) * 1.05), xMaxFloor);
set(gca, ...
    'xlim', [0 xMax], ...
    'xtick', [0 xMax], ...
    'xticklabel', {'hi', 'lo'}, ...
    'ylim', [-1 1], ...
    'ytick', [-1 0 1], ...
    'box', 'off', ...
    'tickdir', 'out', ...
    'ticklength', [0.02 0], ...
    'fontsize', fontSize);
axis square;
xlabel('inferred expertise', 'fontsize', fontSize + 2);
ylabel('inferred anchoring', 'fontsize', fontSize + 2);
moveAxis(gca, [1 1 0.95 0.9], [0 0.05 0 0]);
Raxes(gca, 0.01, 0.01);
shuffle = randperm(numel(sigmaPlot));
for k = 1:numel(shuffle)
    idx = shuffle(k);
    H = plot(sigmaPlot(idx), alphaPlot(idx), 'o', ...
        'markerfacecolor', pantone.DuskBlue, ...
        'markersize', 7, ...
        'markeredgecolor', 'k');
    if groups(idx) == noAnchorGroup
        set(H, 'markerfacecolor', peopleColor{3});
    end
end
xl = xlim;
yl = ylim;
text(xl(1), yl(2), sprintf('r=%.2f', r(1, 2)), ...
    'fontsize', fontSize, 'hor', 'left', 'vert', 'top');
fprintf('%s expertise vs anchoring r=%.4f\n', dataset, r(1, 2));
end
