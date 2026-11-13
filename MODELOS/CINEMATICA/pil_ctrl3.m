function [u1, u2, u3] = pil_ctrl3(ref1, ref2, ref3, x1, x2, x3)
% Controlador de los 3 pistones. Se llama cada Ts = 10 ms desde el bloque MATLAB Function
% que reemplaza a PI_3_PISTONES en Model_aaronC.
%   PIL.modo = 0 -> MiL: tres PI en MATLAB (misma ecuacion que el Arduino)
%   PIL.modo = 1 -> PiL: manda las 3 posiciones medidas y las 3 referencias al Arduino
%                   por UART (trama de 14 bytes) y recibe u1, u2, u3 (trama de 10 bytes)
%   PIL.en_lin / en_hist / en_q -> no idealidades del sensor de cada cilindro
%   PIL.cfg.Kp / Ki / Usat      -> ganancias (en modo 1 se mandan al Arduino en pil3_iniciar)
% Preparar con pil3_iniciar antes de cada simulacion.
global PIL
persistent I e1 xb k
Ts = 0.01;
ref = [ref1; ref2; ref3];
x   = [x1; x2; x3];
if isempty(k)
    I = zeros(3,1); e1 = zeros(3,1); xb = x; k = 0;
end
cfg = PIL.cfg;

% ---- Modelo del sensor de cada cilindro (Bias -> Backlash -> Quantizer) ----
xm = x;
if PIL.en_lin,  xm = xm + 0.09e-3; end                 % error de linealidad (peor caso)
if PIL.en_hist                                         % histeresis: backlash de 0.004 mm
    w    = 0.004e-3;
    sube = xm > xb + w/2;
    baja = xm < xb - w/2;
    xb(sube) = xm(sube) - w/2;
    xb(baja) = xm(baja) + w/2;
    xm = xb;
end
if PIL.en_q                                            % ADC de 10 bits sobre 450 mm
    q  = 0.45/1024;
    xm = min(max(round(xm/q), 0), 1023)*q;
end

if PIL.modo == 0
    % MiL: PI posicional, integral por Tustin, anti-windup por clamping (igual que el MCU)
    e    = ref - xm;
    In   = I + cfg.Ki*Ts/2*(e + e1);
    v    = cfg.Kp*e + In;
    u    = min(max(v, -cfg.Usat), cfg.Usat);
    hold = (v > cfg.Usat & e > 0) | (v < -cfg.Usat & e < 0);
    I(~hold) = In(~hold);
    e1   = e;
    est  = 0;
else
    % PiL: 0xAA | x1 x2 x3 | r1 r2 r3 | XOR   (uint16, 0.01 mm, little-endian)
    xi = uint16(min(max(round(xm*1e5), 0), 65535));
    ri = uint16(min(max(round(ref*1e5), 0), 65535));
    f  = uint8([170, typecast(xi.', 'uint8'), typecast(ri.', 'uint8'), 0]);
    c  = uint8(0);
    for j = 1:13, c = bitxor(c, f(j)); end
    f(14) = c;
    write(PIL.sp, f, 'uint8');
    r   = uint8(read(PIL.sp, 10, 'uint8'));
    bad = (numel(r) ~= 10);
    if ~bad
        c = uint8(0);
        for j = 1:9, c = bitxor(c, r(j)); end
        bad = (r(1) ~= 85) || (c ~= r(10));
    end
    if bad
        PIL.nerr = PIL.nerr + 1;
        u = PIL.ulast; est = 2;                        % respuesta invalida: mantiene u
    else
        u   = double([typecast(r(2:3), 'int16'); typecast(r(4:5), 'int16'); ...
                      typecast(r(6:7), 'int16')]) / 32767;
        est = double(r(9));
        if est ~= 0, PIL.nerr = PIL.nerr + 1; end
    end
end

PIL.ulast = u(:);
PIL.log(end+1, :) = [k*Ts, ref.', x.', xm.', u(:).', est];   % 14 columnas
k  = k + 1;
u1 = u(1); u2 = u(2); u3 = u(3);
end
