function fig_pico(ax, t, y, col, t0, fmt, dx)
% FIG_PICO  Marca el pico de |y| (para t >= t0) con un punto y escribe su valor junto al punto, con
% fondo blanco y corrido hacia el interior del eje (el pico de la base coincide con el límite del eje).
% Si el pico está en el último 20 % del eje, el valor va a la izquierda del punto.
%   fmt: formato del valor (p. ej. '$%.2f^\circ$'); dx: separación horizontal en unidades de datos.
if nargin < 7, dx = 0.4; end
i = find(t >= t0); [~, k] = max(abs(y(i))); k = i(k);
plot(ax, t(k), y(k), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', 3.5, 'HandleVisibility', 'off');
xl = xlim(ax); yl = ylim(ax); dy = 0.10*diff(yl)*sign(y(k));
if t(k) > xl(1) + 0.8*diff(xl), x = t(k) - dx; ha = 'right'; else, x = t(k) + dx; ha = 'left'; end
text(ax, x, y(k) - dy, sprintf(fmt, y(k)), 'Color', col, 'FontSize', 7.5, 'HorizontalAlignment', ha, ...
    'VerticalAlignment', 'middle', 'BackgroundColor', 'w', 'Margin', 0.5);
end
