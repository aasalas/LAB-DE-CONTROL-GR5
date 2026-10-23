function demo_pil(caso, puerto)
% Demostracion en vivo: corre un caso en PiL.slx con el controlador en el Arduino (modo PIL),
% grafica la respuesta sobre el MiL guardado y muestra sus metricas.
%   demo_pil                  PiL no ideal (sesgo + histeresis + ADC), puerto automatico
%   demo_pil('ideal')         otros casos: 'ideal', 'cuant', 'lin', 'hist', 'todas', 'mil'
%   demo_pil('todas', 'COM4') fija el puerto
% 'mil' corre el controlador en el PC (bloque Model en modo Normal), sin Arduino.
if nargin < 1, caso = 'todas'; end
here = fileparts(mfilename('fullpath')); cd(here);
casos = struct('mil', [0 0 0], 'ideal', [0 0 0], 'cuant', [0 0 1], 'lin', [1 0 0], ...
               'hist', [0 1 0], 'todas', [1 1 1]);
if ~isfield(casos, caso), error('Caso desconocido: %s. Use %s.', caso, strjoin(fieldnames(casos), ', ')); end
en = casos.(caso);

% parametros de la planta y del sensor en el workspace base (los lee el modelo)
evalin('base', sprintf('run(''%s'')', fullfile(here, '..', 'CINEMATICA', 'MARLUP_hydr_params.m')));
q = 0.45/1024;                                         % ADC de 10 bits sobre 450 mm
sens = struct('bias', 0.09e-3*en(1), 'backlash', 0.004e-3*en(2), 'q', 1e-12, 'xmin', -inf, 'xmax', inf);
if en(3), sens.q = q; sens.xmin = 0; sens.xmax = 1023*q; end
assignin('base', 'sens', sens);

m = 'PiL'; load_system(m);
if usejava('desktop'), open_system(m); end
pil = 'Processor-in-the-loop (PIL)';
if strcmp(caso, 'mil')
    set_param([m '/Controlador'], 'SimulationMode', 'Normal');
else
    if nargin < 2, pil_puerto; else, pil_puerto(puerto); end
    set_param([m '/Controlador'], 'SimulationMode', pil);
end
fprintf('\n=== demo_pil: caso %s, sesgo %d, histeresis %d, ADC %d ===\n', caso, en);

tic;
try
    out = sim(m, 'StopTime', '4', 'ReturnWorkspaceOutputs', 'on');
catch err
    if strcmp(caso, 'mil'), rethrow(err); end
    fprintf('Se recompila el controlador (%s)\n', err.message);
    limpiar_pil;
    out = sim(m, 'StopTime', '4', 'ReturnWorkspaceOutputs', 'on');
end
fprintf('Simulacion lista en %.1f s\n', toc);
set_param([m '/Controlador'], 'SimulationMode', pil);  % el modelo queda en modo PIL

% resultados frente al MiL guardado por run_pil
n = numel(out.log_x); t = (0:n-1)'*0.01;
L = [t out.log_ref(:) out.log_x(:) out.log_xm(:) out.log_u(:)];
Lm = readmatrix(fullfile(here, 'resultados', 'MiL.csv'));
M = metricas_pil(struct('MiL', Lm, 'demo', L), {'MiL', 'demo'});
M.caso(2) = string(caso);
disp(M(:, {'caso', 'Mp_pct', 'ts_s', 'ess_mm', 'rmse_vs_MiL_mm', 'emax_vs_MiL_mm'}));
fprintf('Requisitos: Mp = %.2f %% (< 10 %%), e_ss = %.3f mm (< 2.3 mm)\n', M.Mp_pct(2), M.ess_mm(2));

f = figure('Name', ['demo_pil: ' caso], 'NumberTitle', 'off', 'Units', 'centimeters', 'Position', [3 3 18 13]);
theme(f, 'light');
subplot(3,1,[1 2]); hold on; grid on;
plot(Lm(:,1), Lm(:,3)*1e3, 'k-', 'LineWidth', 1.2);
plot(t, L(:,3)*1e3, 'r--', 'LineWidth', 1.4);
plot(t, L(:,2)*1e3, ':', 'Color', [0.4 0.4 0.4]);
ylabel('x (mm)'); ylim([-20 460]); legend('MiL', ['PiL ' caso], 'referencia', 'Location', 'northwest');
title(sprintf('PiL %s: Mp = %.2f %%, e_{ss} = %.3f mm, RMSE vs MiL = %.3f mm', ...
    caso, M.Mp_pct(2), M.ess_mm(2), M.rmse_vs_MiL_mm(2)));
axes('Position', [0.55 0.5 0.33 0.2]); hold on; grid on; box on;   % detalle cerca de 400 mm
plot(Lm(:,1), Lm(:,3)*1e3, 'k-', t, L(:,3)*1e3, 'r--');
xlim([1.2 4]); ylim([395 405]); title('detalle', 'FontWeight', 'normal');
subplot(3,1,3); hold on; grid on;
stairs(Lm(:,1), Lm(:,5), 'k-'); stairs(t, L(:,5), 'r--');
ylabel('u'); xlabel('t (s)');
if ~usejava('desktop')                                 % sin ventana (matlab -batch): se guarda la figura
    png = fullfile(tempdir, ['demo_pil_' caso '.png']);
    exportgraphics(f, png, 'Resolution', 120); fprintf('Figura: %s\n', png);
end
end
