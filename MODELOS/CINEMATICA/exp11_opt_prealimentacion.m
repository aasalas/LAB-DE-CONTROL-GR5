function R = exp11_opt_prealimentacion(modo)
% EXP11_OPT_PREALIMENTACION  Optimización de Kp, Ki y presión de suministro para la arquitectura B
% (prealimentación pura: IMU de la base -> cinemática inversa -> 3 PI; sin K, sin saturación).
%   exp11_opt_prealimentacion            todo (~10 min la primera vez; las etapas 0 y 1 quedan en caché)
%   exp11_opt_prealimentacion('barrido') solo el barrido en el modelo sustituto (segundos; usa la caché)
%   exp11_opt_prealimentacion('figura')  rehace la figura desde exp11_opt.mat
% Etapas:
%   0. Identificación del pistón por presión (160 a 500 bar): curva v(u), tau y theta.   [caché]
%   1. Corrida base de la plataforma: B, base de 15°, Kp = 20, Ki = 1, 160 bar.               [caché]
%   2. Barrido en un modelo sustituto del pistón (PI discreto + válvula + curva v(u)), con las
%      referencias de los pistones sintetizadas fuera de Simulink. Objetivo: pico de pitch de la mesa
%      con la base de 15° (desempate: nominal). Restricciones: MG >= 10 dB, MF >= 60°, Mp <= 10 % y
%      ts <= 2 s (G lineal, escalón), pistones dentro de los topes (0.005-0.445 m).
%   3. Regla completa de diseno_pi en el modelo no lineal de un pistón (PiL.slx) para los 3 mejores
%      de cada presión y el PI actual.
%   4. Validación en la plataforma completa del mejor a 160 bar y del mejor global.
% No modifica ningún modelo ni config_pil3.m: todo se cambia en memoria y se cierra sin guardar.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp11_*.mat/.csv y figuras/exp11_barrido.png
if nargin < 1, modo = 'todo'; end
cin = fileparts(mfilename('fullpath'));
res_dir = fullfile(cin, '..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'resultados');
fig_dir = fullfile(cin, '..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'figuras');
f_id = fullfile(res_dir, 'exp11_ident.mat'); f_base = fullfile(res_dir, 'exp11_base.mat');
f_opt = fullfile(res_dir, 'exp11_opt.mat');
P_BAR = [160 200 250 315 400 500];   % el CDH1 es de 250 bar nominales (375 de prueba)
KP = 10:2.5:60; KI = [0 1 2 4 6 8 12 16 24 32 48 64];
OLA15 = [15.49 12]; NOMINAL = [2 10]; TSIM = 30;
warning('off', 'all'); restaura_w = onCleanup(@() warning('on', 'all'));
if strcmp(modo, 'figura'), load(f_opt, 'R'); figura(R.G, R.sel, fig_dir); return, end

%% Etapa 0: identificación por presión
if isfile(f_id), load(f_id, 'ID'); fprintf('Etapa 0: identificación en caché\n');
else
    assert(~strcmp(modo, 'barrido'), 'Falta la caché de la etapa 0: corra exp11_opt_prealimentacion sin argumentos');
    ID = identificar(cin, P_BAR); save(f_id, 'ID');
end
for k = 1:numel(ID)
    fprintf('  %3d bar: Kv ext %.3f, ret %.3f m/s | u = ±1: %.3f / %.3f m/s | tau %.1f ms, theta %.1f ms\n', ID(k).p_bar, ...
        ID(k).Kv_ext, ID(k).Kv_ret, ID(k).F(1), -ID(k).F(-1), 1e3*ID(k).tau, 1e3*ID(k).theta);
end

%% Etapa 1: corrida base de la plataforma
if isfile(f_base), load(f_base, 'base'); fprintf('Etapa 1: corrida base en caché\n');
else
    assert(~strcmp(modo, 'barrido'), 'Falta la caché de la etapa 1');
    base = correr_B(cin, 20, 1, 160, OLA15, TSIM); save(f_base, 'base');
end
fprintf('  base (20/1, 160 bar, 15°): pitch %.3f°, roll %.3f° | error de seguimiento máx %s mm\n', ...
    base.pico_pitch, base.pico_roll, mat2str(round(1e3*base.e_max, 1)));

%% Etapa 2: barrido en el sustituto
fprintf('\nEtapa 2: barrido (%d candidatos)\n', numel(KP)*numel(KI)*numel(P_BAR)); t2 = tic;
ola15 = referencias(OLA15(1), OLA15(2), TSIM); olanom = referencias(NOMINAL(1), NOMINAL(2), TSIM);
d_ref = max(abs(ola15.xr - base.xr_10ms(1:size(ola15.xr, 1), :)), [], 'all');
fprintf('  referencias sintetizadas contra la corrida base: diferencia máx %.3f mm\n', 1e3*d_ref);
% calibración: con y sin limitador de pendiente de la válvula; se queda el más cercano a la corrida base
id160 = ID([ID.p_bar] == 160);
cal = struct('rl', {true, false}, 'e_max', [], 'err', []);
for c = 1:2
    s = sustituto(ola15.xr, 20, 1, id160, cal(c).rl);
    cal(c).e_max = squeeze(max(abs(s.E(ola15.t >= 2, 1, :)), [], 1))';
    cal(c).err = 100*(cal(c).e_max./base.e_max - 1);
    fprintf('  sustituto %s limitador: error máx %s mm (%s %% respecto de la plataforma)\n', ...
        ternario(cal(c).rl, 'con', 'sin'), mat2str(round(1e3*cal(c).e_max, 1)), mat2str(round(cal(c).err)));
end
[~, ic] = min(arrayfun(@(c) max(abs(c.err)), cal)); RL = cal(ic).rl;
fprintf('  se usa el sustituto %s limitador (error de calibración máx %.0f %%)\n', ternario(RL, 'con', 'sin'), max(abs(cal(ic).err)));
if max(abs(cal(ic).err)) > 15, fprintf(2, '  AVISO: la calibración pasa de ±15 %%: el orden de los candidatos es indicativo\n'); end
s0 = sustituto(ola15.xr, 20, 1, id160, RL); [pp0, pr0] = angulos(s0.E, ola15, ola15.t >= 2);
fprintf('  ángulo de la mesa, sustituto contra plataforma: pitch %.3f° / %.3f°, roll %.3f° / %.3f°\n', ...
    pp0, base.pico_pitch, pr0, base.pico_roll);
% Mp del escalón de 10 mm: sustituto contra el modelo no lineal (diseno_pi.csv)
Tdp = readtable(fullfile(cin, '..', 'PISTON', 'resultados', 'diseno_pi.csv'));
st = escalon_sustituto(Tdp.Kp, Tdp.Ki, id160, RL);
fprintf('  Mp del escalón de 10 mm, sustituto contra no lineal: error medio %.1f puntos (máx %.1f)\n', ...
    mean(abs(st.Mp - Tdp.Mp_10mm), 'omitnan'), max(abs(st.Mp - Tdp.Mp_10mm)));

[kp, ki] = ndgrid(KP, KI); kp = kp(:); ki = ki(:); n = numel(kp);
G = table();
for k = 1:numel(ID)
    id = ID(k);
    s15 = sustituto(ola15.xr, kp, ki, id, RL); [pp15, pr15] = angulos(s15.E, ola15, ola15.t >= 2);
    sn = sustituto(olanom.xr, kp, ki, id, RL); [ppn, prn] = angulos(sn.E, olanom, olanom.t >= 2);
    se = escalon_sustituto(kp, ki, id, RL);
    li = lineal(kp, ki, id);
    g = table(repmat(id.p_bar, n, 1), kp, ki, pp15, pr15, ppn, prn, 1e3*max(s15.e_max, [], 2), ...
        max(s15.u_max, [], 2), max(s15.sat_pct, [], 2), min(s15.x_min, [], 2), max(s15.x_max, [], 2), ...
        se.Mp, se.ts, li.MG_dB, li.MF, li.Mp, li.ts, 'VariableNames', {'p_bar', 'Kp', 'Ki', 'pitch15', 'roll15', ...
        'pitch_nom', 'roll_nom', 'e_max_mm', 'u_max', 'sat_pct', 'x_min', 'x_max', 'Mp_sust', 'ts_sust', ...
        'MG_dB', 'MF_deg', 'Mp_lin', 'ts_lin'});
    G = [G; g]; %#ok<AGROW>
end
% el Mp del escalón en el sustituto se desvía ~16 puntos del modelo no lineal: es informativo; el Mp
% real lo revisa la etapa 3. La carrera se limita a los topes físicos (la referencia de 15° ya llega a 15 mm).
G.cumple = G.MG_dB >= 10 & G.MF_deg >= 60 & G.Mp_lin <= 10 & G.ts_lin <= 2 & ...
    G.x_min >= 0.005 & G.x_max <= 0.445;
% factor de escala del sustituto: el pico de la mesa se informa corregido por la corrida base
G.pitch15_corr = G.pitch15*base.pico_pitch/pp0;
fprintf('  barrido listo en %.0f s: %d de %d candidatos cumplen las restricciones\n', toc(t2), nnz(G.cumple), n*numel(ID));
for k = 1:numel(ID)
    Gk = sortrows(G(G.cumple & G.p_bar == ID(k).p_bar, :), {'pitch15', 'pitch_nom'});
    fprintf('  %3d bar, mejores: %s\n', ID(k).p_bar, strjoin(compose('%g/%g (%.2f°)', Gk.Kp(1:min(3, end)), ...
        Gk.Ki(1:min(3, end)), Gk.pitch15_corr(1:min(3, end))), ', '));
end
R = struct('ID', ID, 'G', G, 'cal', cal, 'RL', RL, 'base', base);
if strcmp(modo, 'barrido')
    figura(G, [], fig_dir); writetable(G, fullfile(res_dir, 'exp11_opt.csv')); return
end

%% Etapa 3: regla completa en el modelo no lineal de un pistón
% Ni la G lineal ni el sustituto predicen el sobrepaso del escalón de 10 mm en el modelo no lineal (con Ki
% alto pasa de 10 %). Por eso, para cada presión y cada Ki se busca por bisección el mayor Kp que cumple
% el escalón de 10 mm en el modelo no lineal (el sobrepaso crece con Kp), y entre esa frontera se elige el
% de menor pitch a 15°. Al elegido de cada presión (y al PI actual) se le aplica la regla completa.
fprintf('\nEtapa 3: frontera de la regla en el modelo no lineal de un pistón\n'); t3 = tic;
F = frontera(cin, G, [0 1 2 4 8 16 32]);
sel = table();
for k = 1:numel(ID)
    Fk = sortrows(F(F.p_bar == ID(k).p_bar, :), {'pitch15', 'pitch_nom'});
    if ~isempty(Fk), sel = [sel; Fk(1, :)]; end %#ok<AGROW>
end
sel = [G(G.p_bar == 160 & G.Kp == 20 & G.Ki == 1, :); sel(:, G.Properties.VariableNames)];
V = verificar(cin, sel);
sel = [sel V];
fprintf('  etapa 3 lista en %.0f s\n', toc(t3));
writetable(F, fullfile(res_dir, 'exp11_frontera.csv')); R.frontera = F;
disp(sel(:, {'p_bar', 'Kp', 'Ki', 'pitch15_corr', 'Mp_10mm', 'ts_10mm', 'Mp_400mm', 'ts_400mm', 'ess_mm', 'regla'}));

%% Etapa 4: validación en la plataforma completa
fprintf('\nEtapa 4: validación en la plataforma completa\n');
ok = sel(sel.regla & ~(sel.p_bar == 160 & sel.Kp == 20 & sel.Ki == 1), :);
val = struct([]);
if isempty(ok), fprintf(2, 'Ningún candidato cumple la regla completa: no se valida\n');
else
    ok = sortrows(ok, {'pitch15', 'pitch_nom'});
    casos = cell(0, 3);
    for pb = [160 250]                                 % 160 bar: solo cambia el PI; 250 bar: máximo del CDH1
        b = ok(ok.p_bar == pb, :);
        if ~isempty(b)
            casos(end+1, :) = {b(1, :), OLA15, sprintf('mejor %d bar, 15°', pb)}; %#ok<AGROW>
            casos(end+1, :) = {b(1, :), NOMINAL, sprintf('mejor %d bar, nominal', pb)}; %#ok<AGROW>
        end
    end
    if ~ismember(ok.p_bar(1), [160 250]), casos(end+1, :) = {ok(1, :), OLA15, 'mejor global, 15°'}; end
    for c = 1:size(casos, 1)
        q = casos{c, 1}; fprintf('  %s: Kp = %g, Ki = %g, %d bar\n', casos{c, 3}, q.Kp, q.Ki, q.p_bar);
        v = correr_B(cin, q.Kp, q.Ki, q.p_bar, casos{c, 2}, TSIM);
        v.caso = casos{c, 3}; v.Kp = q.Kp; v.Ki = q.Ki; v.p_bar = q.p_bar; v.pred_pitch = q.pitch15_corr;
        val = [val v]; %#ok<AGROW>
        fprintf('    pitch %.3f°, roll %.3f° | pistones en [%.3f, %.3f] m | |u| máx %.2f\n', v.pico_pitch, ...
            v.pico_roll, v.x_min, v.x_max, max(v.u_max));
    end
end
R.sel = sel; R.val = val;
save(f_opt, 'R'); writetable(G, fullfile(res_dir, 'exp11_opt.csv'));
writetable(sel, fullfile(res_dir, 'exp11_verificados.csv'));
figura(G, sel, fig_dir);
end

%% ===================================================================================== funciones
function ID = identificar(cin, P_BAR)
% Curva estática v(u), tau y theta del pistón para cada presión (arnés de MODELOS/PISTON/diseno_pi.m).
fprintf('Etapa 0: identificación por presión\n');
pis = fullfile(cin, '..', 'PISTON'); vuelve = onCleanup(@() cd(cin)); cd(pis);
evalin('base', sprintf('run(''%s'')', fullfile(cin, 'MARLUP_hydr_params.m')));
evalin('base', 'cyl.x_init = 0.23; sens = struct(''bias'', 0, ''backlash'', 0, ''q'', 1e-12, ''xmin'', -inf, ''xmax'', inf);');
m = 'PiL'; load_system(m);
h = 'tmp_exp11'; if bdIsLoaded(h), close_system(h, 0); end
new_system(h); cierra = onCleanup(@() cerrar({h, m}));
add_block([m '/PISTON MODEL'], [h '/P']); add_block('simulink/Sources/Step', [h '/S']);
set_param([h '/S'], 'Time', '0.3', 'Before', '0'); add_line(h, 'S/1', 'P/1');
add_block('simulink/Sinks/To Workspace', [h '/wv'], 'VariableName', 'v', 'SaveFormat', 'Array'); add_line(h, 'P/5', 'wv/1');
for i = [1 2 3 4 6], add_block('simulink/Sinks/Terminator', sprintf('%s/t%d', h, i)); add_line(h, sprintf('P/%d', i), sprintf('t%d/1', i)); end
set_param(h, 'Solver', 'ode4', 'FixedStep', '1e-4', 'StopTime', '0.6');
U = [-1 -0.75 -0.5 -0.35 -0.2 -0.1 -0.05 -0.02 0.02 0.05 0.1 0.2 0.35 0.5 0.75 1];
ID = struct('p_bar', {}, 'U', {}, 'V', {}, 'F', {}, 'Kv_ext', {}, 'Kv_ret', {}, 'tau', {}, 'theta', {});
for p = P_BAR
    evalin('base', sprintf('p_supply = %g;', p*1e5));
    vs = zeros(size(U)); en = {};
    for j = 1:numel(U)
        set_param([h '/S'], 'After', num2str(U(j)));
        out = sim(h, 'ReturnWorkspaceOutputs', 'on'); t = out.tout; v = out.v;
        v0 = mean(v(t > 0.25 & t < 0.3)); vs(j) = mean(v(t > 0.5)) - v0;
        if abs(U(j)) <= 0.1
            i = t >= 0.3 & t <= 0.4; en{end+1} = struct('t', t(i) - 0.3, 'vn', (v(i) - v0)/vs(j)); %#ok<AGROW>
        end
    end
    mod_ = @(q, t) (t > q(2)).*(1 - exp(-max(t - q(2), 0)/q(1)));
    costo = @(q) sum(cellfun(@(e) sum((mod_(abs(q), e.t) - e.vn).^2), en));
    q = abs(fminsearch(costo, [0.005 0.010]));
    Uc = [U(1:8) 0 U(9:end)]; Vc = [vs(1:8) 0 vs(9:end)];
    ID(end+1) = struct('p_bar', p, 'U', Uc, 'V', Vc, 'F', griddedInterpolant(Uc, Vc, 'linear', 'nearest'), ...
        'Kv_ext', mean(vs(U > 0 & U <= 0.1)./U(U > 0 & U <= 0.1)), 'Kv_ret', mean(vs(U < 0 & U >= -0.1)./U(U < 0 & U >= -0.1)), ...
        'tau', q(1), 'theta', q(2)); %#ok<AGROW>
    fprintf('  %3d bar identificado\n', p);
end
evalin('base', 'p_supply = 160e5;');
end

function r = correr_B(cin, Kp, Ki, p_bar, ola, Tsim)
% Una corrida MiL de la arquitectura B (K = 0, Kff = 1, sin saturación) en memoria, sin guardar.
vuelve = onCleanup(@() cd(pwd)); cd(cin);
mdl = 'Model_aaron';
assignin('base', 'ovr_pil3', struct('Kff', 1, 'Kp', Kp, 'Ki', Ki, 'p_supply', p_bar*1e5, 'ver_mechanics', 0, ...
    'en_lin', 0, 'en_hist', 0, 'en_q', 0, 'en_ruido', 0));
limpia = onCleanup(@() evalin('base', 'clear ovr_pil3'));
evalin('base', sprintf('run(''%s'')', fullfile(cin, 'iniciar_pil3.m')));
load_system(mdl); cierra = onCleanup(@() close_system(mdl, 0));
set_param([mdl '/Gain'], 'Gain', '0'); set_param([mdl '/Gain1'], 'Gain', '0');
for s = {'Saturation', 'Saturation1'}, set_param([mdl '/' s{1}], 'UpperLimit', 'inf', 'LowerLimit', '-inf'); end
set_param([mdl '/P-M SPECTRUM/Constant1'], 'Value', num2str(ola(1), 8));
set_param([mdl '/P-M SPECTRUM/Constant2'], 'Value', num2str(ola(2)));
set_param(mdl, 'SignalLogging', 'on', 'SignalLoggingName', 'logsout', 'StopTime', num2str(Tsim), ...
    'SimMechanicsOpenEditorOnUpdate', 'off');
lg = @(h, nm) set_param(h, 'DataLogging', 'on', 'DataLoggingNameMode', 'Custom', 'DataLoggingName', nm);
pp = get_param([mdl '/PLATO SUPERIOR DEL ROBOT'], 'PortHandles'); lg(pp.Outport(1), 'roll'); lg(pp.Outport(3), 'pitch');
sums = {'Sum', 'Sum1', 'Sum2'};
for i = 1:3
    q = get_param(sprintf('%s/PISTON %d', mdl, i), 'PortHandles'); lg(q.Outport(1), sprintf('x%d', i));
    q = get_param([mdl '/' sums{i}], 'PortHandles'); lg(q.Outport(1), sprintf('xr%d', i));
end
cu = get_param([mdl '/Controlador'], 'PortHandles'); lg(cu.Outport(1), 'u');
tic; out = sim(mdl); r.t_s = toc;
g = @(nm) out.logsout.getElement(nm).Values;
p = g('pitch'); rl = g('roll'); j = p.Time >= 2;
r.t = p.Time; r.pitch = rad2deg(p.Data(:)); r.roll = rad2deg(rl.Data(:));
r.pico_pitch = max(abs(r.pitch(j))); r.pico_roll = max(abs(r.roll(j)));
r.rms_pitch = rms(r.pitch(j)); r.rms_roll = rms(r.roll(j));
t10 = (0:0.01:Tsim)'; r.xr_10ms = zeros(numel(t10), 3); r.e_max = zeros(1, 3); r.e_rms = zeros(1, 3);
r.x_min = inf; r.x_max = -inf;
for i = 1:3
    x = g(sprintf('x%d', i)); xr = g(sprintf('xr%d', i));
    xv = squeeze(x.Data); xrv = squeeze(double(xr.Data));
    r.xr_10ms(:, i) = interp1(xr.Time, xrv, t10, 'previous', 'extrap');
    e = interp1(xr.Time, xrv, x.Time, 'previous', 'extrap') - xv; k = x.Time >= 2;
    r.e_max(i) = max(abs(e(k))); r.e_rms(i) = rms(e(k));
    r.x_min = min(r.x_min, min(xv(k))); r.x_max = max(r.x_max, max(xv(k)));
end
u = g('u'); ud = squeeze(u.Data); if size(ud, 1) ~= numel(u.Time), ud = ud.'; end
r.u_max = max(abs(double(ud(u.Time >= 2, :))));
fprintf('    corrida de la plataforma: %.0f s\n', r.t_s);
end

function o = referencias(Hs, Tp, Tsim)
% Inclinación de la base (misma síntesis del bloque P-M SPECTRUM) y referencias de los pistones de B.
t = (0:0.01:Tsim)'; N = 100; M = 50; g = 9.81;
fp = 1/Tp; df = 4*fp/N; f = df:df:4*fp; om = 2*pi*f;
dth = 2*pi/M; th = dth:dth:2*pi;
s_ = rng; rng(42); fase = 2*pi*rand(N, M); rng(s_);
k = om.^2/g; kx = k'*cos(th); ky = k'*sin(th);
S = (5/16)*Hs^2*fp^4./f.^5.*exp(-1.25*(fp^4./f.^4));
D = (2/pi)*(cos(th/2)).^20; D(th < -pi/2 | th > pi/2) = 0;
A = sqrt(2*S'.*D*df*dth); Ax = A.*kx; Ay = A.*ky;
pb = zeros(size(t)); rb = pb;
for i = 1:numel(t)
    sn = sin(fase - om'*t(i)); pb(i) = atan(sum(Ax.*sn, 'all')); rb(i) = atan(sum(Ay.*sn, 'all'));
end
o.t = t; o.al = -rb; o.th = -pb; o.xr = zeros(numel(t), 3); o.Jinv = zeros(3, 3, numel(t));
for i = 1:numel(t)
    q = [o.al(i); o.th(i); 1.377];
    o.xr(i, :) = 0.23 + ik(q)';
    J = zeros(3); h = 1e-7;
    for c = 1:3, dq = q; dq(c) = dq(c) + h; J(:, c) = (ik(dq) - ik(q))/h; end
    o.Jinv(:, :, i) = inv(J);
end
end

function dL = ik(q)
% marlup_ik: (roll, pitch, z) -> elongación de las patas respecto de la pose ensamblada.
RB = 0.7608; RT = 0.143; Z0 = 1.377; PHI = [-30; 90; 210]*pi/180; L0 = hypot(RB - RT, Z0);
ca = cos(q(1)); sa = sin(q(1)); ct = cos(q(2)); st = sin(q(2));
R = [ct, sa*st, ca*st; 0, ca, -sa; -st, sa*ct, ca*ct];
dL = zeros(3, 1);
for i = 1:3
    d = R*([RT*cos(PHI(i)); RT*sin(PHI(i)); 0] + [0; 0; q(3)]) - [RB*cos(PHI(i)); RB*sin(PHI(i)); 0];
    dL(i) = norm(d) - L0;
end
end

function s = sustituto(xr, Kp, Ki, id, rl)
% Modelo sustituto de los 3 pistones para nc candidatos a la vez (paso de 1 ms):
% PI discreto a 10 ms (trapezoidal, clamping, ±1) -> [limitador 17/s] -> retardo theta -> v(u) -> 1/(tau s+1) -> 1/s
Kp = Kp(:); Ki = Ki(:); nc = numel(Kp); nT = size(xr, 1); dt = 1e-3; Ts = 0.01; RL = 17;
x = 0.23*ones(nc, 3); v = zeros(nc, 3); I = zeros(nc, 3); ep = zeros(nc, 3); u = zeros(nc, 3); y = u;
nd = max(1, round(id.theta/dt)); buf = zeros(nc, 3, nd); ib = 1; F = id.F; a = dt/id.tau;
s.E = zeros(nT, nc, 3); s.u_max = zeros(nc, 3); nsat = zeros(nc, 3);
s.x_min = inf(nc, 3); s.x_max = -inf(nc, 3);
for j = 1:nT
    e = xr(j, :) - x;                                   % muestreo a 10 ms
    s.E(j, :, :) = reshape(e, 1, nc, 3);
    if j > 200, s.x_min = min(s.x_min, x); s.x_max = max(s.x_max, x); end
    In = I + Ki*Ts.*(e + ep)/2; un = Kp.*e + In; u = min(max(un, -1), 1);
    libre = (u == un) | (sign(e) ~= sign(un)); I(libre) = In(libre); ep = e;
    if j > 200, s.u_max = max(s.u_max, abs(u)); nsat = nsat + (abs(u) >= 0.999); end
    if j == nT, break, end
    for k = 1:round(Ts/dt)
        if rl, y = y + min(max(u - y, -RL*dt), RL*dt); else, y = u; end
        ud = buf(:, :, ib); buf(:, :, ib) = y; ib = mod(ib, nd) + 1;
        v = v + a*(reshape(F(ud(:)), nc, 3) - v); x = x + dt*v;
    end
end
s.sat_pct = 100*nsat/max(1, nT - 200);
s.e_max = squeeze(max(abs(s.E(201:end, :, :)), [], 1));
if nc == 1, s.e_max = s.e_max(:)'; end
end

function [pp, pr] = angulos(E, o, j)
% Error de orientación de la mesa por el error de los pistones (cinemática linealizada en la pose pedida).
nT = size(E, 1); nc = size(E, 2); dal = zeros(nT, nc); dth = dal;
for i = 1:nT
    dq = o.Jinv(:, :, i)*(-reshape(E(i, :, :), nc, 3).');   % E = x_ref - x  ->  dl = x - x_ref
    dal(i, :) = dq(1, :); dth(i, :) = dq(2, :);
end
pp = rad2deg(max(abs(dth(j, :)), [], 1))'; pr = rad2deg(max(abs(dal(j, :)), [], 1))';
end

function r = escalon_sustituto(Kp, Ki, id, rl)
% Escalón de 10 mm en x0 = 0.23 m con el sustituto: sobrepaso [%] y establecimiento al 2 % [s].
nT = 301; xr = repmat(0.24, nT, 3); xr(1, :) = 0.23;
s = sustituto(xr, Kp, Ki, id, rl); y = (0.23 + 0*s.E(:, :, 1)) + 0.01 - s.E(:, :, 1);   % x = x_ref - e
y(1, :) = 0.23; yn = (y - 0.23)/0.01; t = (0:nT-1)'*0.01;
r.Mp = max(0, 100*(max(yn, [], 1) - 1))';
r.ts = zeros(numel(Kp), 1);
for c = 1:numel(Kp)
    f = find(abs(yn(:, c) - 1) > 0.02, 1, 'last');
    if isempty(f), r.ts(c) = 0; elseif f == nT, r.ts(c) = inf; else, r.ts(c) = t(f + 1); end
end
end

function r = lineal(Kp, Ki, id)
% Márgenes y escalón de la G lineal identificada a esa presión (como diseno_pi.m).
Ts = 0.01; Kv = (id.Kv_ext + id.Kv_ret)/2;
Gd = c2d(tf(Kv, [id.tau 1 0], 'IODelay', id.theta), Ts, 'zoh');
n = numel(Kp); r.MG_dB = nan(n, 1); r.MF = r.MG_dB; r.Mp = r.MG_dB; r.ts = r.MG_dB;
for c = 1:n
    C = pid(Kp(c), Ki(c), 'Ts', Ts, 'IFormula', 'Trapezoidal'); L = C*Gd; T = feedback(L, 1);
    if ~isstable(T), continue, end
    am = allmargin(L); r.MG_dB(c) = 20*log10(min([am.GainMargin(am.GainMargin > 1) Inf]));
    r.MF(c) = min([am.PhaseMargin Inf]);
    [y, t] = step(T, 0:Ts:6); r.Mp(c) = max(0, 100*(max(y) - 1));
    f = find(abs(y - 1) > 0.02, 1, 'last');
    if isempty(f), r.ts(c) = 0; elseif f == numel(y), r.ts(c) = inf; else, r.ts(c) = t(f + 1); end
end
end

function V = verificar(cin, sel)
% Regla de diseno_pi en el modelo no lineal de un pistón: escalón de 10 mm en x0 y de 0 a 0.40 m.
pis = fullfile(cin, '..', 'PISTON'); vuelve = onCleanup(@() cd(cin)); cd(pis);
evalin('base', sprintf('run(''%s'')', fullfile(cin, 'MARLUP_hydr_params.m')));
evalin('base', 'sens = struct(''bias'', 0, ''backlash'', 0, ''q'', 1e-12, ''xmin'', -inf, ''xmax'', inf);');
m = 'PiL'; load_system(m); load_system('ctrl_pi'); cierra = onCleanup(@() cerrar({m, 'ctrl_pi'}));
set_param([m '/Controlador'], 'SimulationMode', 'Normal');
n = height(sel); V = table(nan(n, 1), nan(n, 1), nan(n, 1), nan(n, 1), nan(n, 1), false(n, 1), ...
    'VariableNames', {'Mp_10mm', 'ts_10mm', 'Mp_400mm', 'ts_400mm', 'ess_mm', 'regla'});
for c = 1:n
    evalin('base', sprintf('p_supply = %g;', sel.p_bar(c)*1e5));
    set_param('ctrl_pi/PI', 'P', num2str(sel.Kp(c), 10), 'I', num2str(sel.Ki(c), 10));
    a = escalon_nl(m, 0.23, 0.24, 1.5, 6); b = escalon_nl(m, 0, 0.40, 0.5, 5);
    V.Mp_10mm(c) = a.Mp; V.ts_10mm(c) = a.ts; V.Mp_400mm(c) = b.Mp; V.ts_400mm(c) = b.ts;
    V.ess_mm(c) = 1e3*max(abs([a.ess b.ess]));
    V.regla(c) = sel.cumple(c) && a.Mp <= 10 && a.ts <= 2 && b.Mp <= 10 && b.ts <= 2 && V.ess_mm(c) <= 2.3;
    fprintf('  %3d bar, %5.1f/%-4g: 10 mm Mp %5.1f %% ts %.2f s | 400 mm Mp %4.1f %% ts %.2f s | %s\n', sel.p_bar(c), ...
        sel.Kp(c), sel.Ki(c), a.Mp, a.ts, b.Mp, b.ts, ternario(V.regla(c), 'cumple', 'no cumple'));
end
evalin('base', 'p_supply = 160e5;');
end

function F = frontera(cin, G, KIf)
% Para cada presión y cada Ki de KIf: mayor Kp (entre los que cumplen márgenes y carrera en G) cuyo
% escalón de 10 mm en el modelo no lineal cumple Mp <= 10 %, ts <= 2 s y |e_ss| <= 2.3 mm. Bisección.
pis = fullfile(cin, '..', 'PISTON'); vuelve = onCleanup(@() cd(cin)); cd(pis);
evalin('base', sprintf('run(''%s'')', fullfile(cin, 'MARLUP_hydr_params.m')));
evalin('base', 'sens = struct(''bias'', 0, ''backlash'', 0, ''q'', 1e-12, ''xmin'', -inf, ''xmax'', inf);');
m = 'PiL'; load_system(m); load_system('ctrl_pi'); cierra = onCleanup(@() cerrar({m, 'ctrl_pi'}));
set_param([m '/Controlador'], 'SimulationMode', 'Normal');
F = table(); nsim = 0;
for pb = unique(G.p_bar)'
    evalin('base', sprintf('p_supply = %g;', pb*1e5));
    for ki = KIf
        g = sortrows(G(G.p_bar == pb & G.Ki == ki & G.cumple, :), 'Kp');
        if isempty(g), continue, end
        lo = 0; hi = height(g); mejor = 0; Mp = nan(hi, 1);   % mayor índice que cumple
        while lo < hi
            mid = ceil((lo + hi)/2);
            set_param('ctrl_pi/PI', 'P', num2str(g.Kp(mid), 10), 'I', num2str(ki, 10));
            a = escalon_nl(m, 0.23, 0.24, 1.5, 6); nsim = nsim + 1; Mp(mid) = a.Mp;
            if a.Mp <= 10 && a.ts <= 2 && abs(a.ess) <= 2.3e-3, lo = mid; mejor = mid; else, hi = mid - 1; end
        end
        if mejor > 0
            F = [F; g(mejor, :)]; %#ok<AGROW>
            fprintf('  %3d bar, Ki = %-3g: Kp máx %5.1f (Mp %4.1f %%) -> pitch 15° %.2f°\n', pb, ki, g.Kp(mejor), Mp(mejor), g.pitch15_corr(mejor));
        else
            fprintf('  %3d bar, Ki = %-3g: ningún Kp cumple\n', pb, ki);
        end
    end
end
fprintf('  %d simulaciones del escalón de 10 mm\n', nsim);
evalin('base', 'p_supply = 160e5;');
end

function r = escalon_nl(m, xa, xb, t0, tfin)
% Escalón de xa a xb en t0 con el modelo no lineal (lógica de simular() en diseno_pi.m).
evalin('base', sprintf('cyl.x_init = %.6f;', xa));
set_param([m '/Step1'], 'Time', num2str(t0), 'Before', num2str(xa), 'After', num2str(xb));
r = struct('Mp', NaN, 'ts', NaN, 'ess', NaN);
try, out = sim(m, 'StopTime', num2str(tfin), 'ReturnWorkspaceOutputs', 'on');
catch err, fprintf(2, '  simulación fallida: %s\n', err.message); return
end
nn = numel(out.log_x); t = (0:nn-1)'*0.01; x = double(out.log_x(:));
i = t >= t0; tt = t(i) - t0; yy = (x(i) - xa)/(xb - xa);
r.Mp = max(0, (max(yy) - 1)*100);
f = find(abs(yy - 1) > 0.02, 1, 'last');
if isempty(f), r.ts = 0; elseif f == numel(yy), r.ts = Inf; else, r.ts = tt(f + 1); end
r.ess = (1 - mean(yy(tt >= tt(end) - 0.5)))*(xb - xa);
end

function figura(G, sel, fig_dir)
% Pico de pitch de la mesa (base de 15°, corregido por la corrida base) contra Kp, por Ki y presión.
P = unique(G.p_bar); KI = unique(G.Ki); cm = parula(numel(KI) + 1);
f = figure('Visible', 'off', 'Position', [100 100 1900 800]); theme(f, 'light');
tl = tiledlayout(f, 2, ceil(numel(P)/2), 'TileSpacing', 'compact');
for k = 1:numel(P)
    ax = nexttile(tl); hold(ax, 'on'); grid(ax, 'on');
    for j = 1:numel(KI)
        g = G(G.p_bar == P(k) & G.Ki == KI(j), :);
        plot(ax, g.Kp, g.pitch15_corr, '-', 'Color', [cm(j, :) 0.35], 'HandleVisibility', 'off');
        c = g.cumple; plot(ax, g.Kp(c), g.pitch15_corr(c), 'o', 'Color', cm(j, :), 'MarkerFaceColor', cm(j, :), ...
            'MarkerSize', 4, 'DisplayName', sprintf('Ki = %g', KI(j)));
    end
    if ~isempty(sel)
        s = sel(sel.p_bar == P(k) & sel.regla, :);
        plot(ax, s.Kp, s.pitch15_corr, 'kp', 'MarkerSize', 12, 'LineWidth', 1.2, 'DisplayName', 'cumple la regla (no lineal)');
    end
    g0 = G(G.p_bar == 160 & G.Kp == 20 & G.Ki == 1, :);
    if P(k) == 160, plot(ax, 20, g0.pitch15_corr, 'rs', 'MarkerSize', 10, 'LineWidth', 1.5, 'DisplayName', 'PI actual (20/1)'); end
    title(ax, sprintf('%d bar', P(k))); xlabel(ax, 'Kp [1/m]');
    if k == 1, ylabel(ax, 'pico de pitch de la mesa, base de 15° [°]'); end
    ylim(ax, [0 max(3, ceil(max(G.pitch15_corr(G.cumple))))]);
    if k == numel(P), legend(ax, 'Location', 'eastoutside', 'FontSize', 7); end
end
title(tl, 'Arquitectura B: barrido de Kp, Ki y presión (sustituto; puntos llenos = cumplen márgenes y escalón)');
exportgraphics(f, fullfile(fig_dir, 'exp11_barrido.png'), 'Resolution', 130); close(f);
winopen(fullfile(fig_dir, 'exp11_barrido.png'));
end

function cerrar(m)
for i = 1:numel(m), if bdIsLoaded(m{i}), close_system(m{i}, 0); end, end
end

function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end
