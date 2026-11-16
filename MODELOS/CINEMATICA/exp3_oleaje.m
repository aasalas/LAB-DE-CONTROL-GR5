%% EXP3_OLEAJE  Tres estados de mar más agresivos: perturbación pico de ~5°, ~10° y ~15° en la base.
% La pendiente del oleaje crece como Hs/Tp^2, así que se fija Hs = 2 m y se acorta el periodo pico.
% Los Tp salen de evaluar fuera de Simulink la misma función del bloque P-M (rng(42), 30 s):
%   Tp = 7.5 s -> pitch 5.1°, Tp = 5.3 s -> 10.1°, Tp = 4.3 s -> 15.2° (picos de la base).
% Controlador único (Kp = 20, Ki = 1, K = 15). Por caso: sin compensar (MiL, K = 0), MiL con K = 15
% y PiL no ideal (Arduino, encoder con ruido de 5 LSB) con K = 15.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp3_oleaje_<grados>.mat/.csv. ~30 min en total.
% Uso: cd MODELOS/CINEMATICA; exp3_oleaje
casos = struct('nombre', {'exp3_oleaje_05', 'exp3_oleaje_10', 'exp3_oleaje_15'}, 'Tp', {7.5, 5.3, 4.3});
Kb = [0; 15; 15];
modo = ["mil"; "mil"; "pil"];
ni = [0 0 0 0; 0 0 0 0; 1 1 1 1];
id = modo + "_K" + string(Kb) + ["";"";"_noideal"];
n = numel(Kb);
corridas = table(id, modo, Kb, 20*ones(n,1), ones(n,1), ones(n,1), ni, ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal'});
for c = casos
    fprintf('\n##### %s: Hs = 2 m, Tp = %g s #####\n', c.nombre, c.Tp);
    T = exp_corridas(corridas, c.nombre, 'Hs', 2, 'Tp', c.Tp);
    disp(T(:, {'id','K','estable','t_sim_s','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max'}))
end
