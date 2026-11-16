function T = fig_oleaje()
% FIG_OLEAJE  Figura y tabla de los estados de mar agresivos (Hs = 2 m; Tp = 7.5, 5.3 y 4.3 s:
% base de ~5°, ~10° y ~15°) con g = 1, Kp = 20, Ki = 1 y K = 3. Lee de ../resultados/
%   exp3_oleaje_{05,10,15}.mat   sin compensar (K = 0; no depende de la cinemática)
%   exp5_prealimentacion.mat     MiL con solo realimentación y con prealimentación
%   exp6_ff_Tp{7p5,5p3,4p3}.mat  PiL no ideal con prealimentación
% y escribe oleaje_casos.pdf/.png y ../resultados/metricas_oleaje.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2; req = 1;
R5 = load(fullfile(dres, 'exp5_prealimentacion.mat')).R;
Tps = [7.5 5.3 4.3]; a3 = {'exp3_oleaje_05', 'exp3_oleaje_10', 'exp3_oleaje_15'};
f = figure('Units', 'centimeters', 'Position', [2 2 18 16], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact'); axs = gobjects(1, 3);
fil = {};
for i = 1:3
    Tp = Tps(i); s = strrep(sprintf('%g', Tp), '.', 'p');
    base = load(fullfile(dres, [a3{i} '.mat'])).R.mil_K0.res;
    fb = R5.(matlab.lang.makeValidName(sprintf('Tp%g_ff0', Tp)));
    ff = R5.(matlab.lang.makeValidName(sprintf('Tp%g_ff1', Tp)));
    rp = load(fullfile(dres, ['exp6_ff_Tp' s '.mat'])).R.pil_K3_ff_noideal;
    if isfield(rp, 'res'), pilN = rp.res; else, pilN = []; end   % la simulación puede interrumpirse
    tg = (t0:0.01:min([base.t(end) fb.t(end) ff.t(end)]))';
    axs(i) = nexttile(tl); hold on; grid on; box on; axs(i).FontSize = 8;
    plot(tg, malla(base, tg), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
    plot(tg, malla(fb, tg), '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.0);
    plot(tg, malla(ff, tg), 'k-', 'LineWidth', 1.4);
    if ~isempty(pilN)
        plot(tg, malla(pilN, tg), '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.9);
        txt = sprintf('PiL no ideal %.2f°', pilN.pico_pitch);
    else
        plot(nan, nan, '-', 'Color', [0 0.45 0.74], 'LineWidth', 0.9);
        txt = 'PiL no ideal: simulación interrumpida';
    end
    yline([-req req], 'r:'); ylabel('pitch de la mesa (°)');
    title(sprintf(['T_p = %.1f s: sin compensar %.1f°, solo realimentación %.1f°, ' ...
        'final MiL %.2f° (%s)'], Tp, base.pico_pitch, fb.pico_pitch, ff.pico_pitch, txt), 'FontWeight', 'normal');
    if i == 1
        legend({'sin compensar', 'solo realimentación (K = 3)', 'final: MiL', 'final: PiL no ideal', sprintf('\\pm%g°', req)}, ...
            'Location', 'northeast', 'FontSize', 7, 'NumColumns', 3);
    end
    corr = {base, fb, ff, pilN}; nm = {'sin compensar', 'solo realimentación, MiL', 'final, MiL', 'final, PiL no ideal'};
    for k = 1:4
        r = corr{k};
        if isempty(r), fil(end+1, :) = {Tp, nm{k}, NaN, NaN, NaN, NaN, NaN, NaN, NaN}; continue; end %#ok<AGROW>
        fil(end+1, :) = {Tp, nm{k}, r.pico_pitch, r.rms_pitch, r.pico_roll, r.rms_roll, ...
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

function y = malla(s, tg)
[tt, iu] = unique(s.t); y = interp1(tt, s.pitch_deg(iu), tg);
end
