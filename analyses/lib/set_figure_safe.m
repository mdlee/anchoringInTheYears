function set_figure_safe(F, position, dual)
%SET_FIGURE_SAFE Figure setup with normalized position + dual-monitor detection.
% Drop-in for setFigure(F, position, dual): position is normalized
% [left bottom width height]. dual is '' / [] (auto-detect), 'leave',
% 'single', 'upDown', or 'leftRight'.
%
% Headless / unknown displays fall back to Units=normalized.

if nargin < 3 || isempty(dual)
    dual = '';
end

try
    tmp = get(0, 'MonitorPositions');
catch
    apply_normalized(F, position);
    return;
end

if isempty(tmp) || ~isnumeric(tmp) || size(tmp, 2) < 4
    apply_normalized(F, position);
    return;
end

% Auto-detect arrangement when dual not supplied (same rules as setFigure).
if isempty(dual)
    dual = detect_dual(tmp);
end

if strcmp(dual, 'leave')
    apply_normalized(F, position);
    return;
end

% Map normalized position onto the detected monitor geometry (pixels).
try
    vec = normalized_to_pixels(tmp, position, dual);
catch
    apply_normalized(F, position);
    return;
end

set(F, ...
    'color', 'w', ...
    'units', 'pixels', ...
    'position', vec, ...
    'papersize', [10 6.75], ...
    'paperpositionmode', 'auto');
end


function dual = detect_dual(tmp)
[rows, ~] = size(tmp);
if rows == 2
    dual = 'leave';
    return;
end
w = tmp(3);
h = tmp(4);
if (w == 1920 && h == 1200) || (w == 1920 && h == 1080)
    dual = 'single';
elseif h == 1080 || h == 1200 || h == 1050 || h == 2560 || h == 1440
    dual = 'leftRight';
elseif w == 1920 || w == 3440
    dual = 'upDown';
else
    % Unknown geometry — leave MATLAB to interpret normalized coords.
    dual = 'leave';
end
end


function vec = normalized_to_pixels(tmp, position, dual)
dx = tmp(3) - tmp(1);
dy = tmp(4) - tmp(2);
switch dual
    case 'single'
        vec = [dx * position(1), dy * position(2), ...
            dx * position(3), dy * position(4)];
    case 'upDown'
        vec = [dx * position(1), dy * position(2) / 2, ...
            dx * position(3), dy * position(4) / 2];
    case 'leftRight'
        vec = [dx * position(1) / 2, dy * position(2), ...
            dx * position(3) / 2, dy * position(4)];
    otherwise
        error('set_figure_safe:UnknownDual', 'Unknown dual mode: %s', dual);
end
end


function apply_normalized(F, position)
set(F, ...
    'color', 'w', ...
    'units', 'normalized', ...
    'position', position, ...
    'papersize', [10 6.75], ...
    'paperpositionmode', 'auto');
end
