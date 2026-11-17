function T = fig_final()
% FIG_FINAL  Nivelación con la arquitectura B (prealimentación pura, Kp = 27.5, Ki = 1), Hs = 2 m,
% Tp = 10 s, 30 s. Lee de ../resultados/
%   exp12_B_mil.mat   r1: MiL nominal
%   exp12_B_pil.mat   p1: PiL ideal, p2: PiL no ideal (encoder de 5 LSB)
%   exp13_informe.mat sin_nominal: sin compensar; mil_noideal_nominal: MiL no ideal
% y escribe pil_nivelacion.pdf/.png y ../resultados/metricas_final.csv
here = fileparts(mfilename('fullpath')); dres = fullfile(here, '..', 'resultados'); t0 = 2; c = paleta();
A = load(fullfile(dres, 'exp12_B_mil.mat')); P = load(fullfile(dres, 'exp12_B_pil.mat'));
E = load(fullfile(dres, 'exp13_informe.mat')).R;
sin = E.sin_nominal; mil = A.r1; milN = E.mil_noideal_nominal; pil = P.p1; pilN = P.p2;
tg = (t0:0.01:29.99)';

% --- métricas
casos = {'Sin compensar', sin, []; 'MiL', mil, []; 'MiL no ideal', milN, mil; ...
         'PiL ideal', pil, mil; 'PiL no ideal', pilN, milN};
fil = {};
for i = 1:size(casos, 1)
    s = casos{i, 2}; q = casos{i, 3}; j = s.t >= t0; d = [NaN NaN];
    if ~isempty(q), e = malla(s, 'pitch_deg', tg) - malla(q, 'pitch_deg', tg); d = [rms(e) max(abs(e))]; end
    u = [NaN NaN]; if isfield(s, 'u_rms'), u = [max(s.u_rms) max(s.sat_pct)]; end
    fil(end+1, :) = {casos{i, 1}, max(abs(s.pitch_deg(j))), rms(s.pitch_deg(j)), max(abs(s.roll_deg(j))), ...
        rms(s.roll_deg(j)), 20*log10(rms(s.pitch_deg(j))/rms(sin.pitch_deg(sin.t >= t0))), u(1), u(2), d(1), d(2)}; %#ok<AGROW>
end
T = cell2table(fil, 'VariableNames', {'caso', 'pico_pitch', 'rms_pitch', 'pico_roll', 'rms_roll', ...
    'aten_pitch_dB', 'u_rms_max', 'sat_pct', 'rmse_pitch_vs_ref', 'emax_pitch_vs_ref'});
disp(T); writetable(T, fullfile(dres, 'metricas_final.csv'));

% --- figura: pitch y roll de la mesa
f = figure('Units', 'centimeters', 'Position', [2 2 18 9], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tl = tiledlayout(f, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
nom = {'pitch_deg', 'roll_deg'}; et = {'\theta (°)', '\alpha (°)'};
for k = 1:2
    ax = nexttile(tl, [1 2]); hold on; grid on;
    plot(ax, sin.t, sin.(nom{k}), '-', 'Color', c.gris, 'LineWidth', 1.0, 'DisplayName', 'sin compensar');
    plot(ax, mil.t, mil.(nom{k}), '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'MiL');
    plot(ax, pil.t, pil.(nom{k}), '--', 'Color', c.naranja, 'LineWidth', 1.2, 'DisplayName', 'PiL ideal');
    plot(ax, pilN.t, pilN.(nom{k}), '-', 'Color', c.verde, 'LineWidth', 0.8, 'DisplayName', 'PiL no ideal');
    yline(ax, [-1 1], ':k', 'HandleVisibility', 'off'); xlim(ax, [0 30]); ylim(ax, [-3.2 3.2]); ylabel(ax, et{k});
    if k == 1, legend(ax, 'Location', 'northoutside', 'Orientation', 'horizontal'); else, xlabel(ax, 't (s)'); end
    ax = nexttile(tl); hold on; grid on;                       % detalle de 4 s
    plot(ax, mil.t, mil.(nom{k}), '-', 'Color', c.azul, 'LineWidth', 1.4);
    plot(ax, pil.t, pil.(nom{k}), '--', 'Color', c.naranja, 'LineWidth', 1.2);
    plot(ax, pilN.t, pilN.(nom{k}), '-', 'Color', c.verde, 'LineWidth', 0.8);
    xlim(ax, [18 22]); ylim(ax, [-0.5 0.5]); if k == 2, xlabel(ax, 't (s)'); end
    if k == 1, title(ax, 'detalle', 'FontWeight', 'normal'); end
end
exportgraphics(f, fullfile(here, 'pil_nivelacion.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pil_nivelacion.png'), 'Resolution', 200); close(f);
end

function y = malla(s, campo, t)
[tu, iu] = unique(s.t); y = interp1(tu, s.(campo)(iu), t, 'linear');
end

function c = paleta()
c = struct('gris', [0.62 0.62 0.62], 'azul', [0 0.40 0.70], 'naranja', [0.85 0.37 0.0], 'verde', [0.30 0.60 0.20]);
end
