%% analyses
% Consolidated results generation for this repository.
%
% Combines analyses previously split across
%   CC2/code/anchorYears/anchorYears_0.m
%   CC2/code/anchorYears/anchorYearsNavajas_0.m
%
% Outputs go under analyses/results/<analysisName>/{png,eps}/
% (plus any non-figure artifacts such as contaminantVsOutlier.txt).
%
% Comment entries in/out of dataList and analysisList to choose what to run.
% Some analyses apply to only one dataset; choose combinations that make sense.

clear; close all;

printFigures = true;

%% Analyses (comment in/out)
% Each analysis writes under analyses/results/<name>/
%   diversityPredictionTheorem — all datasets (F2025: no no-anchor curves)
%   anchoringIndex          — anchorYears only (Firefox prior/posterior); writes anchoringIndex/
%   allQanchoring           — all; also writes under anchoringIndex/
%   allQanchoringReplication — original vs replication dual forest (dataset-
%       independent; needs both stored anchoring-index fits). Writes under anchoringIndex/
%   performanceReplication  — original vs replication combined WOC figure
%       (one histogram + 2x2 insets; dataset-independent; needs both
%       debiasing fits). Writes under performance/
%   performanceOriginalReplication — 2x1 original (A) / replication (B):
%       person histogram, model RMSE+CI, full/anchor/no-anchor aggregates,
%       expertise + anchoring insets. Shares original no-anchor cohort with
%       the replication panel.
%   performanceOriginal — single-panel original event-years WOC figure
%       (histogram, model+CI, full/anchor/no-anchor, insets); original-
%       submission layout.
%   performance             — all; also writes DiverseDebiasing variant
%                             (debiasing + diverse debiasing = anchored-only fit)
%   debiasingModel          — schematic; dataset-independent
%   expertiseVsAnchoring    — all (additional / not in paper)
%   outlierRuleComparison   — anchorYears only (additional / not in paper)
%   debiasingVsAnchoredPerQuestion — all; text report of per-question accuracy
%   constrainedDebiasing — all; text report of expertise-only / anchoring-only /
%       full / full-anchored-only RMSE vs crowd averages and full model
%   aggregateAnchorBF   — percentageEstimationF2025 only; Savage–Dickey BF for
%       overall L vs R person-mean difference (aggregated over questions)
analysisList = {
    %'diversityPredictionTheorem'
   % 'anchoringIndex'
    %'allQanchoring'
  %  'allQanchoringReplication'
   % 'performanceReplication'
    'performanceOriginalReplication'
  %  'performanceOriginal'
    %'performance'
   % 'debiasingModel'
   % 'expertiseVsAnchoring'
   % 'outlierRuleComparison'
   % 'debiasingVsAnchoredPerQuestion'
    %'constrainedDebiasing'
    %'aggregateAnchorBF'
   };

%% Datasets (comment in/out)
dataList = {
   % 'anchorYears'   % event-years experiment
   % 'barrera'       % Barrera-Lemarchand Experiment 2
   % 'percentageEstimationF2025'  % COGS140J F2025 slider 0% vs 100%
   % 'anchorYearsF2026'  % COGS140J F2026, same 11 event-year questions, percentile anchors
   };

%% Fine tune
% Adjust figure styling here; more knobs can be added later.
fineTune.font.diversityPredictionTheorem = 24;  % two-panel DPT figures (axis); labels use +2 / annotations -2
fineTune.font.anchoringIndex          = 24;  % Firefox prior/posterior (axis); xlabel +2
fineTune.font.allQanchoring           = 24;  % event-years all-question forest (BF text -2)
fineTune.font.allQanchoringBarrera    = 18;  % Barrera all-question forest (BF text -4)
fineTune.font.allQanchoringReplication = 18; % original vs F2026 dual forest

% Dual forest (original vs F2026): colors / offsets under fineTune.allQanchoringReplication
% fineTune.allQanchoringReplication.rowOffset = 0.18;
% fineTune.allQanchoringReplication.color.original = ...;
% fineTune.allQanchoringReplication.color.replication = ...;
fineTune.font.performance             = 16;  % legacy; prefer fineTune.performance.font below
fineTune.font.debiasingModel          = 18;  % debiasing schematic (labels +2)
fineTune.font.expertiseVsAnchoring    = 16;  % expertise–anchoring scatter (axis labels +2)
fineTune.font.outlierRuleComparison   = 12;  % outlier-rule bar chart

% Performance plot graphics (percentageEstimationF2025; also usable for Barrera)
fineTune.performance.xlim = [10 75];
fineTune.performance.xtick = 10:10:70;
% Inset axes: bottom-left [x y] in normalized figure units, shared size
fineTune.performance.insetExpertise.bottomLeft = [0.75 0.5];  % inferred expertise vs error
fineTune.performance.insetAnchoring.bottomLeft = [0.5 0.5];   % inferred vs observed anchoring
fineTune.performance.insetWidth = 0.2;
fineTune.performance.insetHeight = 0.4;
fineTune.performance.font.axis = 16;        % main histogram axis tick labels
fineTune.performance.font.xlabel = 18;      % "Root Mean Squared Error"
fineTune.performance.font.crowdLabel = 16;  % full/anchor/no-anchor/model vertical labels
fineTune.performance.font.insetAxis = 16;   % inset tick labels
fineTune.performance.font.insetLabel = 18;  % inset xlabel / ylabel
fineTune.performance.font.insetCorr = 18;   % r= annotation

% Combined original-vs-replication performance figure
% (plot_performance_replication). Uncomment / edit any field to override
% defaults from default_performance_replication_graphics.
%
% fineTune.performanceReplication.figure.pixelPosition = [40 40 1400 900];
% fineTune.performanceReplication.mainAxis.position = [0.07 0.12 0.58 0.78];
% fineTune.performanceReplication.xlim = [0 60];
% fineTune.performanceReplication.xtick = 0:10:60;
% fineTune.performanceReplication.yLimPad = 1.45;
% fineTune.performanceReplication.lineWidth = 3.5;
% fineTune.performanceReplication.ci.originalAlpha = 0.22;
% fineTune.performanceReplication.ci.replicationAlpha = 0.18;
% Person tiles
% fineTune.performanceReplication.color.personAnchored = ...;      % DuskBlue
% fineTune.performanceReplication.color.personNoAnchor = ...;      % Hazelnut
% fineTune.performanceReplication.color.personReplication = ...;   % light DuskBlue
% Aggregate lines
% fineTune.performanceReplication.color.modelOriginal = ...;       % Sandstone
% fineTune.performanceReplication.color.modelReplication = ...;    % ClassicBlue
% fineTune.performanceReplication.color.fullOriginal = [0 0 0];
% fineTune.performanceReplication.color.fullReplication = ...;     % StormyWeather
% fineTune.performanceReplication.color.anchorOriginal = ...;      % LapisBlue
% fineTune.performanceReplication.color.noAnchorOriginal = ...;    % Hazelnut
% Line label heights (fraction of yLim)
% fineTune.performanceReplication.line.modelOriginalMult = 1.08;
% fineTune.performanceReplication.line.modelReplicationMult = 1.00;
% fineTune.performanceReplication.line.anchorOriginalMult = 0.92;
% fineTune.performanceReplication.line.fullOriginalMult = 0.84;
% fineTune.performanceReplication.line.fullReplicationMult = 0.76;
% fineTune.performanceReplication.line.noAnchorOriginalMult = 0.68;
% fineTune.performanceReplication.label.modelOriginal = ' orig. debiasing';
% fineTune.performanceReplication.label.modelReplication = ' rep. debiasing';
% 2x2 insets: [orig expertise | orig anchoring; rep expertise | rep anchoring]
% fineTune.performanceReplication.inset.origExpertise = [0.68 0.37 0.155 0.195];
% fineTune.performanceReplication.inset.origAnchoring = [0.85 0.37 0.155 0.195];
% fineTune.performanceReplication.inset.repExpertise  = [0.68 0.12 0.155 0.195];
% fineTune.performanceReplication.inset.repAnchoring  = [0.85 0.12 0.155 0.195];
% fineTune.performanceReplication.legend.position = [0.07 0.88 0.22 0.10];
% fineTune.performanceReplication.font.crowdLabel = 12;
% fineTune.performanceReplication.font.inset = 11;

% 2x1 original / replication performance (shared no-anchor cohort).
% All layout normalized; set_figure_safe auto-detects dual monitors.
% Defaults: default_performance_original_replication_graphics.
%
 fineTune.performanceOriginalReplication.figure.position = [0.05 0.02 0.5 0.836];
% fineTune.performanceOriginalReplication.figure.dual = '';  % '' auto | leave | single | upDown | leftRight
% Panel / main axes (normalized [l b w h]):
 fineTune.performanceOriginalReplication.panel.A = [0.01 0.52 0.98 0.42];
 fineTune.performanceOriginalReplication.panel.B = [0.01 0.05 0.98 0.42];
% fineTune.performanceOriginalReplication.mainAxis.position = [0.09 0.14 0.84 0.74];
% A/B panel labels:
 fineTune.performanceOriginalReplication.panelLetter.A.position = [0.01 0.965 0.28 0.04];
 fineTune.performanceOriginalReplication.panelLetter.B.position = [0.01 0.475 0.28 0.04];
% fineTune.performanceOriginalReplication.panelLetter.A.fontSize = 20;
% fineTune.performanceOriginalReplication.panelLetter.B.fontSize = 20;
% fineTune.performanceOriginalReplication.panelLetter.A.str = 'A  Original';
% fineTune.performanceOriginalReplication.panelLetter.B.str = 'B  Replication';
% Insets (panel-relative); forceSquare uses on-screen aspect after placement
% fineTune.performanceOriginalReplication.inset.forceSquare = true;
 fineTune.performanceOriginalReplication.insetExpertise.position = [0.76 0.48 0.18 0.36];
 fineTune.performanceOriginalReplication.insetAnchoring.position = [0.50 0.48 0.18 0.36];
 fineTune.performanceOriginalReplication.font.axis = 18;
 fineTune.performanceOriginalReplication.font.xlabel = 20;
 fineTune.performanceOriginalReplication.font.crowdLabel = 16;
 fineTune.performanceOriginalReplication.font.inset = 16;       % inset tick labels
 fineTune.performanceOriginalReplication.font.insetLabel = 16;  % inset xlabel / ylabel
 fineTune.performanceOriginalReplication.font.insetCorr = 16;   % r= annotation
% fineTune.performanceOriginalReplication.xlim = [0 60];
% fineTune.performanceOriginalReplication.lineWidth = 4;

% Single-panel original performance (submission layout)
% fineTune.performanceOriginal.figure.pixelPosition = [80 80 1200 700];
% fineTune.performanceOriginal.insetExpertise.bottomLeft = [0.75 0.50];
% fineTune.performanceOriginal.insetAnchoring.bottomLeft = [0.50 0.50];
% fineTune.performanceOriginal.insetWidth = 0.20;
% fineTune.performanceOriginal.insetHeight = 0.40;
% fineTune.performanceOriginal.lineWidth = 4;
% fineTune.performanceOriginal.ci.faceAlpha = 0.22;

%% Paths
thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(thisDir);
addpath(thisDir);
addpath(fullfile(thisDir, 'lib'));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');
% Prefer analyses/lib helpers (e.g. headless-safe setFigure) over MatlabAddOns
addpath(fullfile(thisDir, 'lib'), '-begin');

storageDirs = find_mcmc_storage(repoRoot);
fprintf('Using storage dirs:\n');
fprintf('  %s\n', storageDirs{:});

%% Draw
% Dual original-vs-replication figures do not need a dataList entry.
if any(strcmp(analysisList, 'allQanchoringReplication'))
   fprintf('\n=== Analysis: allQanchoringReplication ===\n');
   plot_all_q_anchoring_replication(repoRoot, storageDirs, printFigures, fineTune);
end
if any(strcmp(analysisList, 'performanceReplication'))
   fprintf('\n=== Analysis: performanceReplication ===\n');
   plot_performance_replication(repoRoot, storageDirs, printFigures, fineTune);
end
if any(strcmp(analysisList, 'performanceOriginalReplication'))
   fprintf('\n=== Analysis: performanceOriginalReplication ===\n');
   plot_performance_original_replication(repoRoot, storageDirs, printFigures, fineTune);
end
if any(strcmp(analysisList, 'performanceOriginal'))
   fprintf('\n=== Analysis: performanceOriginal ===\n');
   plot_performance_original(repoRoot, storageDirs, printFigures, fineTune);
end

for dataIdx = 1:numel(dataList)
   dataName = dataList{dataIdx};
   fprintf('\n=== Dataset: %s ===\n', dataName);
   switch dataName
      case 'anchorYears'
         plot_anchor_years_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      case 'barrera'
         plot_barrera_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      case 'percentageEstimationF2025'
         plot_percentage_estimation_f2025_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      case 'anchorYearsF2026'
         plot_anchor_years_f2026_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      otherwise
         warning('Unknown dataset: %s', dataName);
   end
end

fprintf('\nDone. Outputs are under analyses/results/<analysis>/{png,eps}.\n');
