function T = fig_oleaje()
% FIG_OLEAJE  Figura y tabla de los tres estados de mar de exp3_oleaje (Hs = 2 m; Tp = 7.5, 5.3
% y 4.3 s: perturbación pico de ~5°, ~10° y ~15°). Controlador único Kp = 20, Ki = 1, K = 15.
% Lee ../resultados/exp3_oleaje_{05,10,15}.mat y escribe
%   oleaje_casos.pdf/.png             pitch de la mesa: sin compensar, MiL y PiL no ideal, por caso
%   ../resultados/metricas_oleaje.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados');
arch = {'exp3_oleaje_05', 'exp3_oleaje_10', 'exp3_oleaje_15'}; t0 = 2; req = 1;
f = figure('Units', 'centimeters', 'Position', [2 2 18 16], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); axs = gobjects(1, 3);
fil = {};
for i = 1:3
    R = load(fullfile(dres, [arch{i} '.mat'])).R;
    base = R.mil_K0.res; mil = R.mil_K15.res; pilN = R.pil_K15_noideal.res;
    tg = (t0:0.01:min([base.t(end) mil.t(end) pilN.t(end)]))';
    axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, 'pitch_deg', tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(mil, 'pitch_deg', tg), 'k-', 'LineWidth', 1.3);
    plot(tg, malla(pilN, 'pitch_deg', tg), '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.8);
    yline([-req req], 'r:');
    ylabel('pitch de la mesa (°)');
    title(sprintf('H_s = 2 m, T_p = %.1f s: sin compensar %.1f°, con K = 15 %.2f° (pico)', ...
        base.Tp, base.pico_pitch, mil.pico_pitch), 'FontWeight', 'normal');
    if i == 1
        legend({'sin compensar (K = 0)', 'MiL, K = 15', 'PiL no ideal (Arduino), K = 15', sprintf('\\pm%g° (requisito)', req)}, ...
            'Location', 'northeast', 'FontSize', 7, 'NumColumns', 2);
    end
    corr = {base, mil, pilN}; nm = {'sin compensar', 'MiL K = 15', 'PiL no ideal K = 15'};
    for k = 1:3
        r = corr{k};
        fil(end+1, :) = {base.Tp, nm{k}, r.pico_pitch, r.rms_pitch, r.pico_roll, r.rms_roll, ...
            20*log10(r.rms_pitch/base.rms_pitch), max(r.u_rms), max(r.sat_pct)}; %#ok<AGROW>
    end
end
xlabel(axs(3), 't (s)'); linkaxes(axs, 'x'); xlim(axs(1), [t0 30]);
exportgraphics(f, fullfile(here, 'oleaje_casos.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'oleaje_casos.png'), 'Resolution', 200);
T = cell2table(fil, 'VariableNames', {'Tp', 'caso', 'pico_pitch', 'rms_pitch', 'pico_roll', 'rms_roll', ...
    'aten_pitch_dB', 'urms_max', 'sat_pct_max'});
writetable(T, fullfile(dres, 'metricas_oleaje.csv')); disp(T);
end

function y = malla(s, campo, tg)
[tt, iu] = unique(s.t); y = interp1(tt, s.(campo)(iu), tg);
end
