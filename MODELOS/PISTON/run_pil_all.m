% Corre MiL, PiL ideal y PiL no ideal (una no idealidad por corrida y todas juntas),
% calcula metricas y exporta figuras. Resultados en resultados/ y figuras/.
global PIL
here = fileparts(mfilename('fullpath'));
cd(here);
run(fullfile(here, '..', 'CINEMATICA', 'MARLUP_hydr_params.m'));
mdl = 'PiL'; load_system(mdl);
p = serialportlist("available");
HW = ~isempty(p);
if HW, PIL_PORT = p(end); outd = 'resultados'; figd = 'figuras';
else,  outd = fullfile('resultados', 'sin_hw'); figd = fullfile(outd, 'figuras'); end  % sin Arduino: todo en MATLAB
if ~isfolder(outd), mkdir(outd); end
if ~isfolder(figd), mkdir(figd); end
logf = fopen(fullfile(outd, 'log_corridas.txt'), 'w');
fprintf(logf, 'HW=%d\n', HW);

% nombre, modo, [en_lin en_hist en_q]
casos = {'MiL',        0, [0 0 0];
         'PiL_ideal',  1, [0 0 0];
         'PiL_cuant',  1, [0 0 1];
         'PiL_lin',    1, [1 0 0];
         'PiL_hist',   1, [0 1 0];
         'PiL_todas',  1, [1 1 1]};

if HW, sp = serialport(PIL_PORT, 115200, 'Timeout', 2); pause(2.5); flush(sp); else, sp = []; end
R = struct();
for c = 1:size(casos, 1)
    nom = casos{c,1};
    PIL = struct('modo', casos{c,2}*HW, 'en_lin', casos{c,3}(1), 'en_hist', casos{c,3}(2), ...
                 'en_q', casos{c,3}(3), 'sp', sp, 'nerr', 0, 'ulast', 0, 'log', zeros(0, 6));
    if PIL.modo == 1                                  % reinicia estados del MCU
        flush(sp); write(sp, uint8([165 0 0 0 0 0]), 'uint8');
        a = read(sp, 6, 'uint8');
        fprintf(logf, '%s reset ack: %s\n', nom, mat2str(a));
    end
    clear pil_ctrl
    tic; sim(mdl, 'StopTime', '4'); dt = toc;
    L = PIL.log;
    R.(nom) = L;
    writematrix(L, fullfile(outd, [nom '.csv']));
    fprintf(logf, '%s: %d muestras, %.1f s, errores trama %d\n', nom, size(L,1), dt, PIL.nerr);
end
PIL.sp = []; clear sp

% ---------------- metricas ----------------
yf = 0.40; t0 = 0.5; nz = @(v) subsref([v(:); NaN], struct('type','()','subs',{{1}}));
M = table();
for c = 1:size(casos, 1)
    nom = casos{c,1}; L = R.(nom);
    t = L(:,1); x = L(:,3); u = L(:,5);
    i = t >= t0; ts_ = t(i) - t0; xs = x(i); us = u(i);
    Mp  = max(0, (max(xs) - yf)/yf*100);
    t10 = nz(ts_(find(xs >= 0.1*yf, 1))); t90 = nz(ts_(find(xs >= 0.9*yf, 1))); tr = t90 - t10;
    fuera = nz(find(abs(xs - yf) > 0.02*yf, 1, 'last')); if isnan(fuera), tset = 0; else, tset = ts_(min(fuera+1, numel(ts_))); end
    ess = abs(yf - mean(xs(ts_ >= ts_(end) - 1)))*1e3;
    rmsu = sqrt(mean(us.^2));
    Lm = R.MiL; xmil = interp1(Lm(:,1), Lm(:,3), t(i));
    rmse = sqrt(mean((xs - xmil).^2))*1e3; emax = max(abs(xs - xmil))*1e3;
    xpk = (max(xs) - yf)*1e3;
    M = [M; table(string(nom), Mp, xpk, tr, tset, ess, rmsu, rmse, emax, ...
        'VariableNames', {'caso','Mp_pct','sobrepaso_mm','tr_s','ts_s','ess_mm','rms_u','rmse_vs_MiL_mm','emax_vs_MiL_mm'})]; %#ok<AGROW>
end
writetable(M, fullfile(outd, 'metricas.csv'));
disp(M);

% ---------------- figuras ----------------
figuras_pil

fprintf(logf, 'OK\n'); fclose(logf);
save(fullfile(outd, 'resultados_pil.mat'), 'R', 'M');
disp('run_pil_all OK');
