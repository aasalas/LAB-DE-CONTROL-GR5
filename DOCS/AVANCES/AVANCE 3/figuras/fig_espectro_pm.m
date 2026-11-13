function fig_espectro_pm(Hs, Tp)
% FIG_ESPECTRO_PM  Figura del oleaje de Pierson-Moskowitz para el informe del Avance 3.
%   fig_espectro_pm            Hs = 0.5 m, Tp = 10 s (los del bloque P-M SPECTRUM)
%   fig_espectro_pm(Hs, Tp)    otro estado de mar
% Izquierda: espectro S(f) y su discretizacion. Derecha: superficie del mar eta(x, y, 0)
% con color segun la altura. Usa la misma discretizacion, dispersion direccional y semilla
% que la MATLAB Function de MODELOS/CINEMATICA/Model_aaronC.slx (P-M SPECTRUM), asi que
% la superficie es la misma realizacion que ve la simulacion.
% Escribe espectro_pm.pdf y espectro_pm.png junto a este archivo.
if nargin < 1, Hs = 0.5; end
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

% --- superficie eta(x, y, t = 0) ---
Lx = 160; n = 161;                                   % dominio de 160 m (~1 longitud de onda pico)
[X, Y] = meshgrid(linspace(-Lx/2, Lx/2, n));
eta = zeros(size(X));
for c = find(A > 0)'                                 % solo componentes con energia
    eta = eta + A(c)*cos(kx(c)*X + ky(c)*Y + fase(c));   % arg del modelo: -w t + fase + k.r
end

% --- figura ---
f1 = figure('Units', 'centimeters', 'Position', [2 2 18 7.5], 'Color', 'w');
theme(f1, 'light');
tl = tiledlayout(f1, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
azul = [0.12 0.36 0.62];

ax1 = nexttile(tl); hold on; grid on; box on;
stem(f, S, 'Marker', 'none', 'Color', [0.72 0.82 0.93], 'LineWidth', 0.6);
plot(fc, Sc, 'Color', azul, 'LineWidth', 1.8);
plot([fp fp], [0 1.12*max(Sc)], '--', 'Color', [0.3 0.3 0.3]);
plot([f_max f_max], [0 1.12*max(Sc)], ':', 'Color', [0.45 0.45 0.45]);
text(fp + 0.008, 1.06*max(Sc), sprintf('f_p = 1/T_p = %.1f Hz', fp), 'FontSize', 8);
text(f_max + 0.008, 0.55*max(Sc), 'f_{max} = 4f_p', 'FontSize', 8, 'Color', [0.35 0.35 0.35]);
xlim([0 0.5]); ylim([0 1.15*max(Sc)]);
xlabel('Frecuencia f (Hz)'); ylabel('S(f) (m^2\cdots)');
title('Espectro de Pierson-Moskowitz', 'FontWeight', 'normal');
text(0.40, 0.80, {sprintf('H_s = %.2f m', Hs), sprintf('T_p = %.0f s', Tp), ...
    sprintf('H_{m0} = 4\\surd{}m_0 = %.2f m', 4*sqrt(m0)), ...
    sprintf('%d f \\times %d dir.', N, M)}, ...
    'Units', 'normalized', 'FontSize', 8, 'VerticalAlignment', 'top');
legend({'componentes del modelo', 'S(f) continuo'}, 'FontSize', 7, 'Location', 'southeast');
ax1.FontSize = 8;

ax2 = nexttile(tl);
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
title(sprintf('Superficie del mar en t = 0 (%d m \\times %d m)', Lx, Lx), 'FontWeight', 'normal');
text(0.5, -0.02, sprintf('escala vertical exagerada \\times%d', exag), 'Units', 'normalized', ...
    'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.4 0.4 0.4]);
ax2.FontSize = 8;

exportgraphics(f1, fullfile(here, 'espectro_pm.png'), 'Resolution', 300);
exportgraphics(f1, fullfile(here, 'espectro_pm.pdf'), 'ContentType', 'image', 'Resolution', 300);
fprintf('Hm0 de S continuo = %.3f m; eta: min %.3f, max %.3f, std %.3f m (4 std = %.3f m)\n', ...
    4*sqrt(m0), min(eta(:)), max(eta(:)), std(eta(:)), 4*std(eta(:)));
end

function c = oceano(n)
% Azul profundo -> azul -> cian -> blanco (crestas)
p = [0 0.05 0.15 0.40; 0.35 0.13 0.42 0.72; 0.65 0.35 0.70 0.88; 0.85 0.70 0.88 0.95; 1 0.97 0.99 1];
c = interp1(p(:,1), p(:,2:4), linspace(0, 1, n));
end
