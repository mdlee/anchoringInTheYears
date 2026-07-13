Code and data for the paper:

Lee, M.D., & Dang, A. (2026). Comparing diversity and debiasing approaches to the wisdom of the crowd.

# Data

The behavioral data for the event years experiment are in the csv file `anchorYearsDecontaminatedLong.csv`. It is in a long format, with the following columns
- `participant`: a unique participant ID from 1 to 194
- `question`: a unique question number from 1 to 11 (1 = 'Thriller', 2 = 'Internet', 3 = 'Disneyland', 4 = 'Great Depression', 5 = 'iPhone', 6 = 'Firefox', 7 = 'Youtube', 8 = 'McDonalds', 9 = 'Revolutionary War', 10 = 'Reagan', 11 = 'Pixar')
- `version`: a number from 1 to 3 indicating which version of the experiment the participant completed (1 = one of the anchor versions, 2 = the other anchor version, 3 = the no anchor version)
- `truth`: the correct answer for the question
- `anchor`: the comparison number used as an anchor (nan for no anchor questions)
- `highOrLow`: the answer to the comparison question (1 = high, 2 = low, nan for no anchor questions)
- `estimate`: the estimated answer provided by the participant

The open data for Experiment 2 of

Barrera-Lemarchand, F., Balenzuela, P., Bahrami, B., Deroy, O., & Navajas, J. (2024). Promoting erroneous divergent opinions increases the wisdom of crowds. Psychological Science, 35(8), 872–886, [https://doi.org/10.1177/09567976241251991](https://doi.org/10.1177/09567976241251991).

were sourced from the data file [Experiment2withoutlog.mat](https://osf.io/w3ts9) in this [OSF repository](https://osf.io/ch5qw/).

# Code

The anchoring index analyses are produced by running the  MATLAB script `anchoringIndex.m`, specifying the question numbers to analyze in the vector `questionList`. This script uses the JAGS graphical model defined in `anchoringIndex_jags.txt`.

The debiasing model analyses are produced by running the  MATLAB script `debiasing.m`, which uses the JAGS graphical model defined in `debiasing_jags.txt`.

Both MATLAB scripts use the [Trinity](https://github.com/joachimvandekerckhove/trinity) package to connect MATLAB and JAGS via the `callBayes` function.

# Results

Results graphs for all 11 questions in the event years data and 30 questions in the Barrera-Lemarchand (2024, Experiment 2) data are in the [results](https://github.com/mdlee/anchoringInTheYears/tree/main/results) subfolder.
