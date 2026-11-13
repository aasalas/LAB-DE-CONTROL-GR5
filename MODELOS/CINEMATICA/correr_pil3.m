function res = correr_pil3(modo, varargin)
% CORRER_PIL3  Simula la plataforma completa y mide la inclinación residual de la mesa.
%   correr_pil3('mil')                  MiL: Model_aaron.slx (controlador en el PC, sin Arduino)
%   correr_pil3('pil')                  PiL: Model_aaronC.slx (controlador en el Arduino)
%   correr_pil3('pil', 'Puerto', "COM8")
%   correr_pil3('mil', 'K', 25, 'Hs', 0.5, 'Tsim', 30)
%   correr_pil3('pil', 'NoIdeal', [1 1 1], 'Kp', 10)     sensor no ideal y otro Kp, sin editar archivos
% Opciones: K (lazo de nivelación, 20), Hs (altura significativa, 0.5 m), Tsim (30 s),
%   TIni (2 s, se ignora el arranque), Puerto (último disponible), Figura (true),
%   Kp, Ki, Usat y NoIdeal = [lin hist q] (por defecto los de config_pil3.m).
% Las ganancias del PI y las no idealidades se editan en config_pil3.m.
% Devuelve las inclinaciones pico y RMS de la mesa [grados] y las señales registradas.
p = inputParser;
addParameter(p, 'K', 20); addParameter(p, 'Hs', 0.5); addParameter(p, 'Tsim', 30);
addParameter(p, 'TIni', 2); addParameter(p, 'Puerto', []); addParameter(p, 'Figura', true);
addParameter(p, 'Kp', []); addParameter(p, 'Ki', []); addParameter(p, 'Usat', []); addParameter(p, 'NoIdeal', []);
parse(p, varargin{:}); o = p.Results;

% Sobrescrituras de config_pil3.m: las lee config_pil3 desde el workspace base
ovr = struct();
for c = {'Kp', 'Ki', 'Usat'}, if ~isempty(o.(c{1})), ovr.(c{1}) = o.(c{1}); end, end
if ~isempty(o.NoIdeal)
    ovr.en_lin = o.NoIdeal(1); ovr.en_hist = o.NoIdeal(2); ovr.en_q = o.NoIdeal(3);
end
assignin('base', 'ovr_pil3', ovr);
sobre = onCleanup(@() evalin('base', 'clear ovr_pil3')); %#ok<NASGU>

here = fileparts(mfilename('fullpath')); cd(here);
switch lower(modo)
    case 'mil', mdl = 'Model_aaron';
    case 'pil', mdl = 'Model_aaronC';
    otherwise, error('modo debe ser ''mil'' o ''pil''');
end
if strcmpi(modo, 'pil')
    if isempty(o.Puerto), pil3_puerto; else, pil3_puerto(o.Puerto); end
end
evalin('base', sprintf('run(''%s'')', fullfile(here, 'iniciar_pil3.m')));   % el InitFcn también lo hace; aquí queda a la vista
load_system(mdl);

% Estado original, para restaurarlo al terminar (o si algo falla)
bR = [mdl '/Gain']; bP = [mdl '/Gain1']; bHs = [mdl '/P-M SPECTRUM/Constant1'];
ph = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles');
pRoll = ph.Outport(1); pPitch = ph.Outport(3);         % Roll_X_cal, Pitch_Y_cal
ant = {get_param(bR,'Gain'), get_param(bP,'Gain'), get_param(bHs,'Value'), get_param(mdl,'SignalLogging'), ...
       get_param(pRoll,'DataLogging'), get_param(pPitch,'DataLogging'), get_param(mdl,'StopTime')};
limpiar = onCleanup(@() restaurar(mdl, bR, bP, bHs, pRoll, pPitch, ant)); %#ok<NASGU>

set_param(bR, 'Gain', num2str(o.K)); set_param(bP, 'Gain', num2str(o.K));
set_param(bHs, 'Value', num2str(o.Hs));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', 'StopTime', num2str(o.Tsim));
set_param(pRoll,  'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'roll_mesa');
set_param(pPitch, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'pitch_mesa');

fprintf('%s | Kp=%g Ki=%g Usat=%g | K=%g Hs=%g | no idealidades [lin hist q] = [%d %d %d]\n', ...
    upper(modo), evalin('base','Kp'), evalin('base','Ki'), evalin('base','Usat'), o.K, o.Hs, ...
    evalin('base','en_lin'), evalin('base','en_hist'), evalin('base','en_q'));
tic; out = sim(mdl); fprintf('Simulación lista en %.1f s\n', toc);

[tr, xr] = leer(out.logsout, 'roll_mesa'); [tp, xp] = leer(out.logsout, 'pitch_mesa');
xr = xr*180/pi; xp = xp*180/pi; ir = tr >= o.TIni; ip = tp >= o.TIni;
res = struct('modo', lower(modo), 't', tr, 'roll_deg', xr, 'pitch_deg', xp, ...
    'pico_roll', max(abs(xr(ir))), 'pico_pitch', max(abs(xp(ip))), ...
    'rms_roll', sqrt(mean(xr(ir).^2)), 'rms_pitch', sqrt(mean(xp(ip).^2)));
fprintf('Roll : pico %.3f deg, RMS %.3f deg\nPitch: pico %.3f deg, RMS %.3f deg   (requisito 0.20 deg)\n', ...
    res.pico_roll, res.rms_roll, res.pico_pitch, res.rms_pitch);

if o.Figura
    f = figure('Name', ['correr_pil3 ' modo], 'NumberTitle', 'off'); theme(f, 'light');
    plot(tr, xr, tp, xp); grid on; yline([-0.2 0.2], 'r--');
    xlabel('t (s)'); ylabel('inclinación de la mesa (°)'); legend('roll', 'pitch', 'requisito \pm0.2°');
    title(sprintf('%s: pico pitch %.3f°, roll %.3f°', upper(modo), res.pico_pitch, res.pico_roll));
end
end

function [t, x] = leer(lg, nombre)
s = lg.getElement(nombre); t = s.Values.Time; x = squeeze(s.Values.Data);
end

function restaurar(mdl, bR, bP, bHs, pRoll, pPitch, a)
set_param(bR, 'Gain', a{1}); set_param(bP, 'Gain', a{2}); set_param(bHs, 'Value', a{3});
set_param(pRoll, 'DataLogging', a{5}); set_param(pPitch, 'DataLogging', a{6});
set_param(mdl, 'SignalLogging', a{4}, 'StopTime', a{7});
end
