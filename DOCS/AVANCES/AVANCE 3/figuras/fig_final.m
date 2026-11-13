function T = fig_final(Ke)
% FIG_FINAL  Figuras y tabla del escenario final: controlador único (Kp = 20, Ki = 1), Hs = 2 m,
% requisito de 1°. Lee ../resultados/exp2_final.mat (de MODELOS/CINEMATICA/exp2_final.m) y escribe
%   barrido_k.pdf/.png        atenuación y pico contra K (MiL, sensor ideal)
%   pil_nivelacion.pdf/.png   pitch y roll: sin compensar, MiL, PiL ideal y PiL no ideal con K = Ke
%   pil_comando.pdf/.png      comando de una válvula: PiL ideal contra PiL no ideal (efecto del ruido)
%   ../resultados/metricas_final.csv
if nargin < 1, Ke = 15; end
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados');
R = load(fullfile(dres, 'exp2_final.mat')).R; t0 = 2; req = 1;
c = struct2cell(R); c = c(cellfun(@(x) isfield(x, 'res'), c)); r = [c{:}];
ni = arrayfun(@(x) any(x.noideal), r);
base = r(strcmp({r.modo}, 'mil') & [r.K] == 0).res;
mil = r(strcmp({r.modo}, 'mil') & [r.K] == Ke & ~ni).res;
milN = r(strcmp({r.modo}, 'mil') & [r.K] == Ke & ni).res;
pil = r(strcmp({r.modo}, 'pil') & [r.K] == Ke & ~ni).res;
pilN = r(strcmp({r.modo}, 'pil') & [r.K] == Ke & ni).res;
tg = (t0:0.01:min([base.t(end) mil.t(end) pil.t(end) pilN.t(end)]))';

% --- tabla de métricas
casos = {'Sin compensar (K = 0), MiL', base, []; 'MiL', mil, []; 'MiL no ideal', milN, mil; ...
         'PiL ideal', pil, mil; 'PiL no ideal', pilN, milN};
fil = {};
for i = 1:size(casos, 1)
    s = casos{i, 2}; q = casos{i, 3}; d = [NaN NaN NaN NaN];
    if ~isempty(q)
        ep = malla(s, 'pitch_deg', tg) - malla(q, 'pitch_deg', tg); er = malla(s, 'roll_deg', tg) - malla(q, 'roll_deg', tg);
        d = [sqrt(mean(ep.^2)) max(abs(ep)) sqrt(mean(er.^2)) max(abs(er))];
    end
    fil(end+1, :) = {casos{i, 1}, s.pico_pitch, s.rms_pitch, s.pico_roll, s.rms_roll, ...
        20*log10(s.rms_pitch/base.rms_pitch), 20*log10(s.rms_roll/base.rms_roll), max(s.u_rms), d(1), d(2), d(3), d(4)}; %#ok<AGROW>
end
T = cell2table(fil, 'VariableNames', {'caso', 'pico_pitch', 'rms_pitch', 'pico_roll', 'rms_roll', 'aten_pitch_dB', 'aten_roll_dB', ...
    'urms_max', 'rmse_pitch_ref', 'emax_pitch_ref', 'rmse_roll_ref', 'emax_roll_ref'});
writetable(T, fullfile(dres, 'metricas_final.csv')); disp(T);

% --- figura 1: barrido de K (MiL, sensor ideal)
b = r(strcmp({r.modo}, 'mil') & ~ni); [~, i] = sort([b.K]); b = b(i); K = [b.K];
pp = arrayfun(@(x) x.res.pico_pitch, b); pr = arrayfun(@(x) x.res.pico_roll, b);
ap = arrayfun(@(x) 20*log10(x.res.rms_pitch/base.rms_pitch), b); ar = arrayfun(@(x) 20*log10(x.res.rms_roll/base.rms_roll), b);
um = arrayfun(@(x) max(x.res.u_rms), b);
k = K > 0; g = fminsearch(@(g) sum((20*log10(1./(1 + g*K(k))) - ap(k)).^2), 0.2);
Kc = linspace(0, max(K)*1.05, 200); Kmin = (base.pico_pitch/req - 1)/g;
f = figure('Units', 'centimeters', 'Position', [2 2 18 12], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
plot(Kc, 20*log10(1./(1 + g*Kc)), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.9);
plot(K(k), ap(k), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(K(k), ar(k), 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
xline(Ke, 'k--', sprintf('K = %g', Ke), 'FontSize', 7);
ylabel('atenuación del RMS (dB)'); xlim([0 Kc(end)]);
legend({sprintf('modelo 1/(1+%.3f K)', g), 'pitch', 'roll'}, 'Location', 'northeast', 'FontSize', 7);
title(sprintf('Nivelación contra K: K_p = 20, K_i = 1, H_s = 2 m (K mínimo para %g°: %.1f)', req, Kmin), 'FontWeight', 'normal');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
plot(K, pp, 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(K, pr, 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
yline(req, 'r:', sprintf('%g° (requisito)', req), 'FontSize', 7, 'LabelHorizontalAlignment', 'right');
xline(Ke, 'k--'); ylabel('pico de inclinación (°)'); xlabel('K'); xlim([0 Kc(end)]);
yyaxis right; plot(K, um, '^--', 'Color', [0.4 0.4 0.4]); ylabel('u_{RMS} máximo'); ax.YAxis(2).Color = [0.4 0.4 0.4];
legend({'pitch', 'roll', 'requisito', '', 'u_{RMS}'}, 'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 7);
exportgraphics(f, fullfile(here, 'barrido_k.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'barrido_k.png'), 'Resolution', 200);

% --- figura 2: inclinación de la mesa en el tiempo
f = figure('Units', 'centimeters', 'Position', [2 2 18 15], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); ejes = {'pitch', 'roll'}; axs = gobjects(1, 3);
for i = 1:2
    cc = [ejes{i} '_deg']; axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, cc, tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(mil, cc, tg), 'k-', 'LineWidth', 1.3);
    plot(tg, malla(pil, cc, tg), '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.4);
    plot(tg, malla(pilN, cc, tg), '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.8);
    yline([-req req], 'r:'); ylabel([ejes{i} ' de la mesa (°)']);
    if i == 1
        legend({'sin compensar (K = 0)', 'MiL', 'PiL ideal (Arduino)', 'PiL no ideal (Arduino)', sprintf('\\pm%g° (requisito)', req)}, ...
            'Location', 'northeast', 'FontSize', 7, 'NumColumns', 3);
        title(sprintf('Inclinación de la mesa, H_s = 2 m, K_p = 20, K_i = 1, K = %g', Ke), 'FontWeight', 'normal');
    end
end
axs(3) = nexttile(tl); hold on; grid on; box on; axs(3).FontSize = 8;
plot(tg, malla(pilN, 'pitch_deg', tg) - malla(pil, 'pitch_deg', tg), '-', 'Color', [0 0.45 0.74]);
plot(tg, malla(pilN, 'roll_deg', tg) - malla(pil, 'roll_deg', tg), '-', 'Color', [0.85 0.33 0.10]);
plot(tg, malla(pil, 'pitch_deg', tg) - malla(mil, 'pitch_deg', tg), 'k-', 'LineWidth', 1.2);
ylabel('diferencia (°)'); xlabel('t (s)');
legend({'pitch: PiL no ideal - PiL ideal', 'roll: PiL no ideal - PiL ideal', 'pitch: PiL ideal - MiL'}, 'Location', 'northeast', 'FontSize', 7, 'NumColumns', 3);
linkaxes(axs, 'x'); xlim(axs(1), [tg(1) tg(end)]);
exportgraphics(f, fullfile(here, 'pil_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_nivelacion.png'), 'Resolution', 200);

% --- figura 3: comando de la válvula 1 (donde se ve el ruido del sensor)
f = figure('Units', 'centimeters', 'Position', [2 2 18 8], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl, [1 2]); hold on; grid on; box on; ax.FontSize = 8;
stairs(pilN.t_u, pilN.u(:, 1), '-', 'Color', [0 0.45 0.74]); stairs(pil.t_u, pil.u(:, 1), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.3);
xlim([t0 tg(end)]); ylabel('comando de la válvula 1, u'); xlabel('t (s)');
legend({'PiL no ideal', 'PiL ideal'}, 'Location', 'northeast', 'FontSize', 7);
title('Comando calculado por el Arduino', 'FontWeight', 'normal');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8; w = [14 16];
stairs(pilN.t_u, pilN.u(:, 1), '-', 'Color', [0 0.45 0.74]); stairs(pil.t_u, pil.u(:, 1), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.3);
xlim(w); xlabel('t (s)'); title('detalle', 'FontWeight', 'normal');
exportgraphics(f, fullfile(here, 'pil_comando.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_comando.png'), 'Resolution', 200);
fprintf('g = %.3f, K mínimo para %g° = %.1f. Figuras en %s\n', g, req, Kmin, here);
end

function y = malla(s, campo, tg)
% Señal interpolada en la malla común (el solver de la planta es de paso variable).
[tt, iu] = unique(s.t); y = interp1(tt, s.(campo)(iu), tg);
end
