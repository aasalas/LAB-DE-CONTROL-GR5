%% EXP10_25GRADOS  Experimento: base de 25° con cilindros virtuales más largos (no es el MARLUP real).
% Con la carrera real (0.45 m, ±0.22 m alrededor de 0.23 m) la mesa compensa como máximo ~15° con esta ola
% (pitch y roll a la vez). Aquí, solo en memoria: carrera de 0.80 m con posición de trabajo en 0.40 m,
% ola lenta (Tp = 20 s) para que la velocidad que piden los cilindros quede bajo 0.29 m/s, y heave de la
% ola anulado (con Tp = 20 s haría falta Hs ~70 m, que movería la base ~20 m en vertical).
% Controlador final: prealimentación (Kff = 1) + K = 3, saturación ±30°, g = 1, Kp = 20, Ki = 1, MiL.
% Resultado: DOCS/AVANCES/AVANCE 3/resultados/exp10_25grados.mat. ~3 min.
cd(fileparts(mfilename('fullpath')));
Tp = 12*20/12; obj = 25; carrera = 0.38;            % ±0.40 m útiles, con 2 cm de margen al tope
[~, ~, b1] = ola_exigencia(1, Tp); Hs = obj/b1;
for k = 1:3, [v, ca, b] = ola_exigencia(Hs, Tp); Hs = Hs*obj/b; end
[v, ca, b] = ola_exigencia(Hs, Tp);
fprintf('Ola: Hs = %.1f m, Tp = %g s, base %.1f°; pide %.2f m/s y %.0f mm a los cilindros\n', Hs, Tp, b, v, 1000*ca);
assert(v <= 0.95*0.29 && ca <= 0.95*carrera, 'La ola no es viable ni con los cilindros virtuales: no se simula');

run('MARLUP_hydr_params.m'); cyl.stroke = 0.80; cyl.x_init = 0.40;     %#ok<NASGU> se pasa por ovr_pil3
assignin('base', 'ovr_pil3', struct('cyl', cyl, 'Kff', 1, 'en_lin', 0, 'en_hist', 0, 'en_q', 0, 'en_ruido', 0));
limpia = onCleanup(@() evalin('base', 'clear ovr_pil3'));
evalin('base', 'run(''iniciar_pil3.m'')');
mdl = 'Model_aaron'; load_system(mdl); cierra = onCleanup(@() close_system(mdl, 0));   % no se guarda nada
ch = find(sfroot, '-isa', 'Stateflow.EMChart', 'Path', [mdl '/P-M SPECTRUM/P-M SPECTRUM']);
ch.Script = strrep(ch.Script, 'heave = sum(Anm .* cos(arg), ''all'');', 'heave = 0;');
set_param([mdl '/Constant4'], 'Value', '0.40');                         % posición de trabajo en la referencia
set_param([mdl '/Gain'], 'Gain', '3'); set_param([mdl '/Gain1'], 'Gain', '3');
set_param([mdl '/P-M SPECTRUM/Constant1'], 'Value', num2str(Hs, 8)); set_param([mdl '/P-M SPECTRUM/Constant2'], 'Value', num2str(Tp));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', 'StopTime', '40');
lg = @(ph, n) set_param(ph, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', n);
ph = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles'); lg(ph.Outport(1), 'roll'); lg(ph.Outport(3), 'pitch');
pm = get_param([mdl '/P-M SPECTRUM'], 'PortHandles'); lg(pm.Outport(1), 'base');
for i = 1:3, pp = get_param(sprintf('%s/PISTON %d', mdl, i), 'PortHandles'); lg(pp.Outport(1), sprintf('x%d', i)); end
tic; out = sim(mdl); ts = toc;
g = @(n) out.logsout.getElement(n).Values;
p = g('pitch'); r = g('roll'); bs = g('base'); i = p.Time >= 2;
bd = squeeze(bs.Data); if size(bd, 1) ~= numel(bs.Time), bd = bd.'; end
xs = cellfun(@(n) g(n).Data, {'x1', 'x2', 'x3'}, 'UniformOutput', false);
res = struct('Hs', Hs, 'Tp', Tp, 't', p.Time, 'pitch_deg', rad2deg(p.Data), 'roll_deg', rad2deg(r.Data), ...
    't_base', bs.Time, 'base_roll_deg', rad2deg(bd(:, 1)), 'base_pitch_deg', rad2deg(bd(:, 2)), ...
    'pico_pitch', rad2deg(max(abs(p.Data(i)))), 'pico_roll', rad2deg(max(abs(r.Data(i)))), ...
    'x_min', min(cellfun(@min, xs)), 'x_max', max(cellfun(@max, xs)), 't_sim_s', ts);
save(fullfile('..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'resultados', 'exp10_25grados.mat'), 'res');
fprintf('Base: pitch %.1f°, roll %.1f° | mesa: pitch %.3f°, roll %.3f° | pistones entre %.3f y %.3f m (carrera 0-0.80) | %.0f s\n', ...
    max(abs(res.base_pitch_deg)), max(abs(res.base_roll_deg)), res.pico_pitch, res.pico_roll, res.x_min, res.x_max, ts);
