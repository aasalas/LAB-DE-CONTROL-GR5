function u = pil_ctrl(ref, x)
% Controlador llamado cada Ts = 10 ms desde el bloque MATLAB Function.
%  PIL.modo = 0 -> MiL: PI incremental en MATLAB (misma ecuacion que el MCU)
%  PIL.modo = 1 -> PiL: envia la posicion medida al Arduino y recibe u por UART
%  PIL.en_lin / en_hist / en_q -> no idealidades del sensor (lado Simulink)
global PIL
persistent u1 e1 xb k
if isempty(k)
    u1 = 0; e1 = 0; k = 0; xb = x;
end
demo = isfield(PIL, 'demo');                          % demo_pil: perfil de referencia y tablero
if demo, ref = PIL.demo.ref(k*0.01); end
f = []; r = []; rtt = NaN;

% ---- Modelo del sensor (Bias -> Backlash -> Quantizer) ----
xm = x;
if PIL.en_lin,  xm = xm + 0.09e-3; end               % error de linealidad (peor caso)
if PIL.en_hist                                        % histeresis: backlash de 0.004 mm
    w = 0.004e-3;
    if xm > xb + w/2, xb = xm - w/2; elseif xm < xb - w/2, xb = xm + w/2; end
    xm = xb;
end
if PIL.en_q                                           % ADC de 10 bits sobre 450 mm
    q = 0.45/1024;
    xm = min(max(round(xm/q), 0), 1023)*q;
end

if PIL.modo == 0
    % PI posicional, integral por Tustin con anti-windup por clamping (igual que el MCU)
    Kp = 60; Ki = 1; Ts = 0.01;
    e  = ref - xm;
    In = u1 + Ki*Ts/2*(e + e1);      % u1 guarda el estado integral I[k-1]
    v  = Kp*e + In;
    u  = min(max(v, -1), 1);
    if ~((v > 1 && e > 0) || (v < -1 && e < 0)), u1 = In; end
    e1 = e;
    est = 0;
else
    xi = uint16(min(max(round(xm*1e5), 0), 65535));
    ri = uint16(min(max(round(ref*1e5), 0), 65535));
    xb8 = typecast(xi, 'uint8'); rb8 = typecast(ri, 'uint8');
    f = uint8([170 xb8 rb8 0]);
    f(6) = bitxor(bitxor(bitxor(bitxor(f(1), f(2)), f(3)), f(4)), f(5));
    if demo && k == PIL.demo.kfalla, f(6) = bitxor(f(6), 255); end   % trama corrupta a proposito
    t0 = tic;
    write(PIL.sp, f, 'uint8');
    r = uint8(read(PIL.sp, 6, 'uint8'));
    rtt = toc(t0);
    chk = bitxor(bitxor(bitxor(bitxor(r(1), r(2)), r(3)), r(4)), r(5));
    if numel(r) ~= 6 || r(1) ~= 85 || chk ~= r(6)
        PIL.nerr = PIL.nerr + 1;
        u = PIL.ulast; est = 2;                       % respuesta invalida: mantiene u
    else
        u = double(typecast(r(2:3), 'int16'))/32767;
        est = double(r(5));
        if est ~= 0, PIL.nerr = PIL.nerr + 1; end
    end
end

PIL.ulast = u;
PIL.log(end+1, :) = [k*0.01, ref, x, xm, u, est];
if demo, PIL.demo.actualizar(k, ref, x, xm, u, est, rtt, f, r); end
k = k + 1;
end
