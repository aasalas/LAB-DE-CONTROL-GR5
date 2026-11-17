function fig_final()
% FIG_FINAL  El caso más exigente: base de hasta 15° (Hs = 15.49 m, Tp = 12 s), PiL no ideal (Arduino,
% encoder de 5 LSB), Kp = 27.5, Ki = 1. Pitch y roll de la base y de la mesa con la misma escala, y el
% pico de cada respuesta marcado. Lee ../resultados/exp13_informe.mat y escribe pil_nivelacion.pdf/.png
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2;
E = load(fullfile(dres, 'exp13_informe.mat')).R;
b = E.sin_b15; m = E.pil_noideal_b15;                  % sin compensar: la mesa reproduce la base
f = figure('Units', 'centimeters', 'Position', [2 2 18 8], 'Visible', 'off'); c = fig_estilo(f);
tl = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nom = {'pitch_deg', 'roll_deg'}; et = {'$\theta$ [$^\circ$]', '$\alpha$ [$^\circ$]'};
for k = 1:2
    ax = nexttile(tl); hold on;
    plot(ax, b.t, b.(nom{k}), '-', 'Color', c.gris, 'LineWidth', 1.1, 'DisplayName', 'base');
    plot(ax, m.t, m.(nom{k}), '-', 'Color', c.azul, 'LineWidth', 1.2, 'DisplayName', 'mesa');
    xlim(ax, [0 30]); ylim(ax, [-15 15]); yticks(ax, [-15 0 15]); ylabel(ax, et{k});
    fig_pico(ax, b.t, b.(nom{k}), [0.45 0.45 0.45], t0, '$%.1f^\\circ$', 0.4);
    fig_pico(ax, m.t, m.(nom{k}), c.azul, t0, '$%.2f^\\circ$', 0.4);
    if k == 1, legend(ax, 'Location', 'northoutside', 'Orientation', 'horizontal'); xticklabels(ax, {});
    else, xlabel(ax, '$t$ [s]'); end
end
exportgraphics(f, fullfile(here, 'pil_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_nivelacion.png'), 'Resolution', 200); close(f);
end
