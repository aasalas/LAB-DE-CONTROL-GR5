function R = exp13_informe()
% EXP13_INFORME  Corridas del informe del Avance 3 con la arquitectura B (Kp = 27.5, Ki = 1).
% Completa las de exp12 (MiL nominal y de 15°, PiL ideal y no ideal nominal):
%   sin compensar (MiL, en memoria: la cinemática recibe base = 0)   nominal, 5°, 10°, 15°
%   MiL no ideal (encoder de 5 LSB)                                 nominal
%   MiL                                                             5°, 10°
%   PiL no ideal                                                    5°, 10°, 15°
%   tiempo de ejecución de ctrl_pi3 en el ATmega328P (perfil de ejecución del PIL)
%   costo de un paso PiL (tiempo de pared por paso, PiL menos MiL)
% Olas grandes: Tp = 12 s, Hs = 5.06, 10.20 y 15.49 m (base de 5°, 10° y 15°). Nominal: Hs = 2 m, Tp = 10 s.
% Cada caso se guarda al terminar en DOCS/AVANCES/AVANCE 3/resultados/exp13_informe.mat; si el archivo
% existe, los casos hechos se omiten. Requiere el Arduino conectado. ~40 min.
here = fileparts(mfilename('fullpath')); cd(here);
f = fullfile(here, '..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'resultados', 'exp13_informe.mat');
R = struct(); if isfile(f), load(f, 'R'); end
olas = struct('id', {'nominal', 'b05', 'b10', 'b15'}, 'Hs', {2, 5.06, 10.20, 15.49}, 'Tp', {10, 12, 12, 12});
casos = {};
for o = olas, casos(end+1, :) = {['sin_' o.id], @() sin_compensar(o.Hs, o.Tp)}; end %#ok<AGROW>
casos(end+1, :) = {'mil_noideal_nominal', @() correr_pil3('mil', 'NoIdeal', [1 1 1 1], 'Figura', false)};
for o = olas(2:3), casos(end+1, :) = {['mil_' o.id], @() correr_pil3('mil', 'Hs', o.Hs, 'Tp', o.Tp, 'Figura', false)}; end %#ok<AGROW>
for o = olas(2:4)
    casos(end+1, :) = {['pil_noideal_' o.id], @() correr_pil3('pil', 'Hs', o.Hs, 'Tp', o.Tp, 'NoIdeal', [1 1 1 1], 'Figura', false)}; %#ok<AGROW>
end
casos(end+1, :) = {'tiempos', @() tiempos()};
for c = 1:size(casos, 1)
    id = casos{c, 1};
    if isfield(R, id), fprintf('[%s] ya hecho\n', id); continue, end
    fprintf('\n=== %s (%d/%d) ===\n', id, c, size(casos, 1));
    try
        R.(id) = casos{c, 2}();
    catch err
        fprintf(2, 'FALLÓ %s: %s\n', id, err.message); R.(id) = struct('error', err.message);
    end
    save(f, 'R');
end
end

function r = sin_compensar(Hs, Tp)
% MiL sin compensar: las entradas de ángulo de la cinemática inversa a cero (la mesa sigue a la base).
mdl = 'Model_aaron';
assignin('base', 'ovr_pil3', struct('en_lin', 0, 'en_hist', 0, 'en_q', 0, 'en_ruido', 0));
limpia = onCleanup(@() evalin('base', 'clear ovr_pil3'));
evalin('base', 'run(''iniciar_pil3.m'')');
load_system(mdl); cierra = onCleanup(@() close_system(mdl, 0));            % no se guarda nada
ff = get_param([mdl '/Demux FF'], 'PortHandles'); ik = get_param([mdl '/INVERSE  KINEMATICS'], 'PortHandles');
for k = 1:2
    delete_line(mdl, ff.Outport(k), ik.Inport(k));
    b = sprintf('%s/cero%d', mdl, k); add_block('simulink/Sources/Constant', b, 'Value', '0');
    q = get_param(b, 'PortHandles'); add_line(mdl, q.Outport(1), ik.Inport(k));
end
set_param([mdl '/P-M SPECTRUM/Constant1'], 'Value', num2str(Hs, 8));
set_param([mdl '/P-M SPECTRUM/Constant2'], 'Value', num2str(Tp));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', 'StopTime', '30');
lg = @(h, n) set_param(h, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', n);
pp = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles'); lg(pp.Outport(1), 'roll'); lg(pp.Outport(3), 'pitch');
tic; out = sim(mdl); r.t_sim_s = toc;
p = out.logsout.getElement('pitch').Values; rl = out.logsout.getElement('roll').Values; i = p.Time >= 2;
r.t = p.Time; r.pitch_deg = rad2deg(squeeze(p.Data)); r.roll_deg = rad2deg(squeeze(rl.Data));
r.pico_pitch = max(abs(r.pitch_deg(i))); r.rms_pitch = rms(r.pitch_deg(i));
r.pico_roll = max(abs(r.roll_deg(i))); r.rms_roll = rms(r.roll_deg(i)); r.Hs = Hs; r.Tp = Tp;
fprintf('Sin compensar: pitch %.3f°, roll %.3f°\n', r.pico_pitch, r.pico_roll);
end

function r = tiempos()
% Tiempo de ejecución del paso de ctrl_pi3 en el Arduino, con el perfil de ejecución del PIL (2 s, 201 pasos).
% (El tiempo de pared de una corrida no sirve para medir la latencia de un paso: lo dominan la compilación
% y la conexión con la placa. La latencia se acota en el informe: 36 B a 115200 baud más el cómputo.)
r = struct();
pil3_puerto;
evalin('base', 'run(''iniciar_pil3.m'')');
mdl = 'Model_aaronC'; load_system(mdl); cierra = onCleanup(@() close_system(mdl, 0));
set_param(mdl, 'CodeExecutionProfiling', 'on', 'CodeProfilingSaveOptions', 'AllData', ...
    'CodeExecutionProfileVariable', 'perfil', 'StopTime', '2');
out = sim(mdl, 'ReturnWorkspaceOutputs', 'on'); ep = out.perfil;
s = ep.Sections; tps = double(ep.TimerTicksPerSecond);
for k = 1:numel(s)
    nom = s(k).Name; tt = double(s(k).ExecutionTimeInTicks); tt = tt(tt > 0);
    if isempty(tt), continue, end
    r.perfil(k) = struct('nombre', nom, 'max_us', 1e6*max(tt)/tps, 'medio_us', 1e6*mean(tt)/tps, 'n', numel(tt));
    fprintf('Perfil %-30s máx %8.1f us, medio %8.1f us (%d llamadas)\n', nom, 1e6*max(tt)/tps, 1e6*mean(tt)/tps, numel(tt));
end
set_param(mdl, 'CodeExecutionProfiling', 'off');
end
