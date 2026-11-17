%% EXP7_SOLO_FF  Prueba de solo prealimentación (Kff = 1, K = 0), descartada.
% MiL, g = 1, Kp = 20, Ki = 1, saturación ±30°, Hs = 2 m, Tp = 10 s: sin compensar y solo prealimentación.
% Resultado: la mesa se desvía poco a poco (error medio de 0.01° a 1° en 30 s; picos de 2.39° en pitch
% y 3.47° en roll), contra 0.13° y 0.06° con prealimentación + K = 3. Sin realimentación nada corrige
% las pequeñas diferencias entre el modelo y la planta. El controlador final usa K = 3 (exp8_angulos_grandes).
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp7_nominal.mat/.csv. ~4 min.
% Uso: cd MODELOS/CINEMATICA; exp7_solo_ff
nom = table(["mil_sin"; "mil_ff"], ["mil"; "mil"], zeros(2,1), 20*ones(2,1), ones(2,1), ones(2,1), ...
    zeros(2, 4), [0; 1], 'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal', 'Kff'});
T = exp_corridas(nom, 'exp7_nominal', 'Hs', 2, 'Tp', 10);
disp(T(:, {'id','estable','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max'}))
