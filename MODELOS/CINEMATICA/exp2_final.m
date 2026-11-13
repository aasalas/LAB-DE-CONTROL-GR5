%% EXP2_FINAL  Escenario final con el controlador único (Kp = 20, Ki = 1, K = 15) y oleaje de
% Hs = 2 m (estado de mar 4). Requisito: inclinación de la mesa <= 1°.
% MiL: barrido K = {0, 5, 10, 15, 20} con sensor ideal y K = 15 con sensor no ideal.
% PiL (Arduino): K = 15 ideal y no ideal. No ideal = sesgo + histéresis + ADC + ruido de 1 LSB.
% Plan y resultados: MODELOS/CINEMATICA/BITACORA.md.  Uso: cd MODELOS/CINEMATICA; exp2_final
Kb = [0; 5; 10; 15; 20; 15; 15; 15];
modo = ["mil"; "mil"; "mil"; "mil"; "mil"; "mil"; "pil"; "pil"];
ni = [zeros(5, 4); 1 1 1 1; 0 0 0 0; 1 1 1 1];
id = modo + "_K" + string(Kb) + ["";"";"";"";"";"_noideal";"";"_noideal"];
n = numel(Kb);
corridas = table(id, modo, Kb, 20*ones(n,1), ones(n,1), ones(n,1), ni, ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal'});
T = exp_corridas(corridas, 'exp2_final', 'Hs', 2);
disp(T(:, {'id','K','estable','t_sim_s','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max','atten_pitch_dB','atten_roll_dB'}))
