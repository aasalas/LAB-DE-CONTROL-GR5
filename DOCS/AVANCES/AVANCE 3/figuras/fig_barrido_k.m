function T = fig_barrido_k(Ke)
% FIG_BARRIDO_K  Figuras y tabla de la etapa 3: barrido de K con el controlador B y su PiL.
%   fig_barrido_k        usa K elegido = 15
%   fig_barrido_k(Ke)    otro K elegido (debe existir en MiL y en PiL)
% Lee ../resultados/exp1_etapa3_mil.mat y exp1_etapa3_pil.mat (de exp1_etapa3 y exp1_etapa3_pil)
% y escribe barrido_k.pdf/.png, pil_nivelacion.pdf/.png y ../resultados/metricas_etapa3.csv.
if nargin < 1, Ke = 15; end
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados');
Rm = load(fullfile(dres, 'exp1_etapa3_mil.mat')).R; Rp = load(fullfile(dres, 'exp1_etapa3_pil.mat')).R;
t0 = 2; umbral = -12;                                    % arranque ignorado [s] y criterio [dB]
m = ordenar(Rm); p = ordenar(Rp); base = m([m.K] == 0).res;
at = @(r, c) 20*log10(r.(['rms_' c])/base.(['rms_' c]));

% --- tabla: MiL y PiL de cada K, y diferencia PiL - MiL sobre una malla común
fil = {};
for r = [m p]
    s = r.res; d = [NaN NaN NaN NaN];
    if strcmp(r.modo, 'pil')
        q = m([m.K] == r.K).res; tg = (t0:0.01:min(s.t(end), q.t(end)))';
        ep = malla(s, 'pitch_deg', tg) - malla(q, 'pitch_deg', tg); er = malla(s, 'roll_deg', tg) - malla(q, 'roll_deg', tg);
        d = [sqrt(mean(ep.^2)) max(abs(ep)) sqrt(mean(er.^2)) max(abs(er))];
    end
    fil(end+1, :) = {upper(r.modo), r.K, r.estable, s.pico_pitch, s.rms_pitch, s.pico_roll, s.rms_roll, at(s, 'pitch'), at(s, 'roll'), ...
        max(s.u_rms), max(s.sat_pct), d(1), d(2), d(3), d(4)}; %#ok<AGROW>
end
T = cell2table(fil, 'VariableNames', {'modo', 'K', 'estable', 'pico_pitch', 'rms_pitch', 'pico_roll', 'rms_roll', 'aten_pitch_dB', 'aten_roll_dB', ...
    'urms_max', 'sat_pct_max', 'rmse_pitch_vs_MiL', 'emax_pitch_vs_MiL', 'rmse_roll_vs_MiL', 'emax_roll_vs_MiL'});
T.estable = T.estable & T.pico_pitch <= base.pico_pitch*1.001;    % peor que sin compensar: inestable
writetable(T, fullfile(dres, 'metricas_etapa3.csv')); disp(T);

% --- figura 1: atenuación contra K
Tm = T(strcmp(T.modo, 'MIL') & T.K > 0, :); es = Tm.estable; Tp = T(strcmp(T.modo, 'PIL') & T.K > 0, :);
g = fminsearch(@(g) sum((20*log10(1./(1 + g*Tm.K(es))) - Tm.aten_pitch_dB(es)).^2), 0.2);   % ganancia efectiva del lazo
Kc = linspace(0, max(Tm.K)*1.05, 200);
f = figure('Units', 'centimeters', 'Position', [2 2 18 12], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
plot(Kc, 20*log10(1./(1 + Kc)), 'k--', 'LineWidth', 0.9);
plot(Kc, 20*log10(1./(1 + g*Kc)), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.9);
plot(Tm.K(es), Tm.aten_pitch_dB(es), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(Tm.K(es), Tm.aten_roll_dB(es), 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
plot(Tp.K, Tp.aten_pitch_dB, 'kd', 'MarkerSize', 9, 'LineWidth', 1.1);
yline(umbral, 'r:', sprintf('criterio: %d dB', umbral), 'FontSize', 7, 'LabelHorizontalAlignment', 'left');
le = {'modelo ideal 1/(1+K)', sprintf('ajuste 1/(1+%.2f K)', g), 'pitch, MiL', 'roll, MiL', 'pitch, PiL (Arduino)', 'criterio'};
if any(~es), xline(Tm.K(~es), '-', 'inestable', 'Color', [0.8 0 0], 'FontSize', 7, 'LabelVerticalAlignment', 'bottom'); le{end+1} = 'inestable'; end
ylim([-32 2]); xlim([0 Kc(end)]); ylabel('atenuación del RMS (dB)'); legend(le, 'Location', 'southwest', 'FontSize', 7);
title('Nivelación contra la ganancia K (controlador B: K_p = 20, K_i = 1)', 'FontWeight', 'normal');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
Ta = T(strcmp(T.modo, 'MIL') & T.estable, :);
plot(Ta.K, Ta.pico_pitch, 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(Ta.K, Ta.pico_roll, 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
yline(0.2, 'r:', '0.2° (requisito)', 'FontSize', 7, 'LabelHorizontalAlignment', 'right');
ylabel('pico de inclinación (°)'); xlabel('K'); xlim([0 Kc(end)]);
yyaxis right; plot(Ta.K, Ta.urms_max, '^--', 'Color', [0.4 0.4 0.4]); ylabel('u_{RMS} máximo'); ax.YAxis(2).Color = [0.4 0.4 0.4];
if any(~es), xline(Tm.K(~es), '-', 'Color', [0.8 0 0]); end
legend({'pitch', 'roll', 'requisito', 'u_{RMS}'}, 'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 7);
exportgraphics(f, fullfile(here, 'barrido_k.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'barrido_k.png'), 'Resolution', 200);

% --- figura 2: PiL contra MiL en el tiempo, con el K elegido
sm = m([m.K] == Ke).res; sp = p([p.K] == Ke).res; tg = (t0:0.01:min([sm.t(end) sp.t(end) base.t(end)]))';
f = figure('Units', 'centimeters', 'Position', [2 2 18 14], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); ejes = {'pitch', 'roll'}; axs = gobjects(1, 3);
for i = 1:2
    c = [ejes{i} '_deg']; axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, c, tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(sm, c, tg), 'k-', 'LineWidth', 1.2);
    plot(tg, malla(sp, c, tg), '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.4);
    yline([-0.2 0.2], 'r:'); ylabel([ejes{i} ' de la mesa (°)']);
    if i == 1
        legend({'sin compensar (K = 0)', sprintf('MiL, K = %g', Ke), sprintf('PiL en el Arduino, K = %g', Ke), '\pm0.2° (requisito)'}, ...
            'Location', 'northeast', 'FontSize', 7, 'NumColumns', 2);
        title(sprintf('Inclinación de la mesa, H_s = 0.5 m, K_p = 20, K_i = 1, K = %g', Ke), 'FontWeight', 'normal');
    end
end
axs(3) = nexttile(tl); hold on; grid on; box on; axs(3).FontSize = 8;
plot(tg, malla(sp, 'pitch_deg', tg) - malla(sm, 'pitch_deg', tg), '-', 'Color', [0 0.45 0.74]);
plot(tg, malla(sp, 'roll_deg', tg) - malla(sm, 'roll_deg', tg), '-', 'Color', [0.85 0.33 0.10]);
ylabel('PiL - MiL (°)'); xlabel('t (s)'); legend({'pitch', 'roll'}, 'Location', 'northeast', 'FontSize', 7);
linkaxes(axs, 'x'); xlim(axs(1), [tg(1) tg(end)]);
exportgraphics(f, fullfile(here, 'pil_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_nivelacion.png'), 'Resolution', 200);
fprintf('Ganancia efectiva del lazo: g = %.3f. Figuras en %s\n', g, here);
end

function r = ordenar(R)
% Corridas con resultado, ordenadas por K.
c = struct2cell(R); c = c(cellfun(@(x) isfield(x, 'res'), c)); r = [c{:}]; [~, i] = sort([r.K]); r = r(i);
end

function y = malla(s, campo, tg)
% Señal interpolada en la malla común (el solver de la planta es de paso variable).
[tt, iu] = unique(s.t); y = interp1(tt, s.(campo)(iu), tg);
end
