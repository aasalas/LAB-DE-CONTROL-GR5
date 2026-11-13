function T = fig_resultados
% FIG_RESULTADOS  Figura y tabla de resultados del informe del Avance 3.
% Lee ../resultados/tres_casos.mat (generado con correr_pil3 para MiL, PiL ideal y PiL no ideal)
% y escribe resultados_nivelacion.pdf/.png junto a este archivo, además de ../resultados/metricas.csv.
here = fileparts(mfilename('fullpath'));
S = load(fullfile(here, '..', 'resultados', 'tres_casos.mat')); R = S.R;
nom = {'base', 'mil', 'ideal', 'noideal'}; et = {'Sin compensar (K = 0)', 'MiL', 'PiL ideal', 'PiL no ideal'};
col = [0.65 0.65 0.65; 0 0 0; 0.85 0.33 0.10; 0.00 0.45 0.74]; est = {'-', '-', '--', '-'}; lw = [1.0 1.2 1.4 0.9];
hay = cellfun(@(c) isfield(R, c), nom);                  % la línea base (K = 0) es opcional
nom = nom(hay); et = et(hay); col = col(hay, :); est = est(hay); lw = lw(hay);
t0 = 2;                                                  % se ignora el arranque de los pistones
tg = (t0:0.01:min(cellfun(@(c) R.(c).t(end), nom)))';    % malla común (el solver es de paso variable)
for i = 1:numel(nom)
    r = R.(nom{i}); [tt, iu] = unique(r.t);
    Y.(nom{i}).roll  = interp1(tt, r.roll_deg(iu),  tg);
    Y.(nom{i}).pitch = interp1(tt, r.pitch_deg(iu), tg);
end

% --- métricas: pico, RMS y diferencia respecto al MiL
fila = @(c, e) [max(abs(Y.(c).pitch)), sqrt(mean(Y.(c).pitch.^2)), max(abs(Y.(c).roll)), sqrt(mean(Y.(c).roll.^2)), ...
    sqrt(mean((Y.(c).pitch - Y.mil.pitch).^2)), sqrt(mean((Y.(c).roll - Y.mil.roll).^2)), ...
    max(abs(Y.(c).pitch - Y.mil.pitch)), max(abs(Y.(c).roll - Y.mil.roll))]; %#ok<INUSD>
M = zeros(numel(nom), 8); for i = 1:numel(nom), M(i, :) = fila(nom{i}); end
T = array2table(M, 'RowNames', et, 'VariableNames', {'pico_pitch','rms_pitch','pico_roll','rms_roll', ...
    'rmse_pitch_vs_MiL','rmse_roll_vs_MiL','emax_pitch_vs_MiL','emax_roll_vs_MiL'});
writetable(T, fullfile(here, '..', 'resultados', 'metricas.csv'), 'WriteRowNames', true);
disp(T);

% --- figura: inclinación de la mesa en el tiempo y diferencia respecto al MiL
f = figure('Units', 'centimeters', 'Position', [2 2 18 11], 'Color', 'w'); theme(f, 'light');
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl); hold on; grid on; box on;
for i = 1:numel(nom), plot(tg, Y.(nom{i}).pitch, est{i}, 'Color', col(i,:), 'LineWidth', lw(i)); end
yline([-0.2 0.2], 'r:', '\pm0.2° (requisito)', 'LabelHorizontalAlignment', 'left', 'FontSize', 7);
ylabel('pitch de la mesa (°)'); legend(et, 'Location', 'northeast', 'FontSize', 7);
title('Inclinación de la mesa, H_s = 0.5 m, K = 20', 'FontWeight', 'normal'); ax1.FontSize = 8;
ax2 = nexttile(tl); hold on; grid on; box on;
plot(tg, Y.ideal.pitch   - Y.mil.pitch, '--', 'Color', col(strcmp(nom,'ideal'),:), 'LineWidth', 1.2);
plot(tg, Y.noideal.pitch - Y.mil.pitch, '-',  'Color', col(strcmp(nom,'noideal'),:), 'LineWidth', 0.9);
ylabel('diferencia con el MiL (°)'); xlabel('t (s)');
legend({'PiL ideal - MiL', 'PiL no ideal - MiL'}, 'Location', 'northeast', 'FontSize', 7); ax2.FontSize = 8;
linkaxes([ax1 ax2], 'x');
exportgraphics(f, fullfile(here, 'resultados_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'resultados_nivelacion.png'), 'Resolution', 200);
end
