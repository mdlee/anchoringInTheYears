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

%% Fine tune
% Adjust figure styling here; more knobs can be added later.
fineTune.font.diversityPredictionTheorem = 24;  % two-panel DPT figures (axis); labels use +2 / annotations -2
fineTune.font.anchoringIndex          = 24;  % Firefox prior/posterior (axis); xlabel +2
fineTune.font.allQanchoring           = 24;  % event-years all-question forest (BF text -2)
fineTune.font.allQanchoringBarrera    = 18;  % Barrera all-question forest (BF text -4)
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
fineTune.performance.font.insetLabel = 16;  % inset xlabel / ylabel
fineTune.performance.font.insetCorr = 16;   % r= annotation

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

%% Datasets (comment in/out)
dataList = {
   % 'anchorYears'   % event-years experiment
   % 'barrera'       % Barrera-Lemarchand Experiment 2
   'percentageEstimationF2025'  % COGS140J F2025 slider 0% vs 100%
   };

%% Analyses (comment in/out)
% Each analysis writes under analyses/results/<name>/
%   diversityPredictionTheorem — all datasets (F2025: no no-anchor curves)
%   anchoringIndex          — anchorYears only (Firefox prior/posterior); writes anchoringIndex/
%   allQanchoring           — all; also writes under anchoringIndex/
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
    'performance'
   % 'debiasingModel'
   % 'expertiseVsAnchoring'
   % 'outlierRuleComparison'
   % 'debiasingVsAnchoredPerQuestion'
    %'constrainedDebiasing'
    %'aggregateAnchorBF'
   };

%% Draw
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
      otherwise
         warning('Unknown dataset: %s', dataName);
   end
end

fprintf('\nDone. Outputs are under analyses/results/<analysis>/{png,eps}.\n');
