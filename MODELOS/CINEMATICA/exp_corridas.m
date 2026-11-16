function T = exp_corridas(corridas, archivo, varargin)
% EXP_CORRIDAS  Ejecuta una tabla de corridas de correr_pil3 y guarda las métricas tras cada una.
%   T = exp_corridas(corridas, 'exp2_final', 'Hs', 2)      (ver exp2_final.m)
% corridas: tabla con columnas id (string), modo ('mil'|'pil'), K, Kp, Ki, Usat y, opcional,
%   noideal (fila [lin hist q ruido]; por defecto sensor ideal) y Kff (prealimentación; por defecto 0).
% Guarda DOCS/AVANCES/AVANCE 3/resultados/<archivo>.mat (con las señales) y .csv (métricas).
% Si <archivo>.mat ya existe, omite las corridas hechas (se puede reanudar tras una falla).
% Opciones (nombre, valor): 'TMax' (600 s: corte de una corrida, informativo), 'Tsim' (30), 'Hs' (2), 'Tp' (10).
% Una corrida que falla, o cuyo pico supera al de K = 0 (corrida con K = 0 del mismo lote), se marca inestable.
p = inputParser; addParameter(p,'Tsim',30); addParameter(p,'Hs',2); addParameter(p,'Tp',10); addParameter(p,'TMax',600);
parse(p, varargin{:}); o = p.Results;
here = fileparts(mfilename('fullpath'));
dir_res = fullfile(here, '..', '..', 'DOCS', 'AVANCES', 'AVANCE 3', 'resultados');
if ~isfolder(dir_res), mkdir(dir_res); end
f_mat = fullfile(dir_res, [archivo '.mat']); f_csv = fullfile(dir_res, [archivo '.csv']);
R = struct(); if isfile(f_mat), load(f_mat, 'R'); end
cols = {'id','modo','K','Kp','Ki','Usat','estable','t_sim_s','pico_pitch','rms_pitch','pico_roll','rms_roll', ...
        'urms_max','sat_pct_max','atten_pitch_dB','atten_roll_dB'};
for i = 1:height(corridas)
    c = corridas(i,:); id = char(c.id);
    if isfield(R, matlab.lang.makeValidName(id)), fprintf('[%s] ya hecha, se omite\n', id); continue; end
    fprintf('\n=== Corrida %s (%d/%d): %s K=%g Kp=%g Ki=%g Usat=%g ===\n', id, i, height(corridas), c.modo, c.K, c.Kp, c.Ki, c.Usat);
    r = struct('id', id, 'modo', char(c.modo), 'K', c.K, 'Kp', c.Kp, 'Ki', c.Ki, 'Usat', c.Usat, 'estable', false);
    ni = [0 0 0 0]; if any(strcmp(corridas.Properties.VariableNames, 'noideal')), ni = c.noideal; end   % [lin hist q ruido]
    r.noideal = ni;
    kff = 0; if any(strcmp(corridas.Properties.VariableNames, 'Kff')), kff = c.Kff; end   % prealimentación
    r.Kff = kff;
    t0 = tic;
    try
        res = correr_pil3(char(c.modo), 'K', c.K, 'Kp', c.Kp, 'Ki', c.Ki, 'Usat', c.Usat, ...
            'Hs', o.Hs, 'Tp', o.Tp, 'Tsim', o.Tsim, 'NoIdeal', ni, 'Kff', kff, 'Figura', false);
        r.res = res; r.estable = true;
    catch err
        % errores de código (no de la simulación) detienen el lote: no son corridas inestables
        % la ola inviable (correr_pil3:ola) también detiene el lote: no se lanza una corrida que se interrumpiría
        if contains(err.identifier, 'UndefinedFunction') || contains(err.message, 'File:') || ...
                strcmp(err.identifier, 'correr_pil3:ola'), rethrow(err); end
        r.error = err.message; fprintf(2, 'FALLÓ: %s\n', err.message);
    end
    r.t_sim_s = toc(t0);
    if r.t_sim_s > o.TMax, fprintf('Aviso: la corrida pasó de %g s\n', o.TMax); end
    R.(matlab.lang.makeValidName(id)) = r;
    save(f_mat, 'R');                                   % tras cada corrida
    escribir_csv(R, cols, f_csv);
end
T = readtable(f_csv);
end

function escribir_csv(R, cols, f)
ids = fieldnames(R); base = [];
for i = 1:numel(ids), r = R.(ids{i}); if isfield(r,'res') && r.K == 0, base = r.res; end, end
rows = cell(numel(ids), numel(cols));
for i = 1:numel(ids)
    r = R.(ids{i}); v = {r.id, r.modo, r.K, r.Kp, r.Ki, r.Usat, r.estable, r.t_sim_s, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN};
    if isfield(r, 'res')
        s = r.res; v(9:14) = {s.pico_pitch, s.rms_pitch, s.pico_roll, s.rms_roll, max(s.u_rms), max(s.sat_pct)};
        if ~isempty(base)
            v{15} = 20*log10(s.rms_pitch/base.rms_pitch); v{16} = 20*log10(s.rms_roll/base.rms_roll);
            if s.pico_pitch > base.pico_pitch && r.K > 0, v{7} = false; end   % peor que sin compensar: inestable
        end
    end
    rows(i,:) = v;
end
writetable(cell2table(rows, 'VariableNames', cols), f);
end
