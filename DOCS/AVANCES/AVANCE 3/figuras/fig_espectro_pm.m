function fig_espectro_pm(Hs, Tp)
% FIG_ESPECTRO_PM  Figura del oleaje de Pierson-Moskowitz para el informe del Avance 3.
%   fig_espectro_pm            Hs = 2 m, Tp = 10 s (los del bloque P-M SPECTRUM)
%   fig_espectro_pm(Hs, Tp)    otro estado de mar
% Izquierda: espectro S(f) y su discretizacion. Derecha: superficie del mar eta(x, y, 0)
% con color segun la altura. Usa la misma discretizacion, dispersion direccional y semilla
% que la MATLAB Function de MODELOS/CINEMATICA/Model_aaronC.slx (P-M SPECTRUM), asi que
% la superficie es la misma realizacion que ve la simulacion.
% Escribe espectro_pm.pdf y espectro_pm.png junto a este archivo.
if nargin < 1, Hs = 2; end
if nargin < 2, Tp = 10;  end
here = fileparts(mfilename('fullpath'));

% --- discretizacion identica al modelo ---
N = 100; M = 50; g = 9.81;
fp = 1/Tp; f_max = 4*fp; df = f_max/N; f = df:df:f_max; omega = 2*pi*f;
d_theta = 2*pi/M; theta = d_theta:d_theta:2*pi;
rng(42); fase = 2*pi*rand(N, M);
k = omega.^2/g; kx = k'*cos(theta); ky = k'*sin(theta);
S = (5/16)*Hs^2*fp^4 ./ f.^5 .* exp(-1.25*fp^4 ./ f.^4);
D = (2/pi)*cos(theta/2).^20; D(theta < -pi/2 | theta > pi/2) = 0;
A = sqrt(2*S'.*D*df*d_theta);

% --- espectro continuo para la curva ---
fc = linspace(1e-3, 0.5, 600);
Sc = (5/16)*Hs^2*fp^4 ./ fc.^5 .* exp(-1.25*fp^4 ./ fc.^4);
m0 = trapz(fc, Sc);

% --- perturbacion en el origen, como la calcula el bloque: pitch = atan(sum(A kx sin(arg))) ---
W = repmat(omega', 1, M);
tt = 2:0.01:30; pb = zeros(size(tt));
for i = 1:numel(tt), pb(i) = atan(sum(A.*kx.*sin(fase - W*tt(i)), 'all')); end
[~, i] = max(abs(pb)); ts = tt(i);                   % instante del pico de pitch de la base
arg0 = fase - W*ts;
theta_b = atan(sum(A.*kx.*sin(arg0), 'all'));        % = -atan(d eta/dx) en (0,0)
alpha_b = atan(sum(A.*ky.*sin(arg0), 'all'));        % = -atan(d eta/dy) en (0,0)
eta0 = sum(A.*cos(arg0), 'all');                     % heave de la base
sx = -tan(theta_b); sy = -tan(alpha_b);              % pendientes de la superficie en (0,0)

% --- superficie eta(x, y, t*) ---
Lx = 160; n = 161;                                   % dominio de 160 m (~1 longitud de onda pico)
[X, Y] = meshgrid(linspace(-Lx/2, Lx/2, n));
eta = zeros(size(X));
for c = find(A > 0)'                                 % solo componentes con energia
    eta = eta + A(c)*cos(kx(c)*X + ky(c)*Y + arg0(c));   % arg del modelo: -w t + fase + k.r
end

% --- figura ---
f1 = figure('Units', 'centimeters', 'Position', [2 2 18 6.8], 'Color', 'w');
theme(f1, 'light');
tl = tiledlayout(f1, 1, 8, 'TileSpacing', 'compact', 'Padding', 'compact');
azul = [0.12 0.36 0.62];

ax1 = nexttile(tl, [1 3]); hold on; grid on; box on;
% el modelo es una suma finita de senoides: el espectro es discreto (una línea por f_n)
plot(fc, Sc, ':', 'Color', [0.55 0.55 0.55], 'LineWidth', 0.9);
stem(f, S, 'filled', 'Color', azul, 'MarkerSize', 2.5, 'LineWidth', 0.8);
plot([fp fp], [0 1.12*max(Sc)], '--', 'Color', [0.3 0.3 0.3]);
text(fp + 0.02*fp, 1.06*max(Sc), sprintf('f_p = 1/T_p = %.2g Hz', fp), 'FontSize', 8);
xlim([0.4 2.6]*fp); ylim([0 1.15*max(Sc)]);       % la cola hasta f_max = 4 f_p es casi nula
xlabel('Frecuencia f (Hz)'); ylabel('S(f_n) (m^2\cdots)');
title('Espectro P-M discreto (suma finita)', 'FontWeight', 'normal');
text(0.60, 0.80, {sprintf('H_s = %.3g m', Hs), sprintf('T_p = %.3g s', Tp), ...
    sprintf('\\Deltaf = %.3g Hz', df), sprintf('%d f_n \\times %d dir.', N, M)}, ...
    'Units', 'normalized', 'FontSize', 8, 'VerticalAlignment', 'top');
ax1.FontSize = 8;

ax2 = nexttile(tl, [1 3]);
exag = 120;                                          % exageracion vertical
zb = -1.6*max(abs(eta(:)));                          % fondo del bloque
surf(X, Y, eta, 'EdgeColor', 'none', 'FaceColor', 'interp'); hold on;
paso = 5;                                            % malla tenue, como en la referencia
mesh(X(1:paso:end, 1:paso:end), Y(1:paso:end, 1:paso:end), eta(1:paso:end, 1:paso:end) + 0.002, ...
    'EdgeColor', [1 1 1], 'EdgeAlpha', 0.30, 'FaceColor', 'none');
% paredes laterales del bloque, coloreadas con la misma escala
lados = {X(1,:), Y(1,:), eta(1,:); X(end,:), Y(end,:), eta(end,:); X(:,1)', Y(:,1)', eta(:,1)'; X(:,end)', Y(:,end)', eta(:,end)'};
for i = 1:4
    xs = lados{i,1}; ys = lados{i,2}; zs = lados{i,3};
    surf([xs; xs], [ys; ys], [zs; zb*ones(size(zs))], [zs; zb*ones(size(zs))], ...
        'EdgeColor', 'none', 'FaceColor', 'interp', 'FaceAlpha', 0.95);
end
colormap(ax2, oceano(256));
clim([zb max(eta(:))]);
cb = colorbar(ax2); cb.Label.String = '\eta (m)'; cb.FontSize = 8;
cb.Limits = [min(eta(:)) max(eta(:))];
daspect([1 1 1/exag]); axis tight off; view(-38, 32);
camlight('headlight'); lighting gouraud; material dull;
% punto de medicion (0,0) y marco local: los vectores se construyen en coordenadas de
% pantalla (z por exag) para que se vean ortogonales a la superficie dibujada
p0 = [0 0 eta0];
marco(ax2, p0, sx, sy, exag, 38);
title(sprintf('Superficie del mar en t^* = %.2f s', ts), 'FontWeight', 'normal');
text(0.5, -0.02, sprintf('%d m \\times %d m, escala vertical \\times%d', Lx, Lx, exag), 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.4 0.4 0.4]);
ax2.FontSize = 8;

% --- detalle en el origen: plano tangente y pendientes ---
ax3 = nexttile(tl, [1 2]); hold on;
e3 = 4;                                              % exageracion menor en el detalle
r = 12; idx = find(abs(X(1, :)) <= r);              % ventana de 24 m x 24 m
surf(X(idx, idx), Y(idx, idx), eta(idx, idx), 'EdgeColor', [1 1 1], 'EdgeAlpha', 0.25, ...
    'FaceColor', 'interp', 'FaceAlpha', 0.85);
colormap(ax3, oceano(256)); clim(ax3, [zb max(eta(:))]);
% plano tangente en (0,0)
[Pu, Pv] = meshgrid([-0.7 0.7]*r);
surf(Pu, Pv, eta0 + sx*Pu + sy*Pv, 'FaceColor', [1 0.85 0.3], 'FaceAlpha', 0.45, 'EdgeColor', [0.8 0.55 0]);
marco(ax3, p0, sx, sy, e3, 7);
% pendientes a lo largo de x y de y
L = 0.7*r;
plot3([0 L], [0 0], eta0 + [0 0], ':', 'Color', [0.2 0.2 0.2]);
plot3([L L], [0 0], eta0 + [0 sx*L], '-', 'Color', [0.80 0.10 0.10], 'LineWidth', 1.2);
plot3([0 0], [0 L], eta0 + [0 0], ':', 'Color', [0.2 0.2 0.2]);
plot3([0 0], [L L], eta0 + [0 sy*L], '-', 'Color', [0.10 0.55 0.10], 'LineWidth', 1.2);
daspect([1 1 1/e3]); axis tight off; view(-38, 32);
camlight('headlight'); lighting gouraud; material dull;
title('Detalle en (0, 0)', 'FontWeight', 'normal');
text(0.5, -0.02, {sprintf('\\partial\\eta/\\partialx = %.3f,  \\partial\\eta/\\partialy = %.3f', sx, sy), ...
    sprintf('\\theta_b = -atan(\\partial\\eta/\\partialx) = %.2f°', rad2deg(theta_b)), ...
    sprintf('\\alpha_b = -atan(\\partial\\eta/\\partialy) = %.2f°   (\\times%d)', rad2deg(alpha_b), e3)}, ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 7);
ax3.FontSize = 8;

exportgraphics(f1, fullfile(here, 'espectro_pm.png'), 'Resolution', 300);
exportgraphics(f1, fullfile(here, 'espectro_pm.pdf'), 'ContentType', 'image', 'Resolution', 300);
fprintf(['4 sqrt(m0) = %.3f m; 4 sqrt(sum A^2/2) = %.3f m; eta: min %.3f, max %.3f, std %.3f m\n' ...
    't* = %.2f s: pitch_b = %.3f°, roll_b = %.3f°, eta0 = %.3f m\n'], 4*sqrt(m0), ...
    4*sqrt(sum(A(:).^2)/2), min(eta(:)), max(eta(:)), std(eta(:)), ts, rad2deg(theta_b), rad2deg(alpha_b), eta0);
end

function marco(ax, p0, sx, sy, exag, Lp)
% Marco local de la base en p0: x_b y y_b tangentes a la superficie, z_b normal.
% Se arma en coordenadas de pantalla (z*exag) y se vuelve a datos.
tx = [1 0 sx*exag]; tx = tx/norm(tx);
ty = [0 1 sy*exag]; ty = ty/norm(ty);
nz = cross(tx, ty); nz = nz/norm(nz);
col = {[0.80 0.10 0.10], [0.10 0.55 0.10], [0.10 0.25 0.80]};
nom = {'x_b', 'y_b', 'z_b'}; v = {tx, ty, nz};
plot3(ax, p0(1), p0(2), p0(3), 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 4);
for j = 1:3
    d = Lp*v{j}; d(3) = d(3)/exag;
    quiver3(ax, p0(1), p0(2), p0(3), d(1), d(2), d(3), 0, 'Color', col{j}, 'LineWidth', 1.6, 'MaxHeadSize', 0.6);
    text(ax, p0(1) + 1.12*d(1), p0(2) + 1.12*d(2), p0(3) + 1.12*d(3), nom{j}, ...
        'FontSize', 8, 'FontWeight', 'bold', 'Color', col{j});
end
end

function c = oceano(n)
% Azul profundo -> azul -> cian -> blanco (crestas)
p = [0 0.05 0.15 0.40; 0.35 0.13 0.42 0.72; 0.65 0.35 0.70 0.88; 0.85 0.70 0.88 0.95; 1 0.97 0.99 1];
c = interp1(p(:,1), p(:,2:4), linspace(0, 1, n));
end
