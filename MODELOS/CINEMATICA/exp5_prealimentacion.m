%% EXP5_PREALIMENTACION  Lazo de nivelación con y sin prealimentación de la inclinación de la base.
% MiL (Model_aaron), g = 1, Kp = 20, Ki = 1, K = 3, sensor ideal, Hs = 2 m y Tp = 10, 7.5, 5.3 y
% 4.3 s (base de ~3°, 5°, 10° y 15°). Kff = 0: solo realimentación; Kff = 1: se suma
% -[roll; pitch] de la base al comando de ángulo. ~15 min.
% Resultados: DOCS/AVANCES/AVANCE 3/resultados/exp5_prealimentacion.mat
% Uso: cd MODELOS/CINEMATICA; exp5_prealimentacion
here = fileparts(mfilename('fullpath'));
f = fullfile(here, '..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'resultados', 'exp5_prealimentacion.mat');
R = struct(); if isfile(f), load(f, 'R'); end
Tps = [10 7.5 5.3 4.3];
for Tp = Tps
    for Kff = [0 1]
        id = matlab.lang.makeValidName(sprintf('Tp%g_ff%d', Tp, Kff));
        if isfield(R, id), fprintf('[%s] ya hecha\n', id); continue; end
        fprintf('\n=== Tp = %g s, Kff = %d ===\n', Tp, Kff);
        R.(id) = correr_pil3('mil', 'K', 3, 'Hs', 2, 'Tp', Tp, 'Kff', Kff, 'NoIdeal', [0 0 0 0], 'Figura', false);
        save(f, 'R');
    end
end
fprintf('\n%6s %10s %10s %10s %10s %8s\n', 'Tp', 'pitch FB', 'pitch FF', 'roll FB', 'roll FF', 'u_RMS FF');
for Tp = Tps
    a = R.(matlab.lang.makeValidName(sprintf('Tp%g_ff0', Tp))); b = R.(matlab.lang.makeValidName(sprintf('Tp%g_ff1', Tp)));
    fprintf('%6.1f %9.3f° %9.3f° %9.3f° %9.3f° %8.3f\n', Tp, a.pico_pitch, b.pico_pitch, a.pico_roll, b.pico_roll, max(b.u_rms));
end
