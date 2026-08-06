function d = ensure_navajas_estimate_cells(d)
%ENSURE_NAVAJAS_ESTIMATE_CELLS Build d.estimate{q,1/2/3} means if missing.
% Col 1 = no-anchor, col 2 = high anchor, col 3 = low anchor.
needsBuild = true;
if isfield(d, 'estimate') && size(d.estimate, 1) >= d.nQuestions && size(d.estimate, 2) >= 3
    sample = d.estimate{1, 1};
    if isscalar(sample) && ~isnan(sample)
        needsBuild = false;
    end
end

if ~needsBuild
    return;
end

if isfield(d, 'estimateLong') && isfield(d, 'groupLong') && isfield(d, 'questionLong')
    for q = 1:d.nQuestions
        yNo = d.estimateLong(d.groupLong == 3 & d.questionLong == q);
        yHi = d.estimateLong(d.groupLong == 2 & d.questionLong == q);
        yLo = d.estimateLong(d.groupLong == 1 & d.questionLong == q);
        d.estimate{q, 1} = mean(yNo, 'omitnan');
        d.estimate{q, 2} = mean(yHi, 'omitnan');
        d.estimate{q, 3} = mean(yLo, 'omitnan');
    end
elseif isfield(d, 'yN') && isfield(d, 'yH') && isfield(d, 'yL')
    for q = 1:d.nQuestions
        d.estimate{q, 1} = nanmean(d.yN(:, q));
        d.estimate{q, 2} = nanmean(d.yH(:, q));
        d.estimate{q, 3} = nanmean(d.yL(:, q));
    end
end
end
