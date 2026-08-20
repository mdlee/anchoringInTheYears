function print_figure(outDir, stem, printFigures)
%PRINT_FIGURE Write PNG and EPS under outDir/png and outDir/eps.
if nargin < 3 || ~printFigures
    return;
end

pngDir = fullfile(outDir, 'png');
epsDir = fullfile(outDir, 'eps');
if ~isfolder(pngDir)
    mkdir(pngDir);
end
if ~isfolder(epsDir)
    mkdir(epsDir);
end

print(gcf, fullfile(pngDir, [stem '.png']), '-dpng', '-r200');
% Prefer OpenGL so FaceAlpha CI patches survive in EPS (painters drops them)
try
    print(gcf, fullfile(epsDir, [stem '.eps']), '-depsc', '-opengl');
catch
    print(gcf, fullfile(epsDir, [stem '.eps']), '-depsc');
end
fprintf('Wrote %s/{png,eps}/%s\n', outDir, stem);
end
