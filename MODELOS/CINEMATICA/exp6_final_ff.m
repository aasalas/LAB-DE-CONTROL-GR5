%% EXP6_FINAL_FF  Controlador final: prealimentación de la base (Kff = 1) + realimentación K = 3,
% con g = 1, Kp = 20, Ki = 1. Completa lo que no está en exp5_prealimentacion (MiL con y sin
% prealimentación, sensor ideal) ni en las corridas sin compensar (K = 0, que no dependen de la
% cinemática: exp4_k_ik para Tp = 10 s y exp3_oleaje_* para Tp = 7.5, 5.3 y 4.3 s).
%   Tp = 10 s: MiL no ideal, PiL ideal y PiL no ideal.
%   Tp = 7.5, 5.3 y 4.3 s: PiL no ideal.
% No ideal = encoder con sesgo, histéresis, ADC y ruido de 5 LSB. Hs = 2 m. ~15 min con el Arduino.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp6_ff_Tp*.mat/.csv
% Uso: cd MODELOS/CINEMATICA; exp6_final_ff
c10 = table(["mil_K3_ff_noideal"; "pil_K3_ff"; "pil_K3_ff_noideal"], ["mil"; "pil"; "pil"], 3*ones(3,1), ...
    20*ones(3,1), ones(3,1), ones(3,1), [1 1 1 1; 0 0 0 0; 1 1 1 1], ones(3,1), ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal', 'Kff'});
T = exp_corridas(c10, 'exp6_ff_Tp10', 'Hs', 2, 'Tp', 10);
disp(T(:, {'id','estable','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max'}))
cOla = table("pil_K3_ff_noideal", "pil", 3, 20, 1, 1, [1 1 1 1], 1, ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal', 'Kff'});
for Tp = [7.5 5.3 4.3]
    T = exp_corridas(cOla, sprintf('exp6_ff_Tp%s', strrep(sprintf('%g', Tp), '.', 'p')), 'Hs', 2, 'Tp', Tp);
    disp(T(:, {'id','estable','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max'}))
end
