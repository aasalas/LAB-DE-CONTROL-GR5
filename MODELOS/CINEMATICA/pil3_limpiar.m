function pil3_limpiar
% Fuerza una compilación limpia de ctrl_pi3 para el PIL. Si el código se da por "al día"
% (carpeta slprj o caché ctrl_pi3.slxc), la aplicación PIL se arma sin wrapper.mk y el make falla.
here = fileparts(mfilename('fullpath'));
clear mex
d = fullfile(here, 'slprj', 'ert', 'ctrl_pi3');
if isfolder(d), rmdir(d, 's'); end
f = fullfile(here, 'ctrl_pi3.slxc');
if isfile(f), delete(f); end
end
