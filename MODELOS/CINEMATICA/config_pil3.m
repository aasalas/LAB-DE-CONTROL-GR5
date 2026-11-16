%% CONFIG_PIL3  Ganancias y no idealidades del PiL de los 3 pistones: edite AQUI para iterar.
% Lo lee iniciar_pil3.m, que corre solo al simular Model_aaron.slx (MiL) o Model_aaronC.slx (PiL).
% Al cambiar Kp, Ki o Usat el modelo PiL recompila y vuelve a cargar el Arduino (~1 min).

%% Controlador PI de cada pistón (ctrl_pi3.slx, mismo PI en los tres)
% Kp = 20, Ki = 1 salen del experimento de diseño MODELOS/PISTON/diseno_pi.m (antes Kp = 6.7).
% Con este PI y la cinemática corregida (g = 1) la ganancia de nivelación K debe ser < 6:
% con K = 6 la plataforma es inestable (exp4_k_ik.m).
Kp   = 20;      % ganancia proporcional [1/m]: u = Kp*e, e en metros
Ki   = 1;       % ganancia integral [1/(m*s)]
Usat = 1;       % saturación del comando de la válvula: u en [-Usat, Usat] (1 = 100 %)

%% No idealidades del encoder lineal de cada cilindro (bloque "Linear encoder", en la realimentación)
% 1 = activa, 0 = ideal. La "Interfaz MCU" solo muestrea (10 ms) y convierte a single.
en_lin  = 0;    % error de linealidad: sesgo de 0.09 mm (peor caso)
en_hist = 0;    % histéresis: backlash de 0.004 mm
en_q    = 0;    % ADC de 10 bits sobre 450 mm: paso de 0.44 mm
en_ruido = 0;   % ruido eléctrico en la entrada analógica, independiente en cada pistón
ruido_mm = 2.2; % desviación estándar del ruido [mm]: 5 LSB del ADC (antes 1 LSB, 0.44 mm, que en
                % la inclinación de la mesa no se distinguía sin zoom)

%% Visualización
ver_mechanics = 0;   % 1 = abre Mechanics Explorer (animación 3D) al simular; 0 = solo los scopes

%% Lazo exterior de nivelación: la ganancia K = 3 está en los bloques Gain y Gain1 del modelo
%  (roll y pitch), con saturación de ±0.3 rad. Gain2 = 0 deja el lazo de heave apagado.
%  Hasta el 16-11-2026 era K = 15 con ±0.6 rad, pero la cinemática inversa hacía que la mesa
%  girara solo g = 0.188 del ángulo pedido (K = 15 equivalía a K = 2.8 con g = 1).
%% Prealimentación de la inclinación de la base (solo Model_aaron, MiL): 1 = activa, 0 = apagada.
%  Se suma -Kff*[roll; pitch] de la base al comando del lazo de nivelación (un IMU en la base).
Kff = 1;

%% Oleaje: Hs = 2 m (estado de mar 4) en P-M SPECTRUM/Constant1, Tp = 10 s. Con Hs = 0.5 m la base
%  apenas se inclinaba 0.7°, por el recorte direccional del bloque; el requisito es 1° en la mesa.

%% Sobrescritura desde la línea de comandos (la usa correr_pil3; no hace falta tocarla)
if exist('ovr_pil3', 'var')
    for f_ = fieldnames(ovr_pil3)'
        eval([f_{1} ' = ovr_pil3.(f_{1});']);
    end
    clear f_
end
