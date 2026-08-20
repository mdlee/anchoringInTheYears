# anchoringInTheYears

Code and data for:

> Lee, M.D., & Dang, A. (2026). Comparing diversity and debiasing approaches to the wisdom of the crowd.

This repository supports the event-years anchoring experiment and a reanalysis of Experiment 2 from Barrera-Lemarchand et al. (2024). It contains long-format behavioral data, JAGS/MATLAB model scripts, result-generation code, and additional diagnostic outputs.

## Repository layout

```
anchoringInTheYears/
├── data/                     # Behavioral data and supporting mats
├── models/
│   ├── anchoringIndex/       # Per-question anchoring-index JAGS model
│   └── debiasing/            # Hierarchical debiasing JAGS model
├── analyses/
│   ├── analyses.m            # Main results driver
│   ├── lib/                  # Plotting / helper functions
│   └── results/
│       ├── diversityPredictionTheorem/   # Per-question two-panel DPT figures
│       ├── anchoringIndex/               # prior/posterior + forest plots
│       ├── performance/
│       ├── debiasingModel/
│       ├── expertiseVsAnchoring/
│       ├── outlierRuleComparison/
│       │   └── contaminantVsOutlier.txt
│       ├── debiasingVsAnchoredPerQuestion/  # per-question anchoring model vs anchor crowd
│       └── constrainedDebiasing/            # expertise-only / anchoring-only / anchored-only
└── README.md
```

Each figure-producing analysis writes into `analyses/results/<analysisName>/{png,eps}/`. Non-figure artifacts (e.g. `contaminantVsOutlier.txt`) sit beside those folders under the same analysis name.

## Data

### Event years (`data/anchorYearsDecontaminatedLong.csv`)

Long-format estimates after contaminant removal (mean ± 3 SD parse; see `outlierRuleComparison`). Columns:

| Column | Description |
| --- | --- |
| `participant` | Participant ID (1–194) |
| `question` | Question ID (1–11) |
| `version` | Task version (1/2 = anchored; 3 = no anchor) |
| `truth` | Correct year |
| `anchor` | Comparison value (`nan` if no anchor) |
| `highOrLow` | Comparison response (1 = high, 2 = low, `nan` if no anchor) |
| `estimate` | Year estimate |

Question IDs: 1 Thriller, 2 Internet, 3 Disneyland, 4 Great Depression, 5 iPhone, 6 Firefox, 7 Youtube, 8 McDonald's, 9 Revolutionary War, 10 Reagan, 11 Pixar.

Supporting mats used by analysis code:

- `data/anchorYearsData.mat` — structured cleaned event-years data
- `data/anchoring140JW2024.mat` — raw pre-parse source for outlier-rule comparison
- `data/pantoneColors.mat` — shared figure colors

### Barrera-Lemarchand Experiment 2 (`data/barreraEtAlExperiment2Long.csv`)

Open data for Experiment 2 of:

> Barrera-Lemarchand, F., Balenzuela, P., Bahrami, B., Deroy, O., & Navajas, J. (2024). Promoting erroneous divergent opinions increases the wisdom of crowds. *Psychological Science, 35*(8), 872–886. https://doi.org/10.1177/09567976241251991

Sourced from [Experiment2withoutlog.mat](https://osf.io/w3ts9) in the [OSF repository](https://osf.io/ch5qw/). Same long-format column names; here `version` encodes group (1 = low anchor, 2 = high anchor, 3 = no anchor). Supporting mat: `data/barreraEtAlExp2.mat`.

### COGS140J F2025 percentageEstimation (`data/percentageEstimationF2025Long.csv`)

Combines two class cohorts on the **same 25** general-knowledge percentage items:

- **F2025**: between-subjects slider-start as anchoring on **0%** (left) vs **100%** (right)
- **W2024**: same items, no slider-side manipulation → treated as the **no-anchor** group

| Column | Description |
| --- | --- |
| `participant` | Participant ID (1–324; 98 left + 56 right + 170 no-anchor) |
| `question` | Question ID (1–25) |
| `version` | 1 = slider left (anchor 0); 2 = slider right (anchor 100); 3 = no anchor (W2024) |
| `truth` | Correct percentage |
| `anchor` | 0, 100, or `nan` |
| `highOrLow` | `nan` (no comparison response) |
| `estimate` | Percentage estimate (0–100) |

Supporting mat: `data/percentageEstimationF2025.mat`. Source mats: `COGS140J/tasks/percentageEstimation/140JF2025Estimation.mat` and `140JW2024Estimation.mat`.

Pipeline entry: from the repo root, run `run_percentageEstimationF2025.m` (fits anchoring-index + debiasing, then `analyses.m`). Or fit separately:

```matlab
cd models/anchoringIndex; anchoringIndex_percentageEstimationF2025
cd ../debiasing; debiasing_percentageEstimationF2025
cd ../../analyses; analyses   % with dataList = {'percentageEstimationF2025'}
```

## Models

Both model scripts use [Trinity](https://github.com/joachimvandekerckhove/trinity) (`callbayes`) to connect MATLAB and JAGS. Run them from their own folders so relative `storage/` paths resolve correctly.

### Anchoring index — `models/anchoringIndex/`

- Script: `anchoringIndex.m`
- JAGS: `anchoringIndex_jags.txt`
- Set `questionList` to the question indices to analyze
- Monitors posterior `A` and prior predictive `Aprior`
- Writes `storage/anchoringIndex_<q>_jags.mat`

Priors are scaled from the observed min/max/mean of the estimates for each question.

### Debiasing model — `models/debiasing/`

- Script: `debiasing.m`
- JAGS: `debiasing_jags.txt`
- Long-format nodes: `y`, `participant`, `question`, `anchor`, `version`
- Monitors crowd means `mu` and person-level `alpha` (anchor weight) and `sigma` (expertise)
- Writes `storage/debiasing_<dataName>_jags.mat`

Toggle `dataName` / CSV inside `debiasing.m` to fit event years or Barrera Exp 2.

## Generating results — `analyses/analyses.m`

Comment entries in/out of two cell arrays:

```matlab
dataList = {
   'anchorYears'
   'barrera'
   };

analysisList = {
   'diversityPredictionTheorem'
   'anchoringIndex'
   'allQanchoring'
   'performance'
   'debiasingModel'
   'expertiseVsAnchoring'
   'outlierRuleComparison'
   'debiasingVsAnchoredPerQuestion'
   'constrainedDebiasing'
   };
```

Font sizes and related styling live in the `%% Fine tune` block at the top of `analyses.m`.

### Analysis → output folder

| Analysis | Folder under `analyses/results/` | Notes |
| --- | --- | --- |
| `diversityPredictionTheorem` | `diversityPredictionTheorem/{png,eps}/` | Per-question two-panel DPT figures |
| `anchoringIndex` | `anchoringIndex/{png,eps}/` | Firefox prior/posterior (event years) |
| `allQanchoring` | `anchoringIndex/{png,eps}/` | Forest plots of anchoring indices (same folder) |
| `performance` | `performance/{png,eps}/` | Crowd / model RMSE comparison |
| `debiasingModel` | `debiasingModel/{png,eps}/` | Debiasing schematic |
| `expertiseVsAnchoring` | `expertiseVsAnchoring/{png,eps}/` | Inferred expertise vs anchoring |
| `outlierRuleComparison` | `outlierRuleComparison/` | Text report + optional bar chart; event years only |
| `debiasingVsAnchoredPerQuestion` | `debiasingVsAnchoredPerQuestion/` | Text report: per-question \|err\| anchoring model vs anchor crowd |
| `constrainedDebiasing` | `constrainedDebiasing/` | Text report: expertise-only / anchoring-only / anchored-only RMSE |

`outlierRuleComparison` rebuilds raw long data from `anchoring140JW2024.mat` and compares the parse rule (mean ± 3 SD, second pass on McDonald's and Pixar) with classic 1.5 × IQR fences. Report: `contaminantVsOutlier.txt`.

`debiasingVsAnchoredPerQuestion` compares the anchoring-model crowd estimate to the anchor crowd on each question for event years and Barrera Exp 2. Reports: `anchorYears.txt`, `barreraLemarchandExperiment2.txt`.

`constrainedDebiasing` compares anchoring model, expertise-only (`alpha=0`), anchoring-only (common `sigma`), and anchoring-model-on-anchored-only fits against full / anchor / no-anchor crowd averages. Reports: `anchorYears.txt`, `barreraLemarchandExperiment2.txt`. Anchored-only fits can be produced with `analyses/lib/fit_anchored_only_debiasing.m`.

### Dependencies for `analyses.m`

- MATLAB with Trinity / JAGS sample mats available under model or analyses `storage/` (see `analyses/lib/find_mcmc_storage.m`)
- Helpers `setFigure`, `moveAxis`, `Raxes` on the MATLAB path
- Trinity `codatable` for summarizing MCMC chains

## License / citation

If you use the event-years data or analyses, please cite the Lee & Dang (2026) paper. If you use the Barrera-Lemarchand Experiment 2 materials, please also cite Barrera-Lemarchand et al. (2024) and their OSF deposit.
