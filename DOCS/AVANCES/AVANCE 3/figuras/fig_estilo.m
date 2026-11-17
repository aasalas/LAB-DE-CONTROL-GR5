function c = fig_estilo(f)
% FIG_ESTILO  Estilo común de las figuras del informe: tema claro, LaTeX en todos los textos, sin
% cuadrícula ni bordes superior y derecho. Devuelve la paleta.
theme(f, 'light');
set(f, 'Color', 'w', 'DefaultTextInterpreter', 'latex', 'DefaultAxesTickLabelInterpreter', 'latex', ...
    'DefaultLegendInterpreter', 'latex', 'DefaultAxesBox', 'off', 'DefaultAxesXGrid', 'off', ...
    'DefaultAxesYGrid', 'off', 'DefaultAxesFontSize', 8, 'DefaultAxesTickDir', 'out', ...
    'DefaultLegendBox', 'off');
c = struct('gris', [0.62 0.62 0.62], 'azul', [0 0.40 0.70], 'naranja', [0.85 0.37 0.0], 'verde', [0.30 0.60 0.20]);
end
