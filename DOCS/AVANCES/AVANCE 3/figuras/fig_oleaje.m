function T = fig_oleaje()
% FIG_OLEAJE  Atenuación ante ángulos grandes: olas lentas (Tp = 12 s) con Hs = 5.06, 10.20 y 15.49 m,
% que inclinan la base 5°, 10° y 15°. Controlador final: prealimentación (Kff = 1) + K = 3, ±30°,
% g = 1, Kp = 20, Ki = 1. Lee ../resultados/exp8_grande_{05,10,15}.mat (de exp8_angulos_grandes.m) y escribe
% oleaje_casos.pdf/.png y ../resultados/metricas_oleaje.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2; req = 1;
grados = [5 10 15]; Hs = [5.06 10.20 15.49];
f = figure('Units', 'centimeters', 'Position', [2 2 18 16], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); axs = gobjects(1, 3);
fil = {};
for i = 1:3
    R = load(fullfile(dres, sprintf('exp8_grande_%02d.mat', grados(i)))).R;
    base = R.mil_sin.res; ff = R.mil_final.res;
    if isfield(R.pil_final_noideal, 'res'), pilN = R.pil_final_noideal.res; else, pilN = []; end
    tg = (t0:0.01:min([base.t(end) ff.t(end)]))';
    axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(ff, tg), 'k-', 'LineWidth', 1.4);
    if ~isempty(pilN)
        plot(tg, malla(pilN, tg), '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.9);
        txt = sprintf('PiL no ideal %.2f°', pilN.pico_pitch);
    else
        plot(nan, nan, '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.9); txt = 'PiL no ideal: interrumpida';
    end
    yline([-req req], 'r:'); ylabel('pitch de la mesa (°)');
    title(sprintf('H_s = %.2f m, T_p = 12 s: base %.1f°, mesa MiL %.2f° (%s)', ...
        Hs(i), base.pico_pitch, ff.pico_pitch, txt), 'FontWeight', 'normal');
    if i == 1
        legend({'sin compensar', 'final: MiL', 'final: PiL no ideal', sprintf('\\pm%g°', req)}, ...
            'Location', 'northeast', 'FontSize', 7, 'NumColumns', 4);
    end
    corr = {base, ff, pilN}; nm = {'sin compensar', 'final, MiL', 'final, PiL no ideal'};
    for k = 1:3
        r = corr{k};
        if isempty(r), fil(end+1, :) = {grados(i), Hs(i), nm{k}, NaN, NaN, NaN, NaN, NaN, NaN, NaN}; continue; end %#ok<AGROW>
        fil(end+1, :) = {grados(i), Hs(i), nm{k}, r.pico_pitch, r.rms_pitch, r.pico_roll, r.rms_roll, ...
            20*log10(r.rms_pitch/base.rms_pitch), max(r.u_rms), max(r.sat_pct)}; %#ok<AGROW>
    end
end
xlabel(axs(3), 't (s)'); linkaxes(axs, 'x'); xlim(axs(1), [t0 30]);
exportgraphics(f, fullfile(here, 'oleaje_casos.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'oleaje_casos.png'), 'Resolution', 200);
T = cell2table(fil, 'VariableNames', {'base_deg', 'Hs', 'caso', 'pico_pitch', 'rms_pitch', 'pico_roll', 'rms_roll', ...
    'aten_pitch_dB', 'urms_max', 'sat_pct_max'});
writetable(T, fullfile(dres, 'metricas_oleaje.csv')); disp(T);
end

function y = malla(s, tg)
[tt, iu] = unique(s.t); y = interp1(tt, s.pitch_deg(iu), tg);
end
