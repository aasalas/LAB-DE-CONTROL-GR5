% Figuras del informe a partir de R (run_pil_all) o de resultados/resultados_pil.mat.
% Tema claro forzado: en R2025a+ las figuras heredan el tema oscuro del escritorio.
here = fileparts(mfilename('fullpath'));
if ~exist('R', 'var'), load(fullfile(here, 'resultados', 'resultados_pil.mat'), 'R'); end
if ~exist('figd', 'var'), figd = fullfile(here, 'figuras'); end
if ~isfolder(figd), mkdir(figd); end
claro = @(f) theme(f, 'light');

Lm = R.MiL; Li = R.PiL_ideal; Ln = R.PiL_todas;
f1 = figure('Units', 'centimeters', 'Position', [2 2 9 9]); claro(f1);
subplot(2,1,1); plot(Lm(:,1), Lm(:,3)*1e3, 'k-', Li(:,1), Li(:,3)*1e3, 'r--', 'LineWidth', 1.1);
grid on; ylabel('x (mm)'); legend('MiL', 'PiL ideal', 'Location', 'southeast'); xlim([0 4]);
subplot(2,1,2); plot(Li(:,1), (Li(:,3) - interp1(Lm(:,1), Lm(:,3), Li(:,1)))*1e3, 'b-', 'LineWidth', 1);
grid on; ylabel('x_{PiL}-x_{MiL} (mm)'); xlabel('t (s)'); xlim([0 4]);
exportgraphics(f1, fullfile(figd, 'mil_vs_pil_ideal.pdf'), 'ContentType', 'vector');

f2 = figure('Units', 'centimeters', 'Position', [2 2 9 12]); claro(f2);
subplot(3,1,1); plot(Lm(:,1), Lm(:,3)*1e3, 'k-', Li(:,1), Li(:,3)*1e3, 'r--', Ln(:,1), Ln(:,3)*1e3, 'b-.', 'LineWidth', 1.1);
grid on; ylabel('x (mm)'); legend('MiL', 'PiL ideal', 'PiL no ideal', 'Location', 'southeast'); xlim([0 4]);
subplot(3,1,2); plot(Lm(:,1), Lm(:,3)*1e3, 'k-', Li(:,1), Li(:,3)*1e3, 'r--', Ln(:,1), Ln(:,3)*1e3, 'b-.', 'LineWidth', 1.1);
grid on; ylabel('x (mm)'); xlim([1.2 4]); ylim([395 405]); title('Detalle cerca de la referencia');
subplot(3,1,3); stairs(Lm(:,1), Lm(:,5), 'k-'); hold on; stairs(Li(:,1), Li(:,5), 'r--'); stairs(Ln(:,1), Ln(:,5), 'b-.');
grid on; ylabel('u'); xlabel('t (s)'); xlim([0 4]);
exportgraphics(f2, fullfile(figd, 'comparacion_x_u.pdf'), 'ContentType', 'vector');

f3 = figure('Units', 'centimeters', 'Position', [2 2 9 6]); claro(f3);
nn = {'PiL_ideal','PiL_cuant','PiL_lin','PiL_hist','PiL_todas'}; hold on;
for c = 1:numel(nn), L = R.(nn{c}); plot(L(:,1), L(:,3)*1e3, 'LineWidth', 1); end
grid on; xlim([1.2 4]); ylim([395 405]); ylabel('x (mm)'); xlabel('t (s)');
legend(strrep(nn, '_', ' '), 'Location', 'southeast');
exportgraphics(f3, fullfile(figd, 'no_idealidades_detalle.pdf'), 'ContentType', 'vector');
