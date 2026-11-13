%% EXP1_ETAPA1  Factorial 2^3 (K, Kp, Usat) con el controlador A, en MiL, y confirmación en PiL.
% Plan: MODELOS/CINEMATICA/BITACORA.md (etapa 1). Se agrupa por Kp para no recompilar el PI.
% Uso: cd MODELOS/CINEMATICA; exp1_etapa1        (PiL de confirmación: exp1_etapa1_pil, tras analizar)
id   = ["0";"1";"2";"5";"6";"C";"3";"4";"7";"8"];
K    = [0; 5; 40; 5; 40; 14; 5; 40; 5; 40];
Kp   = [6.7; 3; 3; 3; 3; 8; 20; 20; 20; 20];
Usat = [1; 0.1; 0.1; 1; 1; 0.3; 0.1; 0.1; 1; 1];
corridas = table(id, repmat("mil",10,1), K, Kp, ones(10,1), Usat, 'VariableNames', {'id','modo','K','Kp','Ki','Usat'});
T = exp_corridas(corridas, 'exp1_etapa1_mil', 'Hs', 0.5); disp(T(:, {'id','K','Kp','Usat','estable','t_sim_s','pico_pitch','rms_pitch','urms_max','sat_pct_max','atten_pitch_dB'}))
