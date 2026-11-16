%% EXP4_K_IK  Barrido de la ganancia de nivelación K con la cinemática inversa corregida (g = 1).
% Con la IK anterior la mesa realizaba g = 0.188 del ángulo ordenado y K = 15 equivalía a una
% ganancia de lazo g*K = 2.8; el lazo era inestable con g*K = 5.6 (K = 30). Con g = 1, K es la
% ganancia de lazo real. Saturación del comando de ángulo: ±0.3 rad (antes ±0.6 con g = 0.188).
% MiL, Hs = 2 m, Tp = 10 s, Kp = 20, Ki = 1, sensor ideal. ~10 min.
% Uso: cd MODELOS/CINEMATICA; exp4_k_ik
Kb = [0; 2.8; 4; 6; 9; 15];
n = numel(Kb);
id = "mil_K" + strrep(string(Kb), ".", "p");
corridas = table(id, repmat("mil", n, 1), Kb, 20*ones(n,1), ones(n,1), ones(n,1), zeros(n, 4), ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal'});
T = exp_corridas(corridas, 'exp4_k_ik', 'Hs', 2, 'Tp', 10);
disp(T(:, {'id','K','estable','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max','atten_pitch_dB'}))
