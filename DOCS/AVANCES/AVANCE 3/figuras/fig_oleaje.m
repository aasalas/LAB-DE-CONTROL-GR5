function T = fig_oleaje()
% FIG_OLEAJE  Nivelación con el PiL no ideal (Arduino, encoder de 5 LSB), Kp = 27.5, Ki = 1, en los cuatro
% estados de mar: nominal (Hs = 2 m, Tp = 10 s) y olas lentas (Tp = 12 s) que inclinan la base 5°, 10° y
% 15° (Hs = 5.06, 10.20 y 15.49 m).
%   oleaje_casos.pdf/.png      pitch de la base y de la mesa con la misma escala (bases de 5° y 10°; el
%                              de 15° es la figura de fig_final.m), con el pico de cada respuesta marcado
%   ../resultados/metricas_oleaje.csv   tabla del informe, los cuatro casos
% Lee ../resultados/exp13_informe.mat y exp12_B_pil.mat (p2: PiL no ideal nominal).
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2;
E = load(fullfile(dres, 'exp13_informe.mat')).R; P = load(fullfile(dres, 'exp12_B_pil.mat'));
base = {E.sin_nominal, E.sin_b05, E.sin_b10, E.sin_b15};
mesa = {P.p2, E.pil_noideal_b05, E.pil_noideal_b10, E.pil_noideal_b15};
lim = [3 5 10 15];

% --- tabla de los cuatro casos
fil = {};
for i = 1:4
    b = base{i}; m = mesa{i}; jb = b.t >= t0; jm = m.t >= t0;
    fil(end+1, :) = {max(abs(b.pitch_deg(jb))), max(abs(b.roll_deg(jb))), max(abs(m.pitch_deg(jm))), ...
        max(abs(m.roll_deg(jm))), 20*log10(rms(m.pitch_deg(jm))/rms(b.pitch_deg(jb))), max(m.u_rms), max(m.sat_pct)}; %#ok<AGROW>
end
T = cell2table(fil, 'VariableNames', {'base_pitch', 'base_roll', 'mesa_pitch', 'mesa_roll', 'aten_dB', 'u_rms', 'sat_pct'});
disp(T); writetable(T, fullfile(dres, 'metricas_oleaje.csv'));

% --- figura: bases de 5° y 10° (el nominal, de 2.9°, no se grafica: queda en la tabla)
f = figure('Units', 'centimeters', 'Position', [2 2 8.8 7], 'Visible', 'off'); c = fig_estilo(f);
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 2:3
    b = base{i}; m = mesa{i};
    ax = nexttile(tl); hold on;
    plot(ax, b.t, b.pitch_deg, '-', 'Color', c.gris, 'LineWidth', 1.0, 'DisplayName', 'base');
    plot(ax, m.t, m.pitch_deg, '-', 'Color', c.azul, 'LineWidth', 1.1, 'DisplayName', 'mesa');
    xlim(ax, [0 30]); ylim(ax, lim(i)*[-1 1]); yticks(ax, lim(i)*[-1 0 1]); ylabel(ax, '$\theta$ [$^\circ$]');
    fig_pico(ax, b.t, b.pitch_deg, [0.45 0.45 0.45], t0, '$%.1f^\\circ$', 0.5);
    fig_pico(ax, m.t, m.pitch_deg, c.azul, t0, '$%.2f^\\circ$', 0.5);
    if i == 2, legend(ax, 'Location', 'northoutside', 'Orientation', 'horizontal'); end
    if i < 3, xticklabels(ax, {}); else, xlabel(ax, '$t$ [s]'); end
end
exportgraphics(f, fullfile(here, 'oleaje_casos.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'oleaje_casos.png'), 'Resolution', 200); close(f);
end
