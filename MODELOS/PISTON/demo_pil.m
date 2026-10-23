function demo_pil(varargin)
% Demostracion en vivo del PiL: la planta corre en Simulink y el PI en el Arduino.
% Perfil de tres escalones, no idealidades del sensor activas, una trama corrupta
% inyectada a proposito y un tablero animado a tiempo real.
%   demo_pil                                  -> espera el boton "Iniciar"
%   demo_pil('esperar', false, 'video', true) -> arranca solo y graba resultados/demo/demo_pil.mp4
global PIL
op = struct('esperar', true, 'video', false, 'puerto', "COM6");
for i = 1:2:numel(varargin), op.(varargin{i}) = varargin{i+1}; end

here = fileparts(mfilename('fullpath')); cd(here);
evalin('base', sprintf('run(''%s'')', fullfile(here, '..', 'CINEMATICA', 'MARLUP_hydr_params.m')));
mdl = 'PiL'; load_system(mdl);
outd = fullfile(here, 'resultados', 'demo'); if ~isfolder(outd), mkdir(outd); end

% ---------------- escenario ----------------
Ts = 0.01; Tf = 9; N = round(Tf/Ts) + 1;
esc = [0 0; 0.5 0.40; 3.5 0.15; 6 0.30];               % [t ref] en s y m
perfil = @(t) esc(find(t >= esc(:,1) - 1e-9, 1, 'last'), 2);
kfalla = 700;                                          % t = 7.00 s, ya asentado
cada = 5;                                              % redibuja cada 5 muestras (20 fps)

D = nan(N, 6);                                         % [t ref x xm u rtt_ms]
nerr = 0; nseq = 0; t0w = []; ncuad = 0;

% ---------------- tablero ----------------
azul = [0 0.45 0.74]; rojo = [0.85 0.2 0.1]; gris = [0.5 0.5 0.5]; verde = [0.2 0.6 0.25];
fig = figure('Name', 'MARLUP - Processor-in-the-Loop', 'NumberTitle', 'off', 'Color', 'w', ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Units', 'pixels', 'Position', [40 40 1280 720], 'Resize', 'off');
theme(fig, 'light');
annotation(fig, 'textbox', [0.02 0.93 0.96 0.06], 'String', ...
    'MARLUP  |  Processor-in-the-Loop en vivo: planta en Simulink + PI en Arduino', ...
    'FontSize', 14, 'FontWeight', 'bold', 'EdgeColor', 'none', 'VerticalAlignment', 'middle');

% cilindro
axC = axes(fig, 'Position', [0.01 0.16 0.24 0.76]); hold(axC, 'on'); axis(axC, 'off');
xlim(axC, [-0.25 0.25]); ylim(axC, [-0.06 1.16]);
plot(axC, [-0.12 0.12], [-0.005 -0.005], 'k', 'LineWidth', 3);
pA = patch(axC, [-0.045 0.045 0.045 -0.045], [0 0 0 0], [0.35 0.6 0.9], 'EdgeColor', 'none');
pB = patch(axC, [-0.045 0.045 0.045 -0.045], [0 0 0.5 0.5], [0.75 0.87 1], 'EdgeColor', 'none');
pP = patch(axC, [-0.045 0.045 0.045 -0.045], [0 0 0.03 0.03], [0.25 0.25 0.3], 'EdgeColor', 'none');
pR = patch(axC, [-0.014 0.014 0.014 -0.014], [0.03 0.03 0.58 0.58], [0.72 0.72 0.75], 'EdgeColor', [0.4 0.4 0.4]);
pT = patch(axC, [-0.17 0.17 0.17 -0.17], [0.58 0.58 0.605 0.605], [0.2 0.2 0.2], 'EdgeColor', 'none');
rectangle(axC, 'Position', [-0.05 0 0.10 0.50], 'LineWidth', 2.5);
hRef = plot(axC, [-0.21 0.21], [0.58 0.58], '--', 'Color', rojo, 'LineWidth', 1.5);
tRef = text(axC, 0.21, 0.6, 'objetivo', 'Color', rojo, 'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'bottom', 'FontSize', 10);
text(axC, 0.065, 0.04, 'A', 'FontWeight', 'bold', 'FontSize', 11);
text(axC, 0.065, 0.46, 'B', 'FontWeight', 'bold', 'FontSize', 11);
tX = text(axC, 0, 1.12, '', 'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');

% indicador del comando de la valvula
axG = axes(fig, 'Position', [0.035 0.08 0.19 0.045]); hold(axG, 'on');
pG = patch(axG, [0 0 0 0], [-0.4 -0.4 0.4 0.4], azul, 'EdgeColor', 'none');
xline(axG, 0, 'k'); xlim(axG, [-1 1]); ylim(axG, [-0.5 0.5]); axG.YTick = []; axG.Box = 'on';
axG.XTick = [-1 0 1]; title(axG, 'Comando de la válvula u', 'FontWeight', 'normal', 'FontSize', 10);

% curvas
ax1 = axes(fig, 'Position', [0.30 0.56 0.43 0.34]); hold(ax1, 'on'); grid(ax1, 'on');
hr = plot(ax1, nan, nan, '--', 'Color', rojo, 'LineWidth', 1.3);
hx = plot(ax1, nan, nan, '-', 'Color', azul, 'LineWidth', 1.8);
xlim(ax1, [0 Tf]); ylim(ax1, [-20 460]); ylabel(ax1, 'Posición (mm)');
legend(ax1, [hx hr], {'x real (planta)', 'referencia'}, 'Location', 'northeast', 'AutoUpdate', 'off');
ax2 = axes(fig, 'Position', [0.30 0.33 0.43 0.16]); hold(ax2, 'on'); grid(ax2, 'on');
hu = stairs(ax2, nan, nan, '-', 'Color', verde, 'LineWidth', 1.4);
xlim(ax2, [0 Tf]); ylim(ax2, [-1.15 1.15]); ylabel(ax2, 'u (Arduino)');
ax3 = axes(fig, 'Position', [0.30 0.08 0.43 0.18]); hold(ax3, 'on'); grid(ax3, 'on');
hl = plot(ax3, nan, nan, '.', 'Color', gris, 'MarkerSize', 6);
xlim(ax3, [0 Tf]); ylim(ax3, [0 40]); ylabel(ax3, 'RTT UART (ms)'); xlabel(ax3, 't (s)');
yline(ax3, Ts*1e3, '--', 'T_s = 10 ms', 'Color', rojo, 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'top');
linkaxes([ax1 ax2 ax3], 'x');

% panel de estado
axT = axes(fig, 'Position', [0.76 0.08 0.23 0.82]); hold(axT, 'on'); axis(axT, 'off'); xlim(axT, [0 1]); ylim(axT, [0 1]);
mono = {'FontName', 'Consolas', 'FontSize', 11, 'Interpreter', 'none'};
text(axT, 0, 0.98, sprintf('Arduino UNO R3 · %s · 115200 baud', op.puerto), 'FontWeight', 'bold', 'FontSize', 11);
text(axT, 0, 0.93, 'PI Tustin  Kp=60  Ki=1  Ts=10 ms', 'FontSize', 10, 'Color', gris);
text(axT, 0, 0.89, 'Sensor: ADC 10 bits + sesgo + histéresis', 'FontSize', 10, 'Color', gris);
tT   = text(axT, 0, 0.82, '', mono{:});
text(axT, 0, 0.75, 'Simulink → MCU', 'FontSize', 10, 'Color', gris);
tTx  = text(axT, 0, 0.71, '', mono{:}, 'Color', azul);
text(axT, 0, 0.65, 'MCU → Simulink', 'FontSize', 10, 'Color', gris);
tRx  = text(axT, 0, 0.61, '', mono{:}, 'Color', verde);
tU   = text(axT, 0, 0.54, '', mono{:});
tCnt = text(axT, 0, 0.47, '', mono{:});
tLat = text(axT, 0, 0.40, '', mono{:});
hLed = plot(axT, 0.04, 0.31, 'o', 'MarkerSize', 16, 'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerEdgeColor', 'k');
text(axT, 0.11, 0.31, 'LED 13: válvula saturada', 'FontSize', 10);
tEv  = text(axT, 0, 0.20, '', 'FontSize', 10, 'Color', rojo, 'VerticalAlignment', 'top');
tFin = text(axT, 0, 0.06, '', 'FontSize', 10, 'FontWeight', 'bold', 'VerticalAlignment', 'top');

% ---------------- conexion con el Arduino ----------------
sp = serialport(op.puerto, 115200, 'Timeout', 2);
pause(2.5); flush(sp);                                 % el UNO se reinicia al abrir el puerto
write(sp, uint8([165 0 0 0 0 0]), 'uint8');
ack = read(sp, 6, 'uint8');
if numel(ack) ~= 6 || ack(1) ~= 90, error('El Arduino no respondió al reinicio (0x5A)'); end
tT.String = 'Arduino listo (ACK 0x5A)';

if op.esperar
    b = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Iniciar PiL', 'FontSize', 14, ...
        'Units', 'normalized', 'Position', [0.45 0.45 0.14 0.08], 'Callback', @(~, ~) uiresume(fig));
    uiwait(fig); delete(b);
end
if op.video
    % 1920x1080 a resolucion nativa de pantalla, H.264 liviano: el tablero es casi plano
    vw = VideoWriter(fullfile(outd, 'demo_pil.mp4'), 'MPEG-4'); vw.FrameRate = 1/(cada*Ts); vw.Quality = 60;
    open(vw);
end

PIL = struct('modo', 1, 'en_lin', 1, 'en_hist', 1, 'en_q', 1, 'sp', sp, 'nerr', 0, 'ulast', 0, ...
    'log', zeros(0, 6), 'demo', struct('ref', perfil, 'kfalla', kfalla, 'actualizar', @actualizar));
clear pil_ctrl
sim(mdl, 'StopTime', num2str(Tf));

% ---------------- cierre ----------------
rtt = D(:, 6);
tFin.String = sprintf(['Demo terminada: %d tramas\n%d error detectado (el inyectado)\n' ...
    'RTT medio %.1f ms, máx. %.1f ms'], nseq, nerr, mean(rtt, 'omitnan'), max(rtt));
drawnow;
if op.video
    img = cuadro();
    for i = 1:round(2/(cada*Ts)), writeVideo(vw, img); end            % 2 s de cuadro final
    close(vw);
end
exportgraphics(fig, fullfile(outd, 'demo_final.png'), 'Resolution', 150);
writematrix(D, fullfile(outd, 'demo_pil.csv'));
PIL.sp = []; clear sp
fprintf('demo_pil OK: %d tramas, %d errores, RTT medio %.2f ms\n', nseq, nerr, mean(rtt, 'omitnan'));

    function actualizar(k, ref, x, xm, u, est, rtt, tx, rx)
        n = k + 1; t = k*Ts;
        D(n, :) = [t ref x xm u rtt*1e3];
        nseq = nseq + 1;
        if est ~= 0
            nerr = nerr + 1;
            xline(ax1, t, ':', 'Color', rojo, 'LineWidth', 1.5);
            xline(ax2, t, ':', 'Color', rojo, 'LineWidth', 1.5);
            tEv.String = sprintf(['t = %.2f s: trama con checksum\ncorrupto inyectada a propósito\n' ...
                '→ MCU respondió estado = %d\n   y repitió el último u'], t, est);
        end
        if isempty(t0w), t0w = tic; end
        if mod(k, cada) ~= 0 && n ~= N, return; end
        espera = t - toc(t0w);                         % ritmo de tiempo real
        if espera > 0, pause(espera); end

        j = 1:n;
        set(hx, 'XData', D(j,1), 'YData', D(j,3)*1e3);
        set(hr, 'XData', D(j,1), 'YData', D(j,2)*1e3);
        set(hu, 'XData', D(j,1), 'YData', D(j,5));
        set(hl, 'XData', D(j,1), 'YData', D(j,6));
        lat = D(j,6);

        set(pA, 'YData', [0.005 0.005 x x]);
        set(pB, 'YData', [x+0.03 x+0.03 0.495 0.495]);
        set(pP, 'YData', [x x x+0.03 x+0.03]);
        set(pR, 'YData', [x+0.03 x+0.03 x+0.58 x+0.58]);
        set(pT, 'YData', [x+0.58 x+0.58 x+0.605 x+0.605]);
        set(hRef, 'YData', [ref ref] + 0.58); tRef.Position(2) = ref + 0.6;
        tX.String = sprintf('x = %6.1f mm', x*1e3);
        set(pG, 'XData', [0 u u 0], 'FaceColor', azul + (abs(u) >= 1)*(rojo - azul));

        tT.String = sprintf('t = %5.2f s    k = %3d', t, k);
        if ~isempty(tx)
            tTx.String = strjoin(cellstr(dec2hex(tx, 2))', ' ');
            tRx.String = strjoin(cellstr(dec2hex(rx, 2))', ' ');
            tU.String = sprintf('u = %+.3f  seq = %3d  est = %d', u, rx(4), rx(5));
        end
        tCnt.String = sprintf('Tramas: %d   Errores: %d', nseq, nerr);
        tLat.String = sprintf('RTT %.1f ms (prom %.1f)', rtt*1e3, mean(lat, 'omitnan'));
        hLed.MarkerFaceColor = [0.3 0.3 0.3] + (abs(u) >= 1)*([1 0.15 0.1] - [0.3 0.3 0.3]);

        if op.video, drawnow; writeVideo(vw, cuadro()); else, drawnow limitrate; end
    end

    function img = cuadro()
        img = print(fig, '-RGBImage', '-r0');
        if ~ncuad, fprintf('cuadro nativo: %dx%d\n', size(img, 2), size(img, 1)); end
        ncuad = ncuad + 1;
        img = img(1:min(end, 1080), 1:min(end, 1920), :);  % recorta o rellena a 1080p exacto
        img(end+1:1080, :, :) = 255; img(:, end+1:1920, :) = 255;
    end
end
