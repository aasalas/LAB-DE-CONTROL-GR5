%% CONFIG_PIL3  Ganancias y no idealidades del PiL de los 3 pistones: edite AQUI para iterar.
% Lo lee iniciar_pil3.m, que corre solo al simular Model_aaron.slx (MiL) o Model_aaronC.slx (PiL).
% Al cambiar Kp, Ki o Usat el modelo PiL recompila y vuelve a cargar el Arduino (~1 min).

%% Controlador PI de cada pistón (ctrl_pi3.slx, mismo PI en los tres)
% Kp = 27.5, Ki = 1 salen de exp11_opt_prealimentacion.m: el mayor Kp que cumple la regla de diseño de
% MODELOS/PISTON/diseno_pi.m (sobrepaso de 7.5 % en el escalón de 10 mm) y el que menos atrasa los
% pistones. Antes Kp = 20 (diseno_pi.m), y antes 6.7.
Kp   = 27.5;    % ganancia proporcional [1/m]: u = Kp*e, e en metros
Ki   = 1;       % ganancia integral [1/(m*s)]
Usat = 1;       % saturación del comando de la válvula: u en [-Usat, Usat] (1 = 100 %)

%% No idealidades del encoder lineal de cada cilindro (bloque "Linear encoder", en la realimentación)
% Activas por defecto desde el 16-11-2026: todos los resultados se dan con el sensor no ideal.
% 1 = activa, 0 = ideal. La "Interfaz MCU" solo muestrea (10 ms) y convierte a single.
en_lin  = 1;    % error de linealidad: sesgo de 0.09 mm (peor caso)
en_hist = 1;    % histéresis: backlash de 0.004 mm
en_q    = 1;    % ADC de 10 bits sobre 450 mm: paso de 0.44 mm
en_ruido = 1;   % ruido eléctrico en la entrada analógica, independiente en cada pistón
ruido_mm = 4.4; % desviación estándar del ruido [mm]: 10 LSB del ADC, desde el 17-11-2026 (antes 5 LSB,
                % 2.2 mm, y antes 1 LSB, 0.44 mm, que en la mesa no se distinguía sin zoom)

%% Visualización
ver_mechanics = 0;   % 1 = abre Mechanics Explorer (animación 3D) al simular; 0 = solo los scopes

%% Arquitectura B: prealimentación pura (desde el 16-11-2026)
%  La inclinación medida de la base (un IMU en la base, Demux FF) entra directo a la cinemática inversa,
%  que ordena a la mesa la rotación inversa R_b^T. No hay lazo sobre el ángulo de la mesa, ni saturación,
%  ni lazo de heave: se podaron del modelo. Antes: -Kff*base + K*(0 - mesa), K = 3, saturación de ±30°
%  (0.13° nominal; B deja 0.35° con Kp = 27.5, dentro del requisito de 1°).

%% Oleaje: Hs = 2 m (estado de mar 4) en P-M SPECTRUM/Constant1, Tp = 10 s. Con Hs = 0.5 m la base
%  apenas se inclinaba 0.7°, por el recorte direccional del bloque; el requisito es 1° en la mesa.

%% Sobrescritura desde la línea de comandos (la usa correr_pil3; no hace falta tocarla)
if exist('ovr_pil3', 'var')
    for f_ = fieldnames(ovr_pil3)'
        eval([f_{1} ' = ovr_pil3.(f_{1});']);
    end
    clear f_
end
