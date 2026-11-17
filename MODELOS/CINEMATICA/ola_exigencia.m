function [v_max, carrera, base] = ola_exigencia(Hs, Tp, Tsim)
% OLA_EXIGENCIA  Velocidad [m/s] y carrera [m] que pide a los cilindros compensar la ola, y pico de la
% inclinación de la base [°]. Usa la misma síntesis del bloque P-M SPECTRUM (100 frecuencias, 50
% direcciones, rng(42)) y el jacobiano de la cinemática corregida (la mesa gira sobre el centro de la
% base): una inclinación phi pide (Z0/L0)*R_BASE*phi de elongación en la pata más exigida.
% La usa correr_pil3 para no lanzar corridas que los cilindros no pueden seguir (Simscape se detiene).
if nargin < 3, Tsim = 30; end
t = 0:0.01:Tsim; arm = 1.377/sqrt((0.7608 - 0.143)^2 + 1.377^2)*0.7608;   % 0.694 m/rad
N = 100; M = 50; g = 9.81;
fp = 1/Tp; f_max = 4*fp; df = f_max/N; f = df:df:f_max; omega = 2*pi*f;
d_theta = 2*pi/M; theta = d_theta:d_theta:2*pi;
s_ = rng; rng(42); fase = 2*pi*rand(N, M); rng(s_);              % misma semilla que el bloque
k_o = omega.^2/g; kx = k_o'*cos(theta); ky = k_o'*sin(theta);
S = (5/16)*Hs^2*fp^4./f.^5.*exp(-1.25*(fp^4./f.^4));
D = (2/pi)*(cos(theta/2)).^20; D(theta < -pi/2 | theta > pi/2) = 0;
A = sqrt(2*S'.*D*df*d_theta);
W = repmat(omega', 1, M); p = zeros(size(t)); r = p;
for i = 1:numel(t)
    arg = fase - W*t(i);
    p(i) = atan(sum(A.*kx.*sin(arg), 'all')); r(i) = atan(sum(A.*ky.*sin(arg), 'all'));
end
i = t >= 2;                                                        % sin el arranque
v = arm*hypot(gradient(p, t), gradient(r, t));
v_max = max(v(i)); carrera = arm*max(hypot(p(i), r(i))); base = rad2deg(max(abs(p(i))));
end
