function T = fig_pi()
% FIG_PI  Respuesta al escalón del PI final (Kp = 27.5, Ki = 1) de un actuador.
%   (a) escalón de 10 mm en x0 = 0.23 m: función de transferencia identificada y modelo no lineal (MiL)
%   (b) escalón de 0 a 0.40 m: MiL, PiL ideal y PiL no ideal (Arduino), de MODELOS/PISTON/run_pil.m
% Escribe pi_escalon.pdf/.png y ../resultados/metricas_pi.csv. El modelo PiL.slx no se guarda.
here = fileparts(mfilename('fullpath')); pis = fullfile(here, '..', '..', '..', '..', 'MODELOS', 'PISTON');
Kp = 27.5; Ki = 1; Ts = 0.01; c = paleta();
D = load(fullfile(pis, 'resultados', 'diseno_pi.mat'));               % G(s) identificada
C = pid(Kp, Ki, 'Ts', Ts, 'IFormula', 'Trapezoidal');
Gd = c2d(D.G, Ts, 'zoh'); Tcl = feedback(C*Gd, 1); am = allmargin(C*Gd);
[yl, tl] = step(Tcl, 0:Ts:3);

% modelo no lineal, escalón de 10 mm (controlador en el PC)
vuelve = onCleanup(@() cd(here)); cd(pis);
evalin('base', sprintf('run(''%s'')', fullfile(pis, '..', 'CINEMATICA', 'MARLUP_hydr_params.m')));
evalin('base', 'cyl.x_init = 0.23; sens = struct(''bias'', 0, ''backlash'', 0, ''q'', 1e-12, ''xmin'', -inf, ''xmax'', inf);');
m = 'PiL'; load_system(m); cierra = onCleanup(@() close_system(m, 0));
set_param([m '/Controlador'], 'SimulationMode', 'Normal');
set_param([m '/Step1'], 'Time', '1.5', 'Before', '0.23', 'After', '0.24');      % como diseno_pi.m
out = sim(m, 'StopTime', '4.5', 'ReturnWorkspaceOutputs', 'on');
n = numel(out.log_x); tn = (0:n-1)'*0.01 - 1.5; xn = double(out.log_x(:)); un = double(out.log_u(:));
cd(here);

% escalón grande (run_pil): columnas t, ref, x, x medida, u
L = @(nom) readmatrix(fullfile(pis, 'resultados', [nom '.csv']));
mil = L('MiL'); pid_ = L('PiL_ideal'); pnd = L('PiL_todas');

% métricas
i = tn >= 0;
fila = @(nom, t, y, ya, yb, u) table(string(nom), met(t, y, ya, yb, 'Mp'), met(t, y, ya, yb, 'tr'), ...
    met(t, y, ya, yb, 'ts'), 1e3*abs(met(t, y, ya, yb, 'ess')), rms(u), ...
    'VariableNames', {'caso', 'Mp_pct', 'tr_s', 'ts_s', 'ess_mm', 'u_rms'});
T = [fila('Lineal, 10 mm', tl, 0.01*yl, 0, 0.01, zeros(size(tl)));
     fila('No lineal (MiL), 10 mm', tn(i), xn(i), 0.23, 0.24, un(i));
     fila('MiL, 0 a 0.40 m', mil(:,1) - 0.5, mil(:,3), 0, 0.40, mil(mil(:,1) >= 0.5, 5));
     fila('PiL ideal, 0 a 0.40 m', pid_(:,1) - 0.5, pid_(:,3), 0, 0.40, pid_(pid_(:,1) >= 0.5, 5));
     fila('PiL no ideal, 0 a 0.40 m', pnd(:,1) - 0.5, pnd(:,3), 0, 0.40, pnd(pnd(:,1) >= 0.5, 5))];
T.MG_dB(:) = 20*log10(min(am.GainMargin(am.GainMargin > 1))); T.MF_deg(:) = min(am.PhaseMargin);
disp(T); writetable(T, fullfile(here, '..', 'resultados', 'metricas_pi.csv'));

% figura
f = figure('Units', 'centimeters', 'Position', [2 2 18 9.5], 'Color', 'w', 'Visible', 'off'); theme(f, 'light');
tlo = tiledlayout(f, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tlo, 1, [2 1]); hold on; grid on;
plot(ax, tl, 10*yl, '-', 'Color', c.gris, 'LineWidth', 1.2, 'DisplayName', 'G(s) identificada');
plot(ax, tn, 1e3*(xn - 0.23), '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'modelo no lineal');
yline(ax, 10*[0.98 1.02], ':', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
xlim(ax, [-0.1 1]); ylabel(ax, 'x - x_0 (mm)'); title(ax, '(a) escalón de 10 mm', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast');
ax = nexttile(tlo, 2, [2 1]); hold on; grid on;
plot(ax, mil(:,1) - 0.5, 1e3*mil(:,3), '-', 'Color', c.azul, 'LineWidth', 1.4, 'DisplayName', 'MiL');
plot(ax, pid_(:,1) - 0.5, 1e3*pid_(:,3), '--', 'Color', c.naranja, 'LineWidth', 1.4, 'DisplayName', 'PiL ideal');
plot(ax, pnd(:,1) - 0.5, 1e3*pnd(:,3), ':', 'Color', c.verde, 'LineWidth', 1.6, 'DisplayName', 'PiL no ideal');
xlim(ax, [-0.1 2]); ylabel(ax, 'x (mm)'); title(ax, '(b) escalón de 0 a 400 mm', 'FontWeight', 'normal');
legend(ax, 'Location', 'southeast');
ax = nexttile(tlo, 5); hold on; grid on;
stairs(ax, tn, un, '-', 'Color', c.azul); xlim(ax, [-0.1 1]); ylabel(ax, 'u'); xlabel(ax, 't (s)');
ax = nexttile(tlo, 6); hold on; grid on;
stairs(ax, mil(:,1) - 0.5, mil(:,5), '-', 'Color', c.azul); stairs(ax, pnd(:,1) - 0.5, pnd(:,5), ':', 'Color', c.verde);
xlim(ax, [-0.1 2]); ylim(ax, [-0.1 1.1]); ylabel(ax, 'u'); xlabel(ax, 't (s)');
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

function c = paleta()
c = struct('gris', [0.62 0.62 0.62], 'azul', [0 0.40 0.70], 'naranja', [0.85 0.37 0.0], 'verde', [0.30 0.60 0.20]);
end
