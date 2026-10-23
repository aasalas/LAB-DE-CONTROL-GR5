% Ejecuta todo el flujo y deja un registro en resultados/diario.txt
here = fileparts(mfilename('fullpath')); cd(here);
if ~isfolder('resultados'), mkdir('resultados'); end
diary(fullfile('resultados', 'diario.txt')); diary on
try
    pil_setup
    subir_arduino
    run_pil_all
catch err
    disp(getReport(err, 'extended', 'hyperlinks', 'off'));
end
diary off
