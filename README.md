Code and data for the paper:

Lee, M.D., & Dang, A. (2025). Comparing diversity and debiasing approaches to the wisdom of the crowd in anchored estimation.

# Data

The csv file `anchorYearsDecontaminatedLong.csv` contains the behavioral data. It is in a long format, with the following columns
- `participant`: a unique participant ID from 1 to 194
- `question`: a unique question number from 1 to 11 (1 = 'Thriller', 2 = 'Internet', 3 = 'Disneyland', 4 = 'Great Depression', 5 = 'iPhone', 6 = 'Firefox', 7 = 'Youtube', 8 = 'McDonalds', 9 = 'Revolutionary War', 10 = 'Reagan', 11 = 'Pixar')
- `version`: a number from 1 to 3 indicating which version of the experiment the participant completed (1 = one of the anchor versions, 2 = the other anchor version, 3 = the no anchor version)
- `truth`: the correct answer for the question
- `anchor`: the comparison number used as an anchor (nan for no anchor questions)
- `highOrLow`: the answer to the comparison question (1 = high, 2 = low, nan for no anchor questions)
- `estimate`: the estimated answer provided by the participant

# Code

The anchoring index analyses are produced by running the  MATLAB script `anchoringIndex.m`, specifying the question numbers to analyze in the vector `questionList`. This script uses the JAGS graphical model defined in `anchoringIndex_jags.txt`.

The debiasing model analyses are produced by running the  MATLAB script `debiasing.m`, which uses the JAGS graphical model defined in `debiasing_jags.txt`.

Both MATLAB scripts use the [Trinity](https://github.com/joachimvandekerckhove/trinity) package to connect MATLAB and JAGS via the `callBayes` function.

# Results

Results graphs for all eleven questions are in the [results](https://github.com/mdlee/anchoringInTheYears/tree/main/results) subfolder.
