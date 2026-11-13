%% EXP1_ETAPA3_PIL  Confirmación en el Arduino (PiL) del barrido de K con el controlador B
% (Kp = 20, Ki = 1, Usat = 1): K = 0, el K elegido (15) y el mayor K estable (20).
% Plan: MODELOS/CINEMATICA/BITACORA.md (etapa 3).  Uso: cd MODELOS/CINEMATICA; exp1_etapa3_pil
Kb = [0; 15; 20]; n = numel(Kb);
corridas = table("P" + string(Kb), repmat("pil", n, 1), Kb, 20*ones(n,1), ones(n,1), ones(n,1), ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat'});
T = exp_corridas(corridas, 'exp1_etapa3_pil', 'Hs', 0.5);
disp(T(:, {'id','K','Kp','estable','t_sim_s','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max','atten_pitch_dB','atten_roll_dB'}))
