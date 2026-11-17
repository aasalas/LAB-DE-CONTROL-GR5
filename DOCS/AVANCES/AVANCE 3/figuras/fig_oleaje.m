function T = fig_oleaje()
% FIG_OLEAJE  Oleajes grandes con la arquitectura B (Kp = 27.5, Ki = 1): olas lentas (Tp = 12 s) con
% Hs = 5.06, 10.20 y 15.49 m, que inclinan la base 5°, 10° y 15°. Sin compensar, MiL y PiL no ideal.
% Lee ../resultados/exp13_informe.mat y exp12_B_mil.mat (r2: MiL de 15°) y escribe
% oleaje_casos.pdf/.png y ../resultados/metricas_oleaje.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2; c = paleta();
E = load(fullfile(dres, 'exp13_informe.mat')).R; A = load(fullfile(dres, 'exp12_B_mil.mat'));
ids = {'b05', 'b10', 'b15'}; grados = [5 10 15];
mil = {E.mil_b05, E.mil_b10, A.r2};
f = figure('Units', 'centimeters', 'Position', [2 2 8.8 10], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
fil = {};
for i = 1:3
    s0 = E.(['sin_' ids{i}]); m = mil{i}; p = E.(['pil_noideal_' ids{i}]);
    ax = nexttile(tl); hold on; grid on;
    yyaxis(ax, 'left'); ax.YColor = [0.3 0.3 0.3];
    plot(ax, s0.t, s0.pitch_deg, '-', 'Color', c.gris, 'LineWidth', 1.0, 'DisplayName', 'base (izq.)');
    ylabel(ax, sprintf('base %d° (°)', grados(i))); ylim(ax, 1.15*max(abs(s0.pitch_deg))*[-1 1]);
    yyaxis(ax, 'right'); ax.YColor = [0 0 0];
    plot(ax, m.t, m.pitch_deg, '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'MiL');
    if isfield(p, 'pitch_deg')
        plot(ax, p.t, p.pitch_deg, '-', 'Color', c.verde, 'LineWidth', 0.8, 'DisplayName', 'PiL no ideal');
    end
    yline(ax, [-1 1], ':k', 'HandleVisibility', 'off'); ylim(ax, [-2.5 2.5]); ylabel(ax, '\theta mesa (°)');
    xlim(ax, [0 30]);
    if i == 1, legend(ax, 'Location', 'northoutside', 'Orientation', 'horizontal'); end
    if i == 3, xlabel(ax, 't (s)'); end
    j = @(s) s.t >= t0;
    pp = NaN; pr = NaN; pu = NaN; if isfield(p, 'pitch_deg'), pp = max(abs(p.pitch_deg(j(p)))); pr = max(abs(p.roll_deg(j(p)))); pu = max(p.u_rms); end
    fil(end+1, :) = {grados(i), max(abs(s0.pitch_deg(j(s0)))), max(abs(m.pitch_deg(j(m)))), max(abs(m.roll_deg(j(m)))), ...
        pp, pr, max(m.u_rms), pu, max(m.sat_pct)}; %#ok<AGROW>
end
fontsize(f, 7, 'points');
T = cell2table(fil, 'VariableNames', {'base_deg', 'sin_pitch', 'mil_pitch', 'mil_roll', 'pilN_pitch', 'pilN_roll', ...
    'mil_u_rms', 'pilN_u_rms', 'mil_sat_pct'});
disp(T); writetable(T, fullfile(dres, 'metricas_oleaje.csv'));
exportgraphics(f, fullfile(here, 'oleaje_casos.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'oleaje_casos.png'), 'Resolution', 200); close(f);
end

function c = paleta()
c = struct('gris', [0.62 0.62 0.62], 'azul', [0 0.40 0.70], 'naranja', [0.85 0.37 0.0], 'verde', [0.30 0.60 0.20]);
end
