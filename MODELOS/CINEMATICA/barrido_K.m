function res = barrido_K(Ks, Hs, Tsim)
% BARRIDO_K  Barre la ganancia K de las realimentaciones de roll y pitch y mide
%            el pico de inclinacion de la mesa en cada corrida (MiL, sin Arduino).
%   barrido_K                       % K = [0 5 10 15 20], Hs = 0.5 m, 15 s
%   barrido_K([0 10 15 20 25])      % otros valores de K
% El modelo queda como estaba al terminar (ganancias, Hs y registro de senales).

if nargin < 1, Ks   = [20 25 30]; end
if nargin < 2, Hs   = 0.5;            end
if nargin < 3, Tsim = 30;             end
if ~any(Ks == 0), Ks = [0 Ks]; end            % K = 0 es la linea base (mesa sin compensar)

mdl   = 'Model_aaronC';
cfg   = struct('Kp',6.7,'Ki',1,'Usat',0.1);   % ganancias de los PI de los pistones
en    = [0 0 0];                              % sin no idealidades del sensor
t_ini = 2;                                    % [s] se ignora el arranque de los pistones

load_system(mdl);
bR  = [mdl '/Gain'];   bP = [mdl '/Gain1'];   bH = [mdl '/Gain2'];   % roll, pitch, heave
bHs = [mdl '/P-M SPECTRUM/Constant1'];                              % Hs del oleaje
ph  = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles');
pRoll = ph.Outport(1);   pPitch = ph.Outport(3);                    % Roll_X_cal, Pitch_Y_cal

% Guarda el estado original para restaurarlo al terminar (o si algo falla)
o.R  = get_param(bR,'Gain');    o.P = get_param(bP,'Gain');    o.H = get_param(bH,'Gain');
o.Hs = get_param(bHs,'Value');  o.SL = get_param(mdl,'SignalLogging');
o.dlR = get_param(pRoll,'DataLogging');   o.dlP = get_param(pPitch,'DataLogging');
limpiar = onCleanup(@() restaurar(mdl,bR,bP,bH,bHs,pRoll,pPitch,o)); %#ok<NASGU>

set_param(mdl,'SignalLogging','on','SignalLoggingName','logsout');
set_param(pRoll, 'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','roll_mesa');
set_param(pPitch,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','pitch_mesa');
set_param(bH,'Gain','0');                     % heave apagado
set_param(bHs,'Value',num2str(Hs));

n = numel(Ks);   pr = zeros(n,1);   pp = zeros(n,1);
for i = 1:n
    set_param(bR,'Gain',num2str(Ks(i)));
    set_param(bP,'Gain',num2str(Ks(i)));
    pil3_iniciar(0, cfg, en);                 % MiL: reinicia los estados del controlador
    fprintf('K = %g ... ', Ks(i));
    out = sim(mdl, 'StopTime', num2str(Tsim));
    [tr,xr] = leer(out.logsout, 'roll_mesa');
    [tp,xp] = leer(out.logsout, 'pitch_mesa');
    pr(i) = max(abs(xr(tr >= t_ini))) * 180/pi;
    pp(i) = max(abs(xp(tp >= t_ini))) * 180/pi;
    fprintf('pico roll %.3f deg, pico pitch %.3f deg\n', pr(i), pp(i));
end

i0 = find(Ks == 0, 1);
fprintf('\n    K | pico roll [deg] | pico pitch [deg] | pitch frente a K=0\n');
for i = 1:n
    fprintf('%5g | %15.3f | %16.3f | %10.0f %%\n', Ks(i), pr(i), pp(i), 100*pp(i)/pp(i0));
end
fprintf('Requisito: 0.20 deg\n');

figure; hold on; grid on
plot(Ks, pp, 'o-', Ks, pr, 's-');
plot([min(Ks) max(Ks)], [0.2 0.2], 'r--');
xlabel('K'); ylabel('pico de inclinacion de la mesa [deg]');
legend({'pitch','roll','requisito 0.2 deg'}, 'Location', 'northeast');

res = struct('K', Ks(:), 'pico_roll_deg', pr, 'pico_pitch_deg', pp);
end

function [t,x] = leer(lg, nombre)
s = lg.getElement(nombre);
t = s.Values.Time;
x = squeeze(s.Values.Data);
end

function restaurar(mdl,bR,bP,bH,bHs,pRoll,pPitch,o)
set_param(bR,'Gain',o.R);   set_param(bP,'Gain',o.P);   set_param(bH,'Gain',o.H);
set_param(bHs,'Value',o.Hs);
set_param(pRoll,'DataLogging',o.dlR);   set_param(pPitch,'DataLogging',o.dlP);
set_param(mdl,'SignalLogging',o.SL);
end