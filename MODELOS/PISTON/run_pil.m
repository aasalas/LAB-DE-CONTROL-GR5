% Processor-in-the-Loop de un piston: el bloque Model 'Controlador' de PiL.slx referencia
% ctrl_pi.slx y corre en modo Normal para el MiL y en modo Processor-in-the-loop (codigo
% generado por Embedded Coder en el Arduino Uno) para los cinco casos PiL.
% Escribe resultados/ (metricas.csv, log_corridas.txt, CSV por caso) y figuras/.
%   run_pil                       usa el ultimo puerto serial disponible
%   PIL_PORT = 'COM4'; run_pil    fija el puerto
here = fileparts(mfilename('fullpath'));
cd(here);
run(fullfile(here, '..', 'CINEMATICA', 'MARLUP_hydr_params.m'));
if ~exist('PIL_PORT', 'var'), pil_puerto; else, pil_puerto(PIL_PORT); end
m = 'PiL'; load_system(m);
outd = 'resultados'; figd = 'figuras';
if ~isfolder(outd), mkdir(outd); end
logf = fopen(fullfile(outd, 'log_corridas.txt'), 'w');

% nombre, modo del bloque Model, [en_lin en_hist en_q]
pil = 'Processor-in-the-loop (PIL)';
casos = {'MiL',        'Normal', [0 0 0];
         'PiL_ideal',  pil,      [0 0 0];
         'PiL_cuant',  pil,      [0 0 1];
         'PiL_lin',    pil,      [1 0 0];
         'PiL_hist',   pil,      [0 1 0];
         'PiL_todas',  pil,      [1 1 1]};

q = 0.45/1024;                                         % ADC de 10 bits sobre 450 mm
R = struct(); limpio = false;
for c = 1:size(casos, 1)
    nom = casos{c,1}; en = casos{c,3};
    sens = struct('bias', 0.09e-3*en(1), 'backlash', 0.004e-3*en(2), ...
                  'q', 1e-12, 'xmin', -inf, 'xmax', inf);   % sin ADC: intervalo despreciable
    if en(3), sens.q = q; sens.xmin = 0; sens.xmax = 1023*q; end
    set_param([m '/Controlador'], 'SimulationMode', casos{c,2});
    if strcmp(casos{c,2}, pil) && ~limpio, limpiar_pil; limpio = true; end   % compila una sola vez
    tic;
    try
        out = sim(m, 'StopTime', '4', 'ReturnWorkspaceOutputs', 'on');
    catch err
        if ~strcmp(casos{c,2}, pil), rethrow(err); end
        fprintf('%s: fallo la aplicacion PIL, se recompila (%s)\n', nom, err.message);
        limpiar_pil;
        out = sim(m, 'StopTime', '4', 'ReturnWorkspaceOutputs', 'on');
    end
    dt = toc;
    n = numel(out.log_x); t = (0:n-1)'*0.01;
    L = [t out.log_ref(:) out.log_x(:) out.log_xm(:) out.log_u(:)];
    R.(nom) = L;
    writematrix(L, fullfile(outd, [nom '.csv']));
    fprintf(logf, '%s: modo %s, %d muestras, %.1f s\n', nom, casos{c,2}, n, dt);
    fprintf('%s listo (%.1f s)\n', nom, dt);
end

M = metricas_pil(R, casos(:,1));
writetable(M, fullfile(outd, 'metricas.csv'));
disp(M);
figuras_pil
fprintf(logf, 'OK\n'); fclose(logf);
save(fullfile(outd, 'resultados_pil.mat'), 'R', 'M');
set_param([m '/Controlador'], 'SimulationMode', pil); save_system(m);   % queda abierto en modo PIL
disp('run_pil OK');
