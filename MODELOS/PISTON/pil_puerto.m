function pil_puerto(puerto)
% Fija en ctrl_pi.slx el puerto serial para cargar el programa y para la comunicacion PIL.
% Se especifica a mano porque el Support Package no autodetecta los clones con CH340.
%   pil_puerto("COM6")   o   pil_puerto   (usa el ultimo puerto serial disponible)
if nargin < 1
    p = serialportlist("available");
    if isempty(p), error('No hay ningun puerto serial disponible: conecte el Arduino.'); end
    puerto = p(end);
end
puerto = char(puerto);
load_system('ctrl_pi'); cs = getActiveConfigSet('ctrl_pi');
d = get_param(cs, 'CoderTargetData');
d.HostBoardConnection.AppDownload_port_source = 'Manually Specify';
d.HostBoardConnection.AppDownload_COMPort_specify = puerto;
d.HostBoardConnection.PIL_port_source1 = 'Manually Specify';
d.HostBoardConnection.PIL_port_source2 = 'Manually Specify';
d.HostBoardConnection.PIL_COMPort_specify = puerto;
d.HostBoardConnection.PIL_baud = '115200(Default)';   % 921600 es poco fiable en un UNO a 16 MHz
set_param(cs, 'CoderTargetData', d);
save_system('ctrl_pi');
fprintf('ctrl_pi: PIL por %s a 115200 baud\n', puerto);
end
