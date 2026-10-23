function M = metricas_pil(R, nombres)
% Metricas de la respuesta al escalon 0 -> 0.40 m en t = 0.5 s.
% R.(nombre) = [t ref x xm u est] a Ts; el caso 'MiL' es la referencia del RMSE.
yf = 0.40; t0 = 0.5; nz = @(v) subsref([v(:); NaN], struct('type','()','subs',{{1}}));
M = table();
for c = 1:numel(nombres)
    nom = nombres{c}; L = R.(nom);
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
end
