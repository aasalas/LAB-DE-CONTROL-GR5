function limpiar_pil
% Fuerza una compilacion limpia de ctrl_pi para el PIL. Si el codigo se da por "al dia"
% (carpeta slprj o cache ctrl_pi.slxc), la aplicacion PIL se arma sin wrapper.mk y el make falla.
here = fileparts(mfilename('fullpath'));
clear mex
d = fullfile(here, 'slprj', 'ert', 'ctrl_pi');
if isfolder(d), rmdir(d, 's'); end
f = fullfile(here, 'ctrl_pi.slxc');
if isfile(f), delete(f); end
end
