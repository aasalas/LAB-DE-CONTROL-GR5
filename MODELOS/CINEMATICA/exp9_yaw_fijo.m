%% EXP9_YAW_FIJO  Resultados con la planta corregida (yaw de la base fijo), g = 1, Kp = 20, Ki = 1,
% saturación ±30°. Controladores: final (Kff = 1, K = 3), solo prealimentación (Kff = 1, K = 0) y
% solo realimentación (Kff = 0, K = 3). Ordenado por prioridad:
%   1. Nominal Hs = 2 m, Tp = 10 s, MiL: sin compensar y los tres controladores.
%   2. Ángulos grandes con olas lentas (Tp = 12 s; Hs = 5.06, 10.20, 15.49 m: base de 5°, 10°, 15°),
%      MiL: sin compensar, final y solo prealimentación.
%   3. PiL no ideal (Arduino, encoder de 5 LSB) del controlador final en los cuatro estados de mar.
% correr_pil3 verifica antes de cada corrida que los cilindros puedan seguir la ola.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp9_*.mat/.csv. ~40 min.
% Uso: cd MODELOS/CINEMATICA; exp9_yaw_fijo
v = {'id', 'modo', 'K', 'Kp', 'Ki', 'Usat', 'noideal', 'Kff'};
mk = @(id, modo, K, ni, kff) table(string(id(:)), string(modo(:)), K(:), 20*ones(numel(K),1), ones(numel(K),1), ...
    ones(numel(K),1), ni, kff(:), 'VariableNames', v);
z = zeros(4, 4);
% 1. ángulos grandes, MiL (primero 15°, a pedido de Aarón)
Hs = [15.49 10.20 5.06]; grados = [15 10 5];
for i = 1:3
    exp_corridas(mk({'mil_sin', 'mil_final', 'mil_ff'}, {'mil', 'mil', 'mil'}, [0 3 0], z(1:3, :), [0 1 1]), ...
        sprintf('exp9_grande_%02d', grados(i)), 'Hs', Hs(i), 'Tp', 12);
end
% 2. nominal, MiL
exp_corridas(mk({'mil_sin', 'mil_final', 'mil_ff', 'mil_fb'}, {'mil', 'mil', 'mil', 'mil'}, [0 3 0 3], z, [0 1 1 0]), ...
    'exp9_nominal', 'Hs', 2, 'Tp', 10);
% 3. PiL no ideal del controlador final
exp_corridas(mk({'pil_final_noideal'}, {'pil'}, 3, [1 1 1 1], 1), 'exp9_nominal', 'Hs', 2, 'Tp', 10);
for i = 1:3
    exp_corridas(mk({'pil_final_noideal'}, {'pil'}, 3, [1 1 1 1], 1), sprintf('exp9_grande_%02d', grados(i)), ...
        'Hs', Hs(i), 'Tp', 12);
end
