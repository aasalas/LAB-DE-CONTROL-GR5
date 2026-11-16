function T = fig_final()
% FIG_FINAL  Figuras y tabla del escenario final con el controlador final: cinemática corregida
% (g = 1), prealimentación de la inclinación de la base (Kff = 1) y realimentación con K = 3
% (Kp = 20, Ki = 1), Hs = 2 m, Tp = 10 s, requisito de 1°. Lee de ../resultados/
%   exp4_k_ik.mat             barrido de K con g = 1 (sin prealimentación) y el caso sin compensar
%   exp5_prealimentacion.mat  MiL con solo realimentación (Tp10_ff0) y con prealimentación (Tp10_ff1)
%   exp6_ff_Tp10.mat          MiL no ideal, PiL ideal y PiL no ideal con prealimentación
% y escribe
%   barrido_k.pdf/.png        atenuación y pico contra K (MiL, g = 1, solo realimentación)
%   pil_nivelacion.pdf/.png   pitch y roll de la mesa: sin compensar, solo realimentación y final
%   pil_comando.pdf/.png      comando de una válvula: PiL ideal contra PiL no ideal
%   ../resultados/metricas_final.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2; req = 1;
R4 = load(fullfile(dres, 'exp4_k_ik.mat')).R;
R5 = load(fullfile(dres, 'exp5_prealimentacion.mat')).R;
R6 = load(fullfile(dres, 'exp6_ff_Tp10.mat')).R;
base = R4.mil_K0.res; fb = R5.Tp10_ff0; mil = R5.Tp10_ff1;
milN = R6.mil_K3_ff_noideal.res; pil = R6.pil_K3_ff.res; pilN = R6.pil_K3_ff_noideal.res;
tg = (t0:0.01:min([base.t(end) mil.t(end) pil.t(end) pilN.t(end)]))';

% --- tabla de métricas (diferencias contra la referencia indicada)
casos = {'Sin compensar (K = 0)', base, []; 'Solo realimentación, K = 3 (MiL)', fb, []; ...
         'Final, MiL', mil, []; 'Final, MiL no ideal', milN, mil; ...
         'Final, PiL ideal', pil, mil; 'Final, PiL no ideal', pilN, pil};
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

% --- figura 1: barrido de K (MiL, g = 1, solo realimentación)
c = struct2cell(R4); b = [c{:}]; [~, i] = sort([b.K]); b = b(i); K = [b.K]; est = [b.estable] & K < 6;
pp = arrayfun(@(x) x.res.pico_pitch, b); pr = arrayfun(@(x) x.res.pico_roll, b);
ap = arrayfun(@(x) 20*log10(x.res.rms_pitch/base.rms_pitch), b); ar = arrayfun(@(x) 20*log10(x.res.rms_roll/base.rms_roll), b);
k = K > 0 & est; g = fminsearch(@(g) sum((20*log10(1./(1 + g*K(k))) - ap(k)).^2), 1);
Kc = linspace(0, 6, 200);
f = figure('Units', 'centimeters', 'Position', [2 2 18 11], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
plot(Kc, 20*log10(1./(1 + g*Kc)), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.9);
plot(K(est), ap(est), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(K(est), ar(est), 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
xline(3, 'k--', 'K = 3', 'FontSize', 7); xline(6, 'r:', 'inestable', 'FontSize', 7);
ylabel('atenuación del RMS (dB)'); xlim([0 6.5]);
legend({sprintf('modelo 1/(1+%.2f K)', g), 'pitch', 'roll'}, 'Location', 'northeast', 'FontSize', 7);
title('Solo realimentación contra K (MiL, g = 1, K_p = 20, K_i = 1, H_s = 2 m)', 'FontWeight', 'normal');
ax = nexttile(tl); hold on; grid on; box on; ax.FontSize = 8;
plot(K(est), pp(est), 'o-', 'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74], 'LineWidth', 1.2);
plot(K(est), pr(est), 's-', 'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10], 'LineWidth', 1.2);
plot(K(~est & K <= 6.5), pp(~est & K <= 6.5), 'x', 'Color', [0.85 0.1 0.1], 'MarkerSize', 9, 'LineWidth', 1.8);
yline(req, 'r:', sprintf('%g° (requisito)', req), 'FontSize', 7, 'LabelHorizontalAlignment', 'left');
xline(3, 'k--'); ylabel('pico de inclinación (°)'); xlabel('K'); xlim([0 6.5]); ylim([0 3.2]);
text(6.1, 2.6, sprintf('K = 6: %.0f°', pp(K == 6)), 'Color', [0.85 0.1 0.1], 'FontSize', 7, 'HorizontalAlignment', 'right');
legend({'pitch', 'roll', 'inestable'}, 'Location', 'northeast', 'FontSize', 7);
exportgraphics(f, fullfile(here, 'barrido_k.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'barrido_k.png'), 'Resolution', 200);

% --- figura 2: inclinación de la mesa en el tiempo
f = figure('Units', 'centimeters', 'Position', [2 2 18 15], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); ejes = {'pitch', 'roll'}; axs = gobjects(1, 3);
for i = 1:2
    cc = [ejes{i} '_deg']; axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, cc, tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(fb, cc, tg), '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0, 'LineStyle', '--');
    plot(tg, malla(mil, cc, tg), 'k-', 'LineWidth', 1.4);
    plot(tg, malla(pil, cc, tg), '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.3);
    plot(tg, malla(pilN, cc, tg), '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.8);
    yline([-req req], 'r:'); ylabel([ejes{i} ' de la mesa (°)']);
    if i == 1
        legend({'sin compensar', 'solo realimentación (K = 3)', 'final: MiL', 'final: PiL ideal', 'final: PiL no ideal', ...
            sprintf('\\pm%g°', req)}, 'Location', 'northeast', 'FontSize', 7, 'NumColumns', 3);
        title('Inclinación de la mesa, H_s = 2 m, T_p = 10 s: prealimentación + K = 3 (K_p = 20, K_i = 1)', 'FontWeight', 'normal');
    end
end
axs(3) = nexttile(tl); hold on; grid on; box on; axs(3).FontSize = 8;
plot(tg, malla(mil, 'pitch_deg', tg), 'k-', 'LineWidth', 1.2);
plot(tg, malla(pilN, 'pitch_deg', tg), '-', 'Color', [0 0.45 0.74]);
plot(tg, malla(pilN, 'roll_deg', tg), '-', 'Color', [0.85 0.33 0.10]);
ylabel('detalle (°)'); xlabel('t (s)');
legend({'pitch: final MiL', 'pitch: final PiL no ideal', 'roll: final PiL no ideal'}, 'Location', 'northeast', 'FontSize', 7, 'NumColumns', 3);
linkaxes(axs, 'x'); xlim(axs(1), [tg(1) tg(end)]);
exportgraphics(f, fullfile(here, 'pil_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_nivelacion.png'), 'Resolution', 200);

% --- figura 3: comando de la válvula 1 (donde se ve el ruido del encoder)
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
d = double(pilN.u) - double(pil.u); iu = pil.t_u >= t0;
fprintf('g ajustado = %.3f. Ruido en u: RMS %s, máx %s\n', g, mat2str(sqrt(mean(d(iu,:).^2)), 3), mat2str(max(abs(d(iu,:))), 3));
end

function y = malla(s, campo, tg)
% Señal interpolada en la malla común (el solver de la planta es de paso variable).
[tt, iu] = unique(s.t); y = interp1(tt, s.(campo)(iu), tg);
end
