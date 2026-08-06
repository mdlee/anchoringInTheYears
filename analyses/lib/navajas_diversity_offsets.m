function offset = navajas_diversity_offsets(nQuestions)
%NAVAJAS_DIVERSITY_OFFSETS Text label offsets from anchorYearsNavajas_0.m
offset = zeros(nQuestions, 6);
if nQuestions < 1
    return;
end
rows = min(nQuestions, 11);
offset(1, 5) = 1.5;
if rows >= 2
    offset(2, :) = [0 -2 1.5 -1.5 -2 1.5];
end
if rows >= 3
    offset(3, 2) = -10;
end
if rows >= 4
    offset(4, 2:3) = [-10 10];
end
if rows >= 5
    offset(5, 6) = -0.25;
end
if rows >= 6
    offset(6, 4) = 1.5;
end
if rows >= 8
    offset(8, 2:3) = [-10 10];
end
if rows >= 9
    offset(9, 2:3) = [-70 70];
end
if rows >= 10
    offset(10, :) = [0 -1.5 1.5 -1.5 -2 1.5] * 2;
end
if rows >= 11
    offset(11, :) = [0 0 0 -2 -1 0];
end
end
