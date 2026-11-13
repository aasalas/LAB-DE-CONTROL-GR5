function pil3_puerto(puerto)
% Fija en ctrl_pi3.slx el puerto serial para cargar el programa y para la comunicación PIL.
% Se especifica a mano porque el Support Package no autodetecta los clones con CH340.
%   pil3_puerto("COM8")   o   pil3_puerto   (usa el último puerto serial disponible)
if nargin < 1
    p = serialportlist("available");
    if isempty(p), error('No hay ningun puerto serial disponible: conecte el Arduino.'); end
    puerto = p(end);
end
puerto = char(puerto);
load_system('ctrl_pi3'); cs = getActiveConfigSet('ctrl_pi3');
d = get_param(cs, 'CoderTargetData');
d.HostBoardConnection.AppDownload_port_source = 'Manually Specify';
d.HostBoardConnection.AppDownload_COMPort_specify = puerto;
d.HostBoardConnection.PIL_port_source1 = 'Manually Specify';
d.HostBoardConnection.PIL_port_source2 = 'Manually Specify';
d.HostBoardConnection.PIL_COMPort_specify = puerto;
d.HostBoardConnection.PIL_baud = '115200(Default)';   % 921600 es poco fiable en un UNO a 16 MHz
set_param(cs, 'CoderTargetData', d);
save_system('ctrl_pi3');
fprintf('ctrl_pi3: PIL por %s a 115200 baud\n', puerto);
end
