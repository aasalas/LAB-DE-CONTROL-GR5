% Compila y sube pil_arduino.ino al Arduino UNO con el arduino-cli del IDE.
here = fileparts(mfilename('fullpath'));
if ~isfolder(fullfile(here, 'logs')), mkdir(fullfile(here, 'logs')); end
fid = fopen(fullfile(here, 'logs', 'log_subida.txt'), 'w');
ports = serialportlist("available");
fprintf(fid, 'Puertos: %s\n', strjoin(ports, ', '));
cands = {fullfile(getenv('ProgramFiles'), 'Arduino IDE', 'resources', 'app', 'lib', 'backend', 'resources', 'arduino-cli.exe'), ...
         fullfile(getenv('LOCALAPPDATA'), 'Programs', 'Arduino IDE', 'resources', 'app', 'lib', 'backend', 'resources', 'arduino-cli.exe'), ...
         'arduino-cli'};
cli = 'arduino-cli';
for i = 1:2
    if isfile(cands{i}), cli = cands{i}; break; end
end
fprintf(fid, 'CLI: %s\n', cli);
if isempty(ports), fprintf(fid, 'ERROR: no hay puerto serial\n'); fclose(fid); error('Sin puerto'); end
port = ports(end);
PIL_PORT = port; %#ok<NASGU>
cmd = sprintf('"%s" compile --jobs 1 --upload -p %s --fqbn arduino:avr:uno "%s"', cli, port, fullfile(here, 'pil_arduino'));
fprintf(fid, 'CMD: %s\n', cmd);
[st, out] = system(cmd);
fprintf(fid, 'STATUS: %d\n%s\n', st, out);
fclose(fid);
assignin('base', 'PIL_PORT', port);
fprintf('Subida terminada (status %d) en %s\n', st, port);
if st ~= 0, error('Fallo la compilacion/subida: ver logs/log_subida.txt'); end
