%% DISENO_PI  Diseña y compara varios PI para el lazo de posición de un pistón.
% Procedimiento:
%   1. Función de transferencia X/U: se identifica con la respuesta al escalón en lazo abierto
%      del modelo no lineal de Simulink (bloque PISTON MODEL de PiL.slx) en el punto de trabajo
%      de la plataforma, x0 = 0.23 m. Un escalón en la válvula produce una velocidad constante:
%          G(s) = Kv * exp(-theta*s) / ( s * (tau*s + 1) )
%      Kv es la velocidad por unidad de comando; tau y theta, el retraso de esa velocidad.
%      Para el diseño se discretiza con retenedor de orden cero a Ts = 10 ms.
%   2. Candidatos: los PI en uso, pidtune a varios anchos de banda y márgenes, y Ziegler-Nichols.
%   3. Métricas de la respuesta al escalón de cada candidato: sobre G y sobre el
%      modelo no lineal (escalón pequeño de 10 mm en x0 y escalón grande de 0 a 0.40 m).
%   4. Selección con la regla escrita abajo (fijada antes de ver los resultados).
% Uso:  cd MODELOS/PISTON; diseno_pi          (sin Arduino; unos 5 min)
% Salidas: resultados/diseno_pi.csv y .mat, figuras/diseno_pi_*.png y .pdf
%
% REGLA DE SELECCIÓN
%   Requisitos (anteproyecto): Mp <= 10 %, ts(2 %) <= 2 s, error en régimen nulo (< 2.3 mm).
%   Robustez: margen de ganancia >= 10 dB y margen de fase >= 60 grados (sobre G lineal).
%   Deben cumplirse en la G lineal y en los dos escalones del modelo no lineal.
%   Entre los que cumplen gana el de menor ts en el escalón de 10 mm; si empatan, el de menor Mp.
here = fileparts(mfilename('fullpath')); cd(here);
Ts = 0.01; x0 = 0.23; w_ola = 2*pi/10;                 % periodo pico del oleaje: 10 s
run(fullfile(here, '..', 'CINEMATICA', 'MARLUP_hydr_params.m'));
sens = struct('bias', 0, 'backlash', 0, 'q', 1e-12, 'xmin', -inf, 'xmax', inf);   % sensor ideal
m = 'PiL'; load_system(m); load_system('ctrl_pi');
set_param([m '/Controlador'], 'SimulationMode', 'Normal');
warning('off', 'all');                                 % avisos de cuantización a single y puertos sin conectar
P0 = get_param('ctrl_pi/PI', 'P'); I0 = get_param('ctrl_pi/PI', 'I');

%% 1. Función de transferencia: identificación en lazo abierto
cyl.x_init = x0;
h = 'tmp_lazo_abierto'; if bdIsLoaded(h), close_system(h, 0); end
new_system(h); load_system(h);
add_block([m '/PISTON MODEL'], [h '/P']); add_block('simulink/Sources/Step', [h '/S']);
set_param([h '/S'], 'Time', '0.3', 'Before', '0', 'After', 'u0'); add_line(h, 'S/1', 'P/1');
add_block('simulink/Sinks/To Workspace', [h '/wv'], 'VariableName', 'v', 'SaveFormat', 'Array'); add_line(h, 'P/5', 'wv/1');
for i_ = [1 2 3 4 6], add_block('simulink/Sinks/Terminator', sprintf('%s/t%d', h, i_)); add_line(h, sprintf('P/%d', i_), sprintf('t%d/1', i_)); end
set_param(h, 'Solver', 'ode4', 'FixedStep', '1e-4', 'StopTime', '0.6');
ensayos = [0.02 0.05 0.1 -0.02 -0.05 -0.1 1 -1]; ID = struct('u0', {}, 't', {}, 'vn', {}, 'Kv', {});
for u0 = ensayos
    out = sim(h, 'ReturnWorkspaceOutputs', 'on'); t = out.tout; v = out.v;
    v0 = mean(v(t > 0.25 & t < 0.3)); vss = mean(v(t > 0.5)); i = t >= 0.3 & t <= 0.4;
    ID(end+1) = struct('u0', u0, 't', t(i) - 0.3, 'vn', (v(i) - v0)/(vss - v0), 'Kv', (vss - v0)/u0); %#ok<SAGROW>
    fprintf('Lazo abierto, u0 = %5.2f: velocidad %7.4f m/s, Kv = %.3f m/s\n', u0, vss - v0, ID(end).Kv);
end
close_system(h, 0);
peq = abs([ID.u0]) <= 0.1;                              % ensayos de señal pequeña
Kv_ext = mean([ID(peq & [ID.u0] > 0).Kv]); Kv_ret = mean([ID(peq & [ID.u0] < 0).Kv]);
Kv = (Kv_ext + Kv_ret)/2;                               % nominal: promedio de extensión y retracción
Kv_rango = [min([ID.Kv]) max([ID.Kv])];
modelo = @(q, t) (t > q(2)).*(1 - exp(-max(t - q(2), 0)/q(1)));     % q = [tau theta]
costo = @(q) sum(arrayfun(@(e) sum((modelo(abs(q), e.t) - e.vn).^2), ID(peq)));
q = abs(fminsearch(costo, [0.005 0.010])); tau = q(1); theta = q(2);
G = tf(Kv, [tau 1 0], 'IODelay', theta);
Gd = c2d(G, Ts, 'zoh'); Gd.InputName = 'u'; Gd.OutputName = 'x';
fprintf('\nG(s) = Kv exp(-theta s)/(s (tau s + 1)):  Kv = %.3f m/s (extensión %.3f, retracción %.3f; rango %.2f a %.2f)\n', Kv, Kv_ext, Kv_ret, Kv_rango);
fprintf('tau = %.1f ms, theta = %.1f ms\n', tau*1e3, theta*1e3);

%% 2. Candidatos
C0 = pid(1, 1, 'Ts', Ts, 'IFormula', 'Trapezoidal');   % como el bloque: integrador trapezoidal
cand = struct('nombre', {}, 'metodo', {}, 'Kp', {}, 'Ki', {});
cand(end+1) = struct('nombre', "A",  'metodo', "en uso, 3 pistones", 'Kp', 6.7, 'Ki', 1);
cand(end+1) = struct('nombre', "U",  'metodo', "en uso, validación unitaria", 'Kp', 60, 'Ki', 1);
cand(end+1) = struct('nombre', "M",  'metodo', "propuesta del informe", 'Kp', 20, 'Ki', 1);
for pm = [60 75]
    for wc = [5 10 15 20 30]
        C = pidtune(Gd, C0, wc, pidtuneOptions('PhaseMargin', pm));
        cand(end+1) = struct('nombre', sprintf("T%d_%d", pm, wc), ...
            'metodo', sprintf("pidtune, MF %d°, cruce %d rad/s", pm, wc), 'Kp', C.Kp, 'Ki', C.Ki); %#ok<SAGROW>
    end
end
[Gm, ~, wcg] = margin(Gd);                             % Ziegler-Nichols con la ganancia última
if isfinite(Gm) && wcg > 0
    Tu = 2*pi/wcg;
    cand(end+1) = struct('nombre', "ZN", 'metodo', "Ziegler-Nichols (Ku, Tu)", 'Kp', 0.45*Gm, 'Ki', 0.45*Gm*1.2/Tu);
    fprintf('Ganancia última Ku = %.1f, Tu = %.3f s\n', Gm, Tu);
end

%% 3. Métricas
T = table();
S = struct();
for c = 1:numel(cand)
    k = cand(c); C = pid(k.Kp, k.Ki, 'Ts', Ts, 'IFormula', 'Trapezoidal');
    L = C*Gd; Tcl = feedback(L, 1);
    r = struct('estable_lin', isstable(Tcl), 'Mp', NaN, 'tr', NaN, 'ts', NaN, 'MG_dB', NaN, 'MF', NaN, 'wc', NaN, 'e_ola', NaN);
    if r.estable_lin
        [y, t] = step(Tcl, 0:Ts:6); si = info_escalon(t, y, 0, 1, 0);
        r.Mp = si.Mp; r.tr = si.tr; r.ts = si.ts;
        am = allmargin(L); r.MG_dB = 20*log10(min([am.GainMargin(am.GainMargin > 1) Inf]));
        r.MF = min([am.PhaseMargin Inf]); r.wc = max([am.PMFrequency 0]);
        r.e_ola = 100*abs(1 - freqresp(Tcl, w_ola));   % error de seguimiento a la frecuencia del oleaje [%]
        S.(k.nombre).lin = [t(:) y(:)];
    end
    % modelo no lineal: escalón pequeño (10 mm en x0, t = 1.5 s) y grande (0 a 0.40 m, t = 0.5 s)
    p = simular(m, k.Kp, k.Ki, x0, x0 + 0.010, 1.5, 6);
    g = simular(m, k.Kp, k.Ki, 0, 0.40, 0.5, 5);
    S.(k.nombre).peq = p.L; S.(k.nombre).gra = g.L;
    T = [T; table(k.nombre, k.metodo, k.Kp, k.Ki, r.estable_lin, r.Mp, r.tr, r.ts, r.MG_dB, r.MF, r.wc, r.e_ola, ...
        p.Mp, p.tr, p.ts, p.ess*1e3, p.umax, g.Mp, g.ts, g.ess*1e3, ...
        'VariableNames', {'id', 'metodo', 'Kp', 'Ki', 'estable', 'Mp_lin', 'tr_lin', 'ts_lin', 'MG_dB', 'MF_deg', 'wc', 'e_ola_pct', ...
        'Mp_10mm', 'tr_10mm', 'ts_10mm', 'ess_10mm_mm', 'umax_10mm', 'Mp_400mm', 'ts_400mm', 'ess_400mm_mm'})]; %#ok<AGROW>
    fprintf('%-7s Kp=%7.2f Ki=%8.2f | lin: Mp %5.1f %% ts %5.2f s MG %5.1f dB MF %5.1f° | 10 mm: Mp %5.1f %% ts %5.2f s | 400 mm: Mp %5.1f %% ts %5.2f s\n', ...
        k.nombre, k.Kp, k.Ki, r.Mp, r.ts, r.MG_dB, r.MF, p.Mp, p.ts, g.Mp, g.ts);
end

%% 4. Selección
ok = T.estable & T.Mp_lin <= 10 & T.ts_lin <= 2 & T.MG_dB >= 10 & T.MF_deg >= 60 & ...
     T.Mp_10mm <= 10 & T.ts_10mm <= 2 & abs(T.ess_10mm_mm) <= 2.3 & ...
     T.Mp_400mm <= 10 & T.ts_400mm <= 2 & abs(T.ess_400mm_mm) <= 2.3;
T.cumple = ok;
Tok = sortrows(T(ok, :), {'ts_10mm', 'Mp_10mm'});
if isempty(Tok), elegido = ""; fprintf('\nNingún candidato cumple todos los criterios.\n');
else, elegido = Tok.id(1);
    fprintf('\nELEGIDO: %s (%s)  Kp = %.3g, Ki = %.3g\n', elegido, Tok.metodo(1), Tok.Kp(1), Tok.Ki(1));
end
T.elegido = T.id == elegido;
disp(T(:, {'id', 'Kp', 'Ki', 'Mp_lin', 'ts_lin', 'MG_dB', 'MF_deg', 'e_ola_pct', 'Mp_10mm', 'ts_10mm', 'Mp_400mm', 'ts_400mm', 'cumple'}));
if ~isfolder('resultados'), mkdir('resultados'); end
writetable(T, fullfile('resultados', 'diseno_pi.csv'));
save(fullfile('resultados', 'diseno_pi.mat'), 'T', 'S', 'G', 'Gd', 'Kv', 'Kv_ext', 'Kv_ret', 'Kv_rango', 'tau', 'theta', 'ID', 'cand', 'elegido');

% el modelo queda como estaba (no se guarda nada)
set_param('ctrl_pi/PI', 'P', P0, 'I', I0);
close_system(m, 0); close_system('ctrl_pi', 0); warning('on', 'all');

%% 5. Figuras
figuras_diseno_pi
disp('diseno_pi OK');

%% Funciones locales
function r = simular(m, Kp, Ki, xa, xb, t0, tfin)
% Corre el modelo no lineal con el PI dado y un escalón de xa a xb en t0.
set_param('ctrl_pi/PI', 'P', num2str(Kp, 10), 'I', num2str(Ki, 10));
evalin('base', sprintf('cyl.x_init = %.6f;', xa));
set_param([m '/Step1'], 'Time', num2str(t0), 'Before', num2str(xa), 'After', num2str(xb));
r = struct('Mp', NaN, 'tr', NaN, 'ts', NaN, 'ess', NaN, 'umax', NaN, 'L', []);
try
    out = sim(m, 'StopTime', num2str(tfin), 'ReturnWorkspaceOutputs', 'on');
catch err
    fprintf(2, '  simulación fallida (Kp = %g, Ki = %g): %s\n', Kp, Ki, err.message); return
end
n = numel(out.log_x); t = (0:n-1)'*0.01; x = double(out.log_x(:)); u = double(out.log_u(:));
si = info_escalon(t, x, xa, xb, t0);
r.Mp = si.Mp; r.tr = si.tr; r.ts = si.ts; r.ess = si.ess; r.umax = max(abs(u(t >= t0)));
r.L = [t double(out.log_ref(:)) x u];
end

function s = info_escalon(t, y, ya, yb, t0)
% Sobrepaso [%], tiempo de subida 10-90 % [s], establecimiento al 2 % [s] y error final.
i = t >= t0; tt = t(i) - t0; yy = (y(i) - ya)/(yb - ya);          % normalizado: 0 -> 1
s.Mp = max(0, (max(yy) - 1)*100);
i10 = find(yy >= 0.1, 1); i90 = find(yy >= 0.9, 1);
if isempty(i90), s.tr = NaN; else, s.tr = tt(i90) - tt(i10); end
fuera = find(abs(yy - 1) > 0.02, 1, 'last');
if isempty(fuera), s.ts = 0; elseif fuera == numel(yy), s.ts = Inf; else, s.ts = tt(fuera + 1); end
s.ess = (1 - mean(yy(tt >= tt(end) - 0.5)))*(yb - ya);            % promedio del último medio segundo
end
