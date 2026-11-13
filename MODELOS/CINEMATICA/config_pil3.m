%% CONFIG_PIL3  Ganancias y no idealidades del PiL de los 3 pistones: edite AQUI para iterar.
% Lo lee iniciar_pil3.m, que corre solo al simular Model_aaron.slx (MiL) o Model_aaronC.slx (PiL).
% Al cambiar Kp, Ki o Usat el modelo PiL recompila y vuelve a cargar el Arduino (~1 min).

%% Controlador PI de cada pistón (ctrl_pi3.slx, mismo PI en los tres)
Kp   = 6.7;     % ganancia proporcional [1/m]: u = Kp*e, e en metros
Ki   = 1;       % ganancia integral [1/(m*s)]
Usat = 1;       % saturación del comando de la válvula: u en [-Usat, Usat] (1 = 100 %)

%% No idealidades del sensor de posición de cada cilindro (1 = activa, 0 = ideal)
en_lin  = 0;    % error de linealidad: sesgo de 0.09 mm (peor caso)
en_hist = 0;    % histéresis: backlash de 0.004 mm
en_q    = 0;    % ADC de 10 bits sobre 450 mm: paso de 0.44 mm

%% Lazo exterior de nivelación: la ganancia K está en los bloques Gain y Gain1 del modelo
%  (roll y pitch). Gain2 = 0 deja el lazo de heave apagado.
