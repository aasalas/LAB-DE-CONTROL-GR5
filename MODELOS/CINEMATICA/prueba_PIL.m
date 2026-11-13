%% =========================================================
%  PRUEBA PiL COMPLETA - 3 PISTONES MARLUP
% ==========================================================

clear
clc

%% 1. Cargar parametros de la planta hidraulica
run('MARLUP_hydr_params.m');

%% 2. Modelo
mdl = 'Model_aaronC';
load_system(mdl);
open_system(mdl);

%% 3. Controladores PI internos de los 3 pistones
cfg = struct( ...
    'Kp',   6.7, ...
    'Ki',   1, ...
    'Usat', 0.1);

%% 4. Ganancia exterior de nivelacion
% Esta es la K que prueba barrido_K
K = 20;

set_param([mdl '/Gain'],  'Gain', num2str(K));   % Roll
set_param([mdl '/Gain1'], 'Gain', num2str(K));   % Pitch

% Por ahora dejamos control vertical apagado
set_param([mdl '/Gain2'], 'Gain', '0');

%% 5. Oleaje
Hs = 0.5;
set_param([mdl '/P-M SPECTRUM/Constant1'], ...
    'Value', num2str(Hs));

%% 6. Puerto del Arduino
% CAMBIAR por el puerto correcto
puerto = "COM10";

%% 7. Configuracion de no idealidades
% [linealidad, histeresis, cuantizacion]
% Primero probamos PiL ideal
en = [0 0 0];

%% 8. Tiempo de simulacion
Tsim = 30;

%% 9. Inicializar PiL
sp = pil3_iniciar(1, cfg, en, puerto);

disp("========================================");
disp(" PiL inicializado correctamente");
disp(" Ejecutando los 3 controladores PI");
disp("========================================");

%% 10. Simular
try
    out_PiL = sim(mdl, 'StopTime', num2str(Tsim));

    disp("========================================");
    disp(" Simulacion PiL terminada correctamente");
    disp("========================================");

catch ME
    % Si ocurre un error, liberar igualmente el puerto
    if ~isempty(sp)
        delete(sp);
    end
    clear sp

    rethrow(ME);
end

%% 11. Liberar puerto serie
if ~isempty(sp)
    delete(sp);
end
clear sp

disp("Puerto serie liberado.");

res = comparar_pil(20, 0.5, 30, "COM10");