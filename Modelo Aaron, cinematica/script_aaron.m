%% ==============================================================
%  MARLUP – Modelo, Kalman (discreto) y Control LQI (x̂ + integrador)
%  Oleaje como disturbio en SALIDA:
%        y_total = C*x + P_reorder * y_amb   (no usar A*(x+x_a))
%  ===============================================================

clear; clc;
gain = 1;

% Piezas CAD (.SLDPRT) que cargan los bloques File Solid del modelo:
% se agregan al path para que los bloques las encuentren por nombre,
% sin rutas absolutas (funciona en cualquier máquina del equipo).
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'CAD'));
addpath(here);   % para resolver MARLUP_hidraulico_params.m

%% === Geometría / Asignanción de actuadores ===
H  = 0.11;          % [m]
Rb = 0.13;          % [m]
uz = Rb / sqrt(Rb^2 + 4*H^2);

phi = deg2rad([-30, 90, 210]);  % [rad]
Rt  = 0.65;                     % [m]

% [tau_x; tau_y; Fz] = T * [F1; F2; F3]
T = uz * [ Rt*sin(phi(1))  Rt*sin(phi(2))  Rt*sin(phi(3));
          -Rt*cos(phi(1)) -Rt*cos(phi(2)) -Rt*cos(phi(3));
           1               1               1            ];
Tinv = pinv(T);

%% === Inercia del plato ===
Jx   = 6.19446;     % kg*m^2
Jy   = 6.19446;     % kg*m^2
M_Plato = 58.5349;     % kg
Mass = M_Plato + 3*(0.492345 + 1.25618 + 0.667284) + 1.92617;

%% === Actuador hidraulico (PISTON_MODEL) ===
% Struct P que leen los bloques de PISTON_MODEL/ACTUADOR_HIDRAULICO:
%   Actuador  -> P.stroke      Masa         -> P.mass
%   Amortiguador -> P.damp     FuentePresion -> P.p_sys
% Ojo: P.mass (58.19 kg, masa acoplada del paper) es independiente de
% M_Plato; no son el mismo dato.
% Parametros provisionales del actuador hidraulico
P.stroke = 0.45;     % [m]
P.mass   = 58.19;    % [kg]
P.damp   = 1000;     % [N*s/m]
P.p_sys  = 90e5;     % [Pa]

%% === Planta ideal (sin amortiguamiento/rigidez) ===
% x = [alpha  alpha_dot  theta  theta_dot  z  z_dot]^T
A = [0 1 0 0 0 0;
     0 0 0 0 0 0;
     0 0 0 1 0 0;
     0 0 0 0 0 0;
     0 0 0 0 0 1;
     0 0 0 0 0 0];

B = [0     0     0;
     1/Jx  0     0;
     0     0     0;
     0     1/Jy  0;
     0     0     0;
     0     0     1/M_Plato];

% y = [roll  pitch  heave]^T
C = [1 0 0 0 0 0;
     0 0 1 0 0 0;
     0 0 0 0 1 0];

D = zeros(3,3);

sys = ss(A,B,C,D);
assert(rank(ctrb(sys))==size(A,1),'Planta no controlable');

%% === Reordenamiento del oleaje (de bloques a salidas del modelo) ===
% Oleaje entrega: y_amb = [heave; pitch; roll]
% Modelo espera:  y     = [ roll;  pitch; heave]
P_reorder = [0 0 1;   % roll   ← 3ª
             0 1 0;   % pitch  ← 2ª
             1 0 0];  % heave  ← 1ª

%% === Discretización ===
Ts  = 0.01;                  % IMPORTANTE: usar este Ts en TODOS los bloques discretos
sysd = c2d(sys, Ts, 'zoh');
[Ad, Bd, Cd, Dd] = ssdata(sysd);

%% === Kalman discreto (dlqe) ===================================
G  = eye(6);   % n×w → w = 6

% Proceso: más incertidumbre en velocidades; lo hacemos más "rápido"
Qx = 30 * diag([1e-6 1e-3 1e-6 1e-3 1e-6 1e-3]);  % ×30 de proceso

% Medición: roll/pitch 0.5°, heave 3 mm
Rn = diag([(10*pi/180)^2, (10*pi/180)^2, (3e-3)^2]);
N  = zeros(6,3);  % w×p = 6×3

% Chequeo
w = size(G,2); p = size(Cd,1);
assert(all(size(Qx)==[w w]));
assert(all(size(Rn)==[p p]));
assert(all(size(N )==[w p]));

[Ld, ~, ~] = dlqe(Ad, G, Cd, Qx, Rn, N);  % Ld: 6×3

%% === Control LQI (sistema aumentado con integradores de error) ===
nx = size(Ad,1);  % 6
ny = size(Cd,1);  % 3

Aaug = [ Ad,           zeros(nx,ny);
        -Cd*Ad,       eye(ny)     ];
Baug = [ Bd;
        -Cd*Bd ];

% Más castigo en z y en velocidades, integrador más agresivo
QxLQI = diag([ 300, 120,   300, 120,   12000, 300 ]);
Qi    = diag([ 15, 15, 60 ]);
Qaug  = blkdiag(QxLQI, Qi);

R = diag([ 6e-4, 6e-4, 1.0e-4 ]);

Kaug  = dlqr(Aaug, Baug, Qaug, R);    % → [Kx  Ki]
Kx    = Kaug(:,1:nx);                 % 3×6
Ki    = Kaug(:,nx+1:end);             % 3×3

[Ktest, Stest, etest] = lqi(sysd, Qaug, R);
K_LQI = Ktest(:,1:nx);                 % 3×6
K_LQIi = Ktest(:,nx+1:end);             % 3×3

%% Control LQR
%            .    .   .
% x =    [ a a  t t z z]
Q = diag([2,1,2,1,50,1]) % Penaliza el error en posiciones, no velocidades
% u =    [Tx   Ty   Fz ]
R = diag([0.15, 0.15, 0.1]) % Penaliza el uso de entrada de control

K = lqr(A,B,Q,R)

%% Observador 
Q_obs = diag([100 1000 100 1000 100 1000]); % High trust in model mechanics
R_obs = diag([1 1 1]);                      % Measurement noise covariance

% Observer Gain L
L = lqr(A', C', Q_obs, R_obs)';

%% Ganancia de Pre-compensación (Kr)
% Matriz del sistema en lazo cerrado (sin observador, para análisis de estado estacionario)
A_cl = A - B*K;

% Queremos encontrar Kr tal que y_ss = C*(-inv(A-BK)*B*Kr)*r = r
% Esto implica que C*(-inv(A-BK)*B*Kr) debe ser la matriz identidad.
Kr = pinv(C * (-inv(A_cl)) * B);

%% === Variables clave para Simulink ===============================
% 1) P_reorder  → Gain 3×3 a la salida del subsistema de Oleaje
% 2) y_total    = Cx + P_reorder*y_amb     (Sum 3x1 antes de Sensores)
% 3) Kalman (discreto):
%       A=Ad, B=Bd, C=Cd, D=0, Q=Qx, R=Rn, N=zeros(6,3), Ts = 0.001
%       Entradas: u (misma a planta), y_total
%       Salida:   xhat
% 4) Control:
%       e   = r - y_total
%       zI  = Discrete-Time Integrator(e), Ts = 0.001   <-- ¡igual que arriba!
%       u   = -Kx*xhat - Ki*zI
%       (no uses Kr/Krd con integrador)
%
% 5) Si hay saturaciones físicas:
%       u → Tinv → saturaciones(F1..F3) → T → u_sat → planta
%       Anti-windup: suma beta*(u_sat - u) a la entrada del integrador (beta 0.1–1)

%% === Print para revisar ==========================================
disp('Ganancias de control (LQI):');
disp('Kx ='); disp(Kx);
disp('Ki ='); disp(Ki);

disp('Ganancia de Kalman (Ld):');
disp(Ld);

disp('P_reorder (oleaje→salidas del modelo):');
disp(P_reorder);


%% PID AARON(HAY QUE AJUSTAR wn_p, es el ancho de banda del controlador del pitch)

zeta = 0.9;
wn_r = 8;
wn_p = 8;
wn_z  = 8;
p = 4;

pid_gains = @(J,wn) deal( J*wn^2*(1 + 2*zeta*p), ...
                          J*p*wn^3, ...
                          J*wn*(2*zeta + p) );

[Kp_roll,  Ki_roll,  Kd_roll ] = pid_gains(Jx, wn_r);
[Kp_pitch, Ki_pitch, Kd_pitch] = pid_gains(Jy, wn_p);
[Kp_heave, Ki_heave, Kd_heave] = pid_gains(M_Plato, wn_z);