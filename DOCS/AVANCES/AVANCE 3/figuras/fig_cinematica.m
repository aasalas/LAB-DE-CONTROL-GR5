function fig_cinematica(alpha_deg, theta_deg)
% FIG_CINEMATICA  Figura del modelo cinemático de MARLUP para el informe del Avance 3.
%   fig_cinematica              pose inclinada de ejemplo: alpha = 10°, theta = -8°
%   fig_cinematica(a, t)        otra pose (grados)
% (a) Marcos: base {0}, mesa {P}, anclajes inferiores {B_j} y superiores {A_j}, en la pose nominal.
% (b) Construcción vectorial de la pata 1 en la pose inclinada: d_1 = p_1 - b_1, L_1 = ||d_1||.
% Usa la geometría y la ecuación de la MATLAB Function marlup_ik (INVERSE KINEMATICS):
%   T_0^P = Ry(theta) Rx(alpha) Trasl(0,0,z),   L_j = || R (p_j^P + z k) - b_j ||.
% Escribe cinematica.pdf y cinematica.png junto a este archivo.
if nargin < 1, alpha_deg = 10; end
if nargin < 2, theta_deg = -8; end
here = fileparts(mfilename('fullpath'));

R_B = 0.7608; R_T = 0.143; Z0 = 1.377;              % [m], medidos en el CAD (Tabla de geometría)
PHI = [-30 90 210]*pi/180;
c = 100;                                            % se dibuja en cm

f1 = figure('Units', 'centimeters', 'Position', [2 2 18 8.5], 'Color', 'w');
theme(f1, 'light');
tl = tiledlayout(f1, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---------------- (a) marcos en la pose nominal ----------------
ax = nexttile(tl); hold on; axis equal; grid on; box off; ax.FontSize = 8;
[b, p, Rm, o] = pose(0, 0, Z0, R_B, R_T, PHI);
disco(o*0, eye(3), R_B, [0.85 0.85 0.85], 0.35, c);
disco(o, Rm, R_T*1.6, [0.55 0.70 0.95], 0.45, c);
for j = 1:3
    plot3(c*[b(1,j) p(1,j)], c*[b(2,j) p(2,j)], c*[b(3,j) p(3,j)], '-', 'Color', [0.35 0.25 0.65], 'LineWidth', 2);
    triada(b(:,j), eye(3), 14, c); triada(p(:,j), Rm, 10, c);
    text(c*b(1,j)*1.13, c*b(2,j)*1.13, c*b(3,j) - 6, sprintf('\\{B_%d\\}', j), 'FontSize', 8);
    u = p(1:2,j)/norm(p(1:2,j));                     % etiqueta hacia afuera, radial
    text(c*p(1,j) + 32*u(1), c*p(2,j) + 32*u(2), c*p(3,j) + 2, sprintf('\\{A_%d\\}', j), ...
        'FontSize', 8, 'HorizontalAlignment', 'center');
    m = (b(:,j) + p(:,j))/2;
    text(c*m(1) + 4, c*m(2), c*m(3), sprintf('L_%d', j), 'FontSize', 8, 'Color', [0.35 0.25 0.65]);
end
triada([0;0;0], eye(3), 30, c); text(-12, -12, -8, '\{0\}', 'FontSize', 9, 'FontWeight', 'bold');
triada(o, Rm, 25, c); text(0, 0, c*o(3) + 33, '\{P\}', 'FontSize', 9, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
% radio de la base y ángulos de los brazos
plot3(c*[0 b(1,2)], c*[0 b(2,2)], [0 0], 'k--', 'LineWidth', 0.8);
text(c*b(1,2)/2 + 3, c*b(2,2)/2, 4, 'R_B', 'FontSize', 8);
plot3([0 0], [0 0], c*[0 Z0], 'k:', 'LineWidth', 0.8); text(3, 3, c*Z0/2, 'Z_0', 'FontSize', 8);
xlabel('x_0 (cm)'); ylabel('y_0 (cm)'); zlabel('z_0 (cm)');
view(-50, 22); xlim([-90 90]); ylim([-90 90]); zlim([0 175]);
title('(a) Marcos de MARLUP, pose nominal', 'FontWeight', 'normal');

% ---------------- (b) construcción vectorial de la pata 1 ----------------
ax = nexttile(tl); hold on; axis equal; grid on; box off; ax.FontSize = 8;
al = deg2rad(alpha_deg); th = deg2rad(theta_deg);
[b, p, Rm, o, L] = pose(al, th, Z0, R_B, R_T, PHI);
disco(o*0, eye(3), R_B, [0.85 0.85 0.85], 0.35, c);
disco(o, Rm, R_T*1.6, [0.55 0.70 0.95], 0.45, c);
for j = 2:3
    plot3(c*[b(1,j) p(1,j)], c*[b(2,j) p(2,j)], c*[b(3,j) p(3,j)], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.5);
end
triada([0;0;0], eye(3), 25, c); text(-12, -12, -8, '\{0\}', 'FontSize', 9, 'FontWeight', 'bold');
triada(o, Rm, 22, c); text(-14, 0, c*o(3) + 14, '\{P\}', 'FontSize', 9, 'FontWeight', 'bold');
mg = [0.85 0.10 0.45]; az = [0.10 0.35 0.80]; vd = [0.10 0.55 0.20];
flecha([0;0;0], b(:,1), az, c); flecha([0;0;0], p(:,1), vd, c); flecha(b(:,1), p(:,1), mg, c, 2.2);
text(c*b(1,1)/2, c*b(2,1)/2 - 6, -6, '\it{b}_1', 'FontSize', 9, 'Color', az, 'FontWeight', 'bold');
text(c*p(1,1)/2 - 10, c*p(2,1)/2, c*p(3,1)/2, '\it{p}_1', 'FontSize', 9, 'Color', vd, 'FontWeight', 'bold');
m = (b(:,1) + p(:,1))/2;
text(c*m(1) + 6, c*m(2), c*m(3) + 10, {'\it{d}_1 = \it{p}_1 - \it{b}_1', ...
    sprintf('L_1 = ||\\it{d}_1|| = %.1f cm', c*L(1))}, 'FontSize', 8, 'Color', mg);
% normal de la mesa, para leer la inclinación
n = Rm(:,3);
plot3(c*o(1) + [0 45*n(1)], c*o(2) + [0 45*n(2)], c*o(3) + [0 45*n(3)], 'k--', 'LineWidth', 1);
plot3(c*o(1) + [0 0], c*o(2) + [0 0], c*o(3) + [0 45], 'k:', 'LineWidth', 1);
text(c*o(1) + 45*n(1), c*o(2) + 45*n(2), c*o(3) + 48*n(3), '  \it{n}_P', 'FontSize', 8);
xlabel('x_0 (cm)'); ylabel('y_0 (cm)'); zlabel('z_0 (cm)');
view(-50, 22); xlim([-90 90]); ylim([-90 90]); zlim([0 200]);
title(sprintf('(b) Pata 1 con \\alpha = %g°, \\theta = %g°, z = Z_0', alpha_deg, theta_deg), 'FontWeight', 'normal');

exportgraphics(f1, fullfile(here, 'cinematica.pdf'), 'ContentType', 'vector');
exportgraphics(f1, fullfile(here, 'cinematica.png'), 'Resolution', 250);
fprintf('L = [%.4f %.4f %.4f] m, L0 = %.4f m\n', L, sqrt((R_B - R_T)^2 + Z0^2));
end

function [b, p, Rm, o, L] = pose(al, th, z, R_B, R_T, PHI)
% Misma cinemática que marlup_ik: T = Ry(theta) Rx(alpha) Trasl(0,0,z); la mesa gira sobre el
% centro de la base, así que su origen es R*(0,0,z)
ca = cos(al); sa = sin(al); ct = cos(th); st = sin(th);
Rm = [ct sa*st ca*st; 0 ca -sa; -st sa*ct ca*ct];
o = Rm*[0; 0; z];
b = R_B*[cos(PHI); sin(PHI); zeros(1, 3)];
p = Rm*(R_T*[cos(PHI); sin(PHI); zeros(1, 3)] + [0; 0; z]);
L = sqrt(sum((p - b).^2, 1));
end

function disco(o, Rm, r, col, a, c)
t = linspace(0, 2*pi, 80); q = Rm*[r*cos(t); r*sin(t); zeros(size(t))] + o;
fill3(c*q(1,:), c*q(2,:), c*q(3,:), col, 'FaceAlpha', a, 'EdgeColor', col*0.7);
end

function triada(o, Rm, Lc, c)
col = {[0.85 0.15 0.15], [0.15 0.60 0.15], [0.15 0.30 0.85]};
for k = 1:3
    d = Lc*Rm(:,k);
    quiver3(c*o(1), c*o(2), c*o(3), d(1), d(2), d(3), 0, 'Color', col{k}, 'LineWidth', 1.2, 'MaxHeadSize', 0.5);
end
end

function flecha(a, b, col, c, w)
if nargin < 5, w = 1.6; end
d = c*(b - a);
quiver3(c*a(1), c*a(2), c*a(3), d(1), d(2), d(3), 0, 'Color', col, 'LineWidth', w, 'MaxHeadSize', 0.25);
end
