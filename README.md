Code and data for the paper:

Lee, M.D., & Dang, A. (2025). Comparing Diversity and Debiasing Approaches to the\\Wisdom of the Crowd in Anchored Estimation.

# Data

`anchorYearsDecontaminatedLong.csv` contains the behavioral data. It is in a long format, with the following columns
- `participant`: a unique participant ID from 1 to 194
- `question`: a unique question number from 1 to 11 (1 = 'Thriller', 2 = 'Internet', 3 = 'Disneyland', 4 = 'Great Depression', 5 = 'iPhone', 6 = 'Firefox', 7 = 'Youtube', 8 = 'McDonalds', 9 = 'Revolutionary War', 10 = 'Reagan', 11 = 'Pixar')
- `version`: a number from 1 to 3 indicating which version of the experiment the participant completed (1 = one of the anchor versions, 2 = the other anchor version, 3 = the no anchor version)
- `truth`: the correct answer for the question
- `anchor`: the comparison number used as an anchor (nan for no anchor questions)
- `highOrLow`: the answer to the comparison question (1 = high, 2 = low, nan for no anchor questions)
- `estimate`: the estimated answer provided by the participant

  # Code
