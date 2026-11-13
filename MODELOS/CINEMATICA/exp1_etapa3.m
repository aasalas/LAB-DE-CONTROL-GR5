%% EXP1_ETAPA3  Barrido de la ganancia de nivelación K con el controlador B (PI elegido en
% MODELOS/PISTON/diseno_pi.m: Kp = 20, Ki = 1, Usat = 1), en MiL.
% Plan: MODELOS/CINEMATICA/BITACORA.md (etapa 3).  Uso: cd MODELOS/CINEMATICA; exp1_etapa3
Kb = [0; 5; 10; 15; 20; 30]; n = numel(Kb);
corridas = table("B" + string(Kb), repmat("mil", n, 1), Kb, 20*ones(n,1), ones(n,1), ones(n,1), ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat'});
T = exp_corridas(corridas, 'exp1_etapa3_mil');
disp(T(:, {'id','K','Kp','estable','t_sim_s','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max','atten_pitch_dB','atten_roll_dB'}))
