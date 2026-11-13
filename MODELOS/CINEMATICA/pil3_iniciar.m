function sp = pil3_iniciar(modo, cfg, en, puerto)
% Prepara una corrida del MiL o del PiL de los 3 pistones. Llamar ANTES de cada simulacion.
%   modo   : 0 = MiL (todo en MATLAB), 1 = PiL (controlador en el Arduino)
%   cfg    : struct con Kp, Ki, Usat (por defecto 60, 1, 1 = los validados en la Actividad 3)
%   en     : [lin hist q] no idealidades del sensor, 1 = activa (por defecto [1 1 1])
%   puerto : por ejemplo "COM6" (por defecto, el ultimo puerto disponible)
% Deja la estructura global PIL lista para pil_ctrl3. Al terminar: delete(sp); clear sp
%
% Ejemplos:
%   sp = pil3_iniciar(0);                                          % MiL con 60 / 1 / 1
%   sp = pil3_iniciar(1, struct('Kp',6.7,'Ki',1,'Usat',0.1));      % PiL con las ganancias del modelo
global PIL
clear pil_ctrl3                                        % reinicia los estados internos

if nargin < 1 || isempty(modo), modo = 0; end
def = struct('Kp', 6.7, 'Ki', 1, 'Usat', 0.1);
if nargin < 2 || isempty(cfg)
    cfg = def;
else
    campos = fieldnames(def);
    for i = 1:numel(campos)
        if ~isfield(cfg, campos{i}), cfg.(campos{i}) = def.(campos{i}); end
    end
end
if nargin < 3 || isempty(en), en = [1 1 1]; end

sp = [];
if modo == 1
    if nargin < 4 || isempty(puerto)
        p = serialportlist("available");
        assert(~isempty(p), 'No hay puertos seriales disponibles: conecte el Arduino.');
        puerto = p(end);
    end
    sp = serialport(puerto, 115200, 'Timeout', 2);
    pause(2.5); flush(sp);                             % el Arduino se reinicia al abrir el puerto

    % Trama de configuracion: 0xA5 | Kp Ki Usat (float32, little-endian) | XOR
    g = typecast(single([cfg.Kp cfg.Ki cfg.Usat]), 'uint8');      % 12 bytes
    f = uint8([165 g 0]);
    c = uint8(0);
    for j = 1:13, c = bitxor(c, f(j)); end
    f(14) = c;
    write(sp, f, 'uint8');
    r = uint8(read(sp, 10, 'uint8'));                  % respuesta: 0x5A | ... | estado | XOR
    assert(numel(r) == 10 && r(1) == 90 && r(9) == 0, ...
        'El Arduino no acepto la configuracion: revise que tenga cargado pil_arduino_3p y el puerto.');
end

PIL = struct('modo', modo, 'en_lin', en(1), 'en_hist', en(2), 'en_q', en(3), ...
             'sp', sp, 'nerr', 0, 'ulast', zeros(3,1), 'log', zeros(0, 14), 'cfg', cfg);
end
