function res = comparar_pil(K, Hs, Tsim, puerto)
% COMPARAR_PIL  MiL vs PiL ideal vs PiL no ideal con el mismo K (pico de la mesa).
%   comparar_pil(25)                      % Hs = 0.5, 120 s, puerto automatico
%   comparar_pil(25, 0.5, 120, "COM6")
global PIL
if nargin < 2 || isempty(Hs),   Hs   = 0.5; end
if nargin < 3 || isempty(Tsim), Tsim = 120; end
if nargin < 4,                  puerto = []; end

mdl   = 'Model_aaronC';
cfg   = struct('Kp',6.7,'Ki',1,'Usat',0.1);          % mismas ganancias que el barrido
t_ini = 2;
casos = {'MiL ideal',0,[0 0 0]; 'PiL ideal',1,[0 0 0]; 'PiL no ideal',1,[1 1 1]};

load_system(mdl);
bR = [mdl '/Gain'];  bP = [mdl '/Gain1'];  bH = [mdl '/Gain2'];
bHs = [mdl '/P-M SPECTRUM/Constant1'];
ph = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles');
pRoll = ph.Outport(1);  pPitch = ph.Outport(3);

o.R = get_param(bR,'Gain');  o.P = get_param(bP,'Gain');  o.H = get_param(bH,'Gain');
o.Hs = get_param(bHs,'Value');  o.SL = get_param(mdl,'SignalLogging');
o.dlR = get_param(pRoll,'DataLogging');  o.dlP = get_param(pPitch,'DataLogging');
limpiar = onCleanup(@() restaurar(mdl,bR,bP,bH,bHs,pRoll,pPitch,o)); %#ok<NASGU>

set_param(mdl,'SignalLogging','on','SignalLoggingName','logsout');
set_param(pRoll, 'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','roll_mesa');
set_param(pPitch,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName','pitch_mesa');
set_param(bR,'Gain',num2str(K));  set_param(bP,'Gain',num2str(K));
set_param(bH,'Gain','0');         set_param(bHs,'Value',num2str(Hs));

n = size(casos,1);
pr = zeros(n,1); pp = zeros(n,1); ne = zeros(n,1); dr = zeros(n,1); dp = zeros(n,1);
sp = [];
try
    for i = 1:n
        fprintf('%s ... ', casos{i,1});
        sp  = pil3_iniciar(casos{i,2}, cfg, casos{i,3}, puerto);
        out = sim(mdl, 'StopTime', num2str(Tsim));
        if ~isempty(sp), delete(sp); sp = []; end          % libera el puerto
        [tr,xr] = leer(out.logsout, 'roll_mesa');
        [tp,xp] = leer(out.logsout, 'pitch_mesa');
        pr(i) = max(abs(xr(tr >= t_ini))) * 180/pi;
        pp(i) = max(abs(xp(tp >= t_ini))) * 180/pi;
        ne(i) = PIL.nerr;
        if i == 1, r0 = {tr,xr};  p0 = {tp,xp}; end
        dr(i) = difrms(tr,xr,r0{1},r0{2},t_ini);
        dp(i) = difrms(tp,xp,p0{1},p0{2},t_ini);
        fprintf('pico roll %.3f, pitch %.3f deg, errores UART %d\n', pr(i), pp(i), ne(i));
    end
catch ME
    if ~isempty(sp), delete(sp); end
    rethrow(ME);
end

fprintf('\nK = %g, Hs = %g m, %g s\n', K, Hs, Tsim);
fprintf('%-13s | roll [deg] | pitch [deg] | errores | dif RMS vs MiL roll/pitch [deg]\n', 'caso');
for i = 1:n
    fprintf('%-13s | %10.3f | %11.3f | %7d | %7.4f / %7.4f\n', casos{i,1}, pr(i), pp(i), ne(i), dr(i), dp(i));
end
fprintf('Requisito: 0.20 deg\n');
res = table(casos(:,1), pr, pp, ne, dr, dp, 'VariableNames', ...
    {'caso','pico_roll_deg','pico_pitch_deg','errores_uart','dif_roll_deg','dif_pitch_deg'});
end

function [t,x] = leer(lg, nombre)
s = lg.getElement(nombre);
t = s.Values.Time;  x = squeeze(s.Values.Data);
end

function d = difrms(t,x,t0,x0,t_ini)
[tu,iu] = unique(t);   [t0u,i0u] = unique(t0);
tt = tu(tu >= t_ini);
d  = sqrt(mean((interp1(tu,x(iu),tt) - interp1(t0u,x0(i0u),tt)).^2)) * 180/pi;
end

function restaurar(mdl,bR,bP,bH,bHs,pRoll,pPitch,o)
set_param(bR,'Gain',o.R);  set_param(bP,'Gain',o.P);  set_param(bH,'Gain',o.H);
set_param(bHs,'Value',o.Hs);
set_param(pRoll,'DataLogging',o.dlR);  set_param(pPitch,'DataLogging',o.dlP);
set_param(mdl,'SignalLogging',o.SL);
end