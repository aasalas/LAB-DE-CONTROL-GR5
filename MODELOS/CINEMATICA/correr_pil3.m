function res = correr_pil3(modo, varargin)
% CORRER_PIL3  Simula la plataforma completa y mide la inclinación residual de la mesa.
%   correr_pil3('mil')                  MiL: Model_aaron.slx (controlador en el PC, sin Arduino)
%   correr_pil3('pil')                  PiL: Model_aaronC.slx (controlador en el Arduino)
%   correr_pil3('pil', 'Puerto', "COM8")
%   correr_pil3('mil', 'K', 10, 'Hs', 1, 'Tsim', 30)
%   correr_pil3('pil', 'NoIdeal', [1 1 1 1])            sensor no ideal, sin editar archivos
% Opciones: K (lazo de nivelación, 15), Hs (altura significativa, 2 m), Tsim (30 s),
%   TIni (2 s, se ignora el arranque), Puerto (último disponible), Figura (true),
%   Kp, Ki, Usat y NoIdeal = [lin hist q ruido] (por defecto los de config_pil3.m).
% Las ganancias del PI y las no idealidades se editan en config_pil3.m.
% Devuelve las inclinaciones pico y RMS de la mesa [grados], u_rms y sat_pct (por válvula) y las señales.
p = inputParser;
addParameter(p, 'K', 15); addParameter(p, 'Hs', 2); addParameter(p, 'Tsim', 30);
addParameter(p, 'TIni', 2); addParameter(p, 'Puerto', []); addParameter(p, 'Figura', true);
addParameter(p, 'Kp', []); addParameter(p, 'Ki', []); addParameter(p, 'Usat', []); addParameter(p, 'NoIdeal', []);
parse(p, varargin{:}); o = p.Results;

% Sobrescrituras de config_pil3.m: las lee config_pil3 desde el workspace base
ovr = struct();
for c = {'Kp', 'Ki', 'Usat'}, if ~isempty(o.(c{1})), ovr.(c{1}) = o.(c{1}); end, end
if ~isempty(o.NoIdeal)
    ovr.en_lin = o.NoIdeal(1); ovr.en_hist = o.NoIdeal(2); ovr.en_q = o.NoIdeal(3);
    if numel(o.NoIdeal) > 3, ovr.en_ruido = o.NoIdeal(4); else, ovr.en_ruido = 0; end
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
pU = get_param([mdl '/Controlador'], 'PortHandles').Outport(1);   % comando de las tres válvulas
ant = {get_param(bR,'Gain'), get_param(bP,'Gain'), get_param(bHs,'Value'), get_param(mdl,'SignalLogging'), ...
       get_param(pRoll,'DataLogging'), get_param(pPitch,'DataLogging'), get_param(mdl,'StopTime'), get_param(pU,'DataLogging')};
limpiar = onCleanup(@() restaurar(mdl, bR, bP, bHs, pRoll, pPitch, pU, ant)); %#ok<NASGU>

set_param(bR, 'Gain', num2str(o.K)); set_param(bP, 'Gain', num2str(o.K));
set_param(bHs, 'Value', num2str(o.Hs));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', 'StopTime', num2str(o.Tsim));
set_param(pRoll,  'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'roll_mesa');
set_param(pPitch, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'pitch_mesa');
set_param(pU,     'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', 'u_valvulas');

fprintf('%s | Kp=%g Ki=%g Usat=%g | K=%g Hs=%g | no idealidades [lin hist q ruido] = [%d %d %d %d]\n', ...
    upper(modo), evalin('base','Kp'), evalin('base','Ki'), evalin('base','Usat'), o.K, o.Hs, ...
    evalin('base','en_lin'), evalin('base','en_hist'), evalin('base','en_q'), evalin('base','en_ruido'));
tic;
try
    out = sim(mdl);
catch err
    if ~strcmpi(modo, 'pil'), rethrow(err); end
    % caché de compilación "al día" pero sin wrapper.mk: se limpia y se recompila una vez
    fprintf('Falló la compilación del PIL (%s)\nSe recompila ctrl_pi3 desde cero...\n', err.message);
    close_system('ctrl_pi3', 0); pil3_limpiar;
    if isempty(o.Puerto), pil3_puerto; else, pil3_puerto(o.Puerto); end
    out = sim(mdl);
end
fprintf('Simulación lista en %.1f s\n', toc);

[tr, xr] = leer(out.logsout, 'roll_mesa'); [tp, xp] = leer(out.logsout, 'pitch_mesa');
xr = xr*180/pi; xp = xp*180/pi; ir = tr >= o.TIni; ip = tp >= o.TIni;
res = struct('modo', lower(modo), 't', tr, 'roll_deg', xr, 'pitch_deg', xp, ...
    'pico_roll', max(abs(xr(ir))), 'pico_pitch', max(abs(xp(ip))), ...
    'rms_roll', sqrt(mean(xr(ir).^2)), 'rms_pitch', sqrt(mean(xp(ip).^2)));
% Esfuerzo de control: u_RMS y % del tiempo con |u| en el límite Usat, por válvula
[tu, xu] = leer(out.logsout, 'u_valvulas'); xu = double(xu); if size(xu,1) ~= numel(tu), xu = xu.'; end   % una columna por válvula
iu = tu >= o.TIni; Us = evalin('base', 'Usat');
res.t_u = tu; res.u = xu; res.Usat = Us;
res.u_rms = sqrt(mean(xu(iu,:).^2, 1)); res.sat_pct = 100*mean(abs(xu(iu,:)) >= 0.999*Us, 1);
fprintf('Roll : pico %.3f deg, RMS %.3f deg\nPitch: pico %.3f deg, RMS %.3f deg   (requisito 1 deg)\n', ...
    res.pico_roll, res.rms_roll, res.pico_pitch, res.rms_pitch);
fprintf('u_RMS por válvula: %s | %% del tiempo saturada: %s\n', mat2str(res.u_rms, 3), mat2str(res.sat_pct, 3));

if o.Figura
    f = figure('Name', ['correr_pil3 ' modo], 'NumberTitle', 'off'); theme(f, 'light');
    plot(tr, xr, tp, xp); grid on; yline([-1 1], 'r--');
    xlabel('t (s)'); ylabel('inclinación de la mesa (°)'); legend('roll', 'pitch', 'requisito \pm1°');
    title(sprintf('%s: pico pitch %.3f°, roll %.3f°', upper(modo), res.pico_pitch, res.pico_roll));
end
end

function [t, x] = leer(lg, nombre)
s = lg.getElement(nombre); t = s.Values.Time; x = squeeze(s.Values.Data);
end

function restaurar(mdl, bR, bP, bHs, pRoll, pPitch, pU, a)
set_param(bR, 'Gain', a{1}); set_param(bP, 'Gain', a{2}); set_param(bHs, 'Value', a{3});
set_param(pRoll, 'DataLogging', a{5}); set_param(pPitch, 'DataLogging', a{6});
set_param(pU, 'DataLogging', a{8});
set_param(mdl, 'SignalLogging', a{4}, 'StopTime', a{7});
end
