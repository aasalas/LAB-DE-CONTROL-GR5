%% FIGURAS_DISENO_PI  Figuras del experimento de diseño del PI (lee resultados/diseno_pi.mat).
here = fileparts(mfilename('fullpath'));
D = load(fullfile(here, 'resultados', 'diseno_pi.mat')); T = D.T; S = D.S;
figd = fullfile(here, 'figuras'); if ~isfolder(figd), mkdir(figd); end
ele = D.elegido; ref = ["A" "U"];                        % los que estaban en uso, como referencia
col = struct('A', [0.85 0.33 0.10], 'U', [0.49 0.18 0.56], 'E', [0 0.45 0.74]);

% Figura 1: escalón de 10 mm en el modelo no lineal, todos los candidatos
f = figure('Units', 'centimeters', 'Position', [2 2 18 13], 'Visible', 'off'); theme(f, 'light');
ax1 = subplot(3, 1, [1 2]); hold on; grid on; ax2 = subplot(3, 1, 3); hold on; grid on;
h = gobjects(0); nom = strings(0);
for i = 1:height(T)
    id = T.id(i); if any(id == [ref ele]) || ~isfield(S.(id), 'peq') || isempty(S.(id).peq), continue; end
    L = S.(id).peq; plot(ax1, L(:,1) - 1.5, (L(:,3) - 0.23)*1e3, '-', 'Color', [0.75 0.75 0.75]);
end
h(end+1) = plot(ax1, NaN, NaN, '-', 'Color', [0.75 0.75 0.75]); nom(end+1) = "otros candidatos";
for id = ref
    L = S.(id).peq; k = T(T.id == id, :);
    h(end+1) = plot(ax1, L(:,1) - 1.5, (L(:,3) - 0.23)*1e3, '-', 'Color', col.(id), 'LineWidth', 1.3); %#ok<SAGROW>
    nom(end+1) = sprintf('%s: Kp = %.3g, Ki = %.3g', id, k.Kp, k.Ki); %#ok<SAGROW>
    stairs(ax2, L(:,1) - 1.5, L(:,4), '-', 'Color', col.(id));
end
if ele ~= ""
    L = S.(ele).peq; k = T(T.id == ele, :);
    h(end+1) = plot(ax1, L(:,1) - 1.5, (L(:,3) - 0.23)*1e3, '-', 'Color', col.E, 'LineWidth', 2);
    nom(end+1) = sprintf('elegido %s: Kp = %.3g, Ki = %.3g', ele, k.Kp, k.Ki);
    stairs(ax2, L(:,1) - 1.5, L(:,4), '-', 'Color', col.E, 'LineWidth', 1.3);
    Ll = S.(ele).lin;
    h(end+1) = plot(ax1, Ll(:,1), Ll(:,2)*10, 'k--', 'LineWidth', 1); nom(end+1) = "elegido, modelo lineal G(z)";
end
yline(ax1, 10, ':'); yline(ax1, [9.8 10.2], ':', 'Color', [0.5 0.5 0.5]);
xlim(ax1, [-0.1 3]); ylim(ax1, [-0.5 13]); ylabel(ax1, 'x - x_0 (mm)');
title(ax1, 'Escalón de 10 mm en x_0 = 0.23 m, modelo no lineal');
legend(ax1, h, nom, 'Location', 'southeast', 'FontSize', 8);
xlim(ax2, [-0.1 3]); ylabel(ax2, 'u'); xlabel(ax2, 't (s)');
exportgraphics(f, fullfile(figd, 'diseno_pi_escalon.png'), 'Resolution', 200);
exportgraphics(f, fullfile(figd, 'diseno_pi_escalon.pdf'), 'ContentType', 'vector');

% Figura 2: escalón de 0 a 0.40 m (validación unitaria), en uso contra elegido
f = figure('Units', 'centimeters', 'Position', [2 2 18 11], 'Visible', 'off'); theme(f, 'light');
ax1 = subplot(3, 1, [1 2]); hold on; grid on; ax2 = subplot(3, 1, 3); hold on; grid on;
h = gobjects(0); nom = strings(0); ids = ref; if ele ~= "" && ~any(ele == ref), ids = [ref ele]; end
for id = ids
    L = S.(id).gra; k = T(T.id == id, :); c = col.E; if isfield(col, id), c = col.(id); end
    h(end+1) = plot(ax1, L(:,1), L(:,3)*1e3, '-', 'Color', c, 'LineWidth', 1.4); %#ok<SAGROW>
    nom(end+1) = sprintf('%s: Kp = %.3g, Ki = %.3g (Mp %.1f %%, t_s %.2f s)', id, k.Kp, k.Ki, k.Mp_400mm, k.ts_400mm); %#ok<SAGROW>
    stairs(ax2, L(:,1), L(:,4), '-', 'Color', c);
end
L = S.(ids(1)).gra; plot(ax1, L(:,1), L(:,2)*1e3, 'k:');
ylabel(ax1, 'x (mm)'); ylim(ax1, [-20 460]); xlim(ax1, [0 4]); xlim(ax2, [0 4]);
title(ax1, 'Escalón de 0 a 0.40 m, modelo no lineal'); legend(ax1, h, nom, 'Location', 'southeast', 'FontSize', 8);
ylabel(ax2, 'u'); xlabel(ax2, 't (s)');
exportgraphics(f, fullfile(figd, 'diseno_pi_escalon_grande.png'), 'Resolution', 200);
exportgraphics(f, fullfile(figd, 'diseno_pi_escalon_grande.pdf'), 'ContentType', 'vector');
fprintf('Figuras en %s\n', figd);
