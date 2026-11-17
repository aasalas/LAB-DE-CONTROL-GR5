%% EXP8_ANGULOS_GRANDES  Atenuación ante ángulos grandes con el controlador final: prealimentación
% (Kff = 1) + realimentación K = 3, saturación ±30°, g = 1, Kp = 20, Ki = 1.
% Olas lentas (Tp = 12 s) con Hs = 5.06, 10.20 y 15.49 m, que inclinan la base 5°, 10° y 15°. Con
% Tp = 12 s la velocidad que piden los cilindros (0.08, 0.17 y 0.25 m/s) queda por debajo de lo que
% dan sus válvulas (0.29 m/s retrayendo); con olas rápidas del mismo ángulo no la alcanzan.
% Por caso: sin compensar (MiL), final MiL y final PiL no ideal (encoder de 5 LSB). ~22 min.
% El escenario nominal (Hs = 2 m, Tp = 10 s) está en exp5_prealimentacion y exp6_final_ff.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp8_grande_{05,10,15}.mat/.csv
% Uso: cd MODELOS/CINEMATICA; exp8_angulos_grandes
c = table(["mil_sin"; "mil_final"; "pil_final_noideal"], ["mil"; "mil"; "pil"], [0; 3; 3], 20*ones(3,1), ...
    ones(3,1), ones(3,1), [0 0 0 0; 0 0 0 0; 1 1 1 1], [0; 1; 1], ...
    'VariableNames', {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal', 'Kff'});
Hs = [5.06 10.20 15.49]; grados = [5 10 15];
for i = 1:3
    T = exp_corridas(c, sprintf('exp8_grande_%02d', grados(i)), 'Hs', Hs(i), 'Tp', 12);
    disp(T(:, {'id','estable','pico_pitch','rms_pitch','pico_roll','rms_roll','urms_max','sat_pct_max'}))
end
