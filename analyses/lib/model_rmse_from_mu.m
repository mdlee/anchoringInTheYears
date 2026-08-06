function [rmsePoint, rmseCI, rmseSamples] = model_rmse_from_mu(chainsOrMu, truths, varargin)
%MODEL_RMSE_FROM_MU Aggregate model error from posterior means / samples of mu.
%
%   rmsePoint = model_rmse_from_mu(chains, truths)
%   [rmsePoint, rmseCI] = model_rmse_from_mu(chains, truths, 'PosteriorCI', true)
%   [rmsePoint, rmseCI, rmseSamples] = model_rmse_from_mu(...)
%
% Point summary (default / always returned):
%   RMSE (or mean abs error) comparing the posterior mean of mu for each
%   question to ground truth — same definition as the performance figures.
%
% Optional 95% CI ('PosteriorCI', true, or requesting rmseCI):
%   For each MCMC draw of the mu vector (joint over questions), compute the
%   same aggregate error metric across questions. Report the central CI% of
%   that sample distribution. This is the posterior uncertainty of the
%   aggregated RMSE/MAE, not a per-question interval.
%
% Inputs
%   chainsOrMu  - Trinity chains struct with fields mu_1..mu_Q, OR a vector of
%                 already-averaged mu values (CI requires chains).
%   truths      - Q x 1 ground truth
%
% Name-value options
%   'RelativeError'  (false)  use % of truth (see aggregate_relative_rmse)
%   'MeanAbs'        (false)  mean |error| instead of RMSE
%   'PosteriorCI'    (false)  compute CI (also on if nargout >= 2)
%   'CI'             (95)     credible interval percent
%   'Thin'           (1)      keep every Thin-th MCMC sample
%
% See also: aggregate_relative_rmse, codatable

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RelativeError', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'MeanAbs', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'PosteriorCI', false, @(x) islogical(x) || isnumeric(x));
addParameter(p, 'CI', 95, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 100);
addParameter(p, 'Thin', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});
opt = p.Results;
opt.RelativeError = logical(opt.RelativeError);
opt.MeanAbs = logical(opt.MeanAbs);
opt.PosteriorCI = logical(opt.PosteriorCI);
opt.Thin = max(1, round(opt.Thin));

truths = truths(:);
wantCI = opt.PosteriorCI || nargout >= 2;
rmseCI = [];
rmseSamples = [];

if isstruct(chainsOrMu)
    names = mu_field_names(chainsOrMu);
    nQ = numel(names);
    if nQ ~= numel(truths)
        error('model_rmse_from_mu:SizeMismatch', ...
            'Found %d mu_* fields but truths has %d entries.', nQ, numel(truths));
    end
    muMean = zeros(nQ, 1);
    for q = 1:nQ
        muMean(q) = mean(chainsOrMu.(names{q})(:));
    end
    rmsePoint = score_estimates(muMean, truths, opt);

    if wantCI
        nDraw = numel(chainsOrMu.(names{1}));
        keep = 1:opt.Thin:nDraw;
        nKeep = numel(keep);
        Mu = zeros(nKeep, nQ);
        for q = 1:nQ
            v = chainsOrMu.(names{q})(:);
            Mu(:, q) = v(keep);
        end
        rmseSamples = score_estimates_rows(Mu, truths, opt);
        lo = (100 - opt.CI) / 2;
        hi = 100 - lo;
        rmseCI = prctile(rmseSamples, [lo, hi]);
        rmseCI = rmseCI(:)';
    end
else
    muMean = chainsOrMu(:);
    if numel(muMean) ~= numel(truths)
        error('model_rmse_from_mu:SizeMismatch', ...
            'mu has %d entries but truths has %d.', numel(muMean), numel(truths));
    end
    rmsePoint = score_estimates(muMean, truths, opt);
    if wantCI
        error('model_rmse_from_mu:NeedChains', ...
            'Posterior CI requires a chains struct with mu_* fields.');
    end
end
end

function err = score_estimates(estimates, truths, opt)
errRows = score_estimates_rows(estimates(:)', truths, opt);
err = errRows(1);
end

function err = score_estimates_rows(Mu, truths, opt)
% Mu is nSamples x nQuestions (or 1 x nQuestions)
truths = truths(:)'; % 1 x nQ
nS = size(Mu, 1);
if size(Mu, 2) ~= numel(truths)
    error('model_rmse_from_mu:SizeMismatch', ...
        'Mu has %d columns but truths has %d entries.', size(Mu, 2), numel(truths));
end
if opt.RelativeError
    valid = isfinite(truths) & truths ~= 0;
    if ~any(valid)
        err = nan(nS, 1);
        return;
    end
    rel = (Mu(:, valid) - truths(valid)) ./ truths(valid) * 100;
    if opt.MeanAbs
        err = mean(abs(rel), 2, 'omitnan');
    else
        err = sqrt(mean(rel.^2, 2, 'omitnan'));
    end
elseif opt.MeanAbs
    err = mean(abs(Mu - truths), 2, 'omitnan');
else
    err = sqrt(mean((Mu - truths).^2, 2, 'omitnan'));
end
end

function names = mu_field_names(chains)
fn = fieldnames(chains);
nums = [];
for i = 1:numel(fn)
    tok = regexp(fn{i}, '^mu_(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        nums(end+1) = str2double(tok{1}); %#ok<AGROW>
    end
end
if isempty(nums)
    error('model_rmse_from_mu:NoMu', 'No mu_<k> fields found in chains.');
end
nums = sort(nums);
names = arrayfun(@(k) sprintf('mu_%d', k), nums, 'UniformOutput', false);
end
