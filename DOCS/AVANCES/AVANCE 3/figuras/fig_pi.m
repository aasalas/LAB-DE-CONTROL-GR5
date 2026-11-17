function T = fig_pi()
% FIG_PI  Respuesta al escalón del PI final (Kp = 27.5, Ki = 1) de un actuador, con el sensor no ideal
% (linealidad, histéresis y ADC de 10 bits, como en MODELOS/PISTON).
%   (a) escalón de 10 mm en x0 = 0.23 m (en t = 1.5 s, como diseno_pi.m): G(s) identificada (diseño)
%       y modelo no lineal con el sensor no ideal
%   (b) escalón de 0 a 0.40 m en el PiL no ideal (Arduino), de MODELOS/PISTON/run_pil.m (PiL_todas)
% Escribe pi_escalon.pdf/.png y ../resultados/metricas_pi.csv. El modelo PiL.slx no se guarda.
here = fileparts(mfilename('fullpath')); pis = fullfile(here, '..', '..', '..', '..', 'MODELOS', 'PISTON');
Kp = 27.5; Ki = 1; Ts = 0.01;
D = load(fullfile(pis, 'resultados', 'diseno_pi.mat'));               % G(s) identificada
C = pid(Kp, Ki, 'Ts', Ts, 'IFormula', 'Trapezoidal');
Gd = c2d(D.G, Ts, 'zoh'); Tcl = feedback(C*Gd, 1); am = allmargin(C*Gd);
[yl, tl] = step(Tcl, 0:Ts:3);

% modelo no lineal con el sensor no ideal, escalón de 10 mm (controlador en el PC; el PiL da lo mismo)
vuelve = onCleanup(@() cd(here)); cd(pis);
evalin('base', sprintf('run(''%s'')', fullfile(pis, '..', 'CINEMATICA', 'MARLUP_hydr_params.m')));
q = 0.45/1024;
evalin('base', sprintf(['cyl.x_init = 0.23; sens = struct(''bias'', 0.09e-3, ''backlash'', 0.004e-3, ' ...
    '''q'', %.12g, ''xmin'', 0, ''xmax'', %.12g);'], q, 1023*q));
m = 'PiL'; load_system(m); cierra = onCleanup(@() close_system(m, 0));
set_param([m '/Controlador'], 'SimulationMode', 'Normal');
set_param([m '/Step1'], 'Time', '1.5', 'Before', '0.23', 'After', '0.24');
out = sim(m, 'StopTime', '4.5', 'ReturnWorkspaceOutputs', 'on');
n = numel(out.log_x); tn = (0:n-1)'*0.01 - 1.5; xn = double(out.log_x(:)); un = double(out.log_u(:));
cd(here);

% escalón grande en el Arduino (run_pil, PiL_todas): columnas t, ref, x, x medida, u
P = readmatrix(fullfile(pis, 'resultados', 'PiL_todas.csv')); tp = P(:,1) - 0.5;

% métricas
i = tn >= 0; j = tp >= 0;
fila = @(nom, t, y, ya, yb, u) table(string(nom), met(t, y, ya, yb, 'Mp'), met(t, y, ya, yb, 'tr'), ...
    met(t, y, ya, yb, 'ts'), 1e3*abs(met(t, y, ya, yb, 'ess')), rms(u), ...
    'VariableNames', {'caso', 'Mp_pct', 'tr_s', 'ts_s', 'ess_mm', 'u_rms'});
T = [fila('G(s), 10 mm', tl, 0.01*yl, 0, 0.01, zeros(size(tl)));
     fila('No ideal, 10 mm', tn(i), xn(i), 0.23, 0.24, un(i));
     fila('PiL no ideal, 0 a 0.40 m', tp(j), P(j,3), 0, 0.40, P(j,5))];
T.MG_dB(:) = 20*log10(min(am.GainMargin(am.GainMargin > 1))); T.MF_deg(:) = min(am.PhaseMargin);
disp(T); writetable(T, fullfile(here, '..', 'resultados', 'metricas_pi.csv'));

% figura
f = figure('Units', 'centimeters', 'Position', [2 2 18 8.5], 'Visible', 'off'); c = fig_estilo(f);
tlo = tiledlayout(f, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tlo, 1, [2 1]); hold on;
plot(ax, tl, 10*yl, '--', 'Color', c.gris, 'LineWidth', 1.2, 'DisplayName', '$G(s)$, dise\~no');
plot(ax, tn, 1e3*(xn - 0.23), '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'modelo no ideal');
xlim(ax, [-0.1 1]); ylim(ax, [0 12]); ylabel(ax, '$x - x_0$ [mm]');
fig_pico(ax, tn, 1e3*(xn - 0.23), c.azul, 0, '$%.2f$ mm', 0.03);
title(ax, '(a) Escal\''on de 10 mm', 'FontWeight', 'normal'); legend(ax, 'Location', 'southeast');
ax = nexttile(tlo, 2, [2 1]); hold on;
plot(ax, tp, 1e3*P(:,3), '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'PiL no ideal (Arduino)');
xlim(ax, [-0.1 2]); ylim(ax, [0 450]); ylabel(ax, '$x$ [mm]');
fig_pico(ax, tp, 1e3*P(:,3), c.azul, 0, '$%.1f$ mm', 0.05);
title(ax, '(b) Escal\''on de 0 a 400 mm', 'FontWeight', 'normal'); legend(ax, 'Location', 'southeast');
ax = nexttile(tlo, 5); hold on;
stairs(ax, tn, un, '-', 'Color', c.azul); xlim(ax, [-0.1 1]); ylabel(ax, '$u$'); xlabel(ax, '$t$ [s]');
ax = nexttile(tlo, 6); hold on;
stairs(ax, tp, P(:,5), '-', 'Color', c.azul);
xlim(ax, [-0.1 2]); ylim(ax, [-0.1 1.1]); ylabel(ax, '$u$'); xlabel(ax, '$t$ [s]');
exportgraphics(f, fullfile(here, 'pi_escalon.pdf'), 'ContentType', 'vector');
exportgraphics(f, fullfile(here, 'pi_escalon.png'), 'Resolution', 200); close(f);
end

function v = met(t, y, ya, yb, que)
% Sobrepaso [%], subida 10-90 % [s], establecimiento al 2 % [s] y error final [m] de un escalón en t = 0.
i = t >= 0; tt = t(i); yy = (y(i) - ya)/(yb - ya);
switch que
    case 'Mp', v = max(0, 100*(max(yy) - 1));
    case 'tr', v = tt(find(yy >= 0.9, 1)) - tt(find(yy >= 0.1, 1));
    case 'ts'
        k = find(abs(yy - 1) > 0.02, 1, 'last');
        if isempty(k), v = 0; elseif k == numel(yy), v = inf; else, v = tt(k + 1); end
    case 'ess', v = (1 - mean(yy(tt >= tt(end) - 0.5)))*(yb - ya);
end
end
