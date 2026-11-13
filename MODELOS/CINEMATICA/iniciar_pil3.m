%% INICIAR_PIL3  Prepara el workspace base para simular Model_aaron.slx (MiL) o Model_aaronC.slx (PiL).
% Es el InitFcn de ambos modelos: corre solo al presionar Run; no hace falta llamarlo a mano.
% Carga los parámetros hidráulicos y config_pil3.m (ganancias y no idealidades) y arma la
% estructura "sens" que leen los bloques del sensor dentro de "Controlador PiL".
here_ = fileparts(mfilename('fullpath'));
run(fullfile(here_, 'MARLUP_hydr_params.m'));
run(fullfile(here_, 'config_pil3.m'));

q_ = 0.45/1024;                                        % ADC de 10 bits sobre 450 mm
sens = struct('bias', 0.09e-3*en_lin, 'backlash', 0.004e-3*en_hist, ...
              'q', 1e-12, 'xmin', -inf, 'xmax', inf, 'ruido', ruido_mm*1e-3*en_ruido);
if en_q, sens.q = q_; sens.xmin = 0; sens.xmax = 1023*q_; end

% Mechanics Explorer: se abre o no según ver_mechanics (como InitFcn actúa sobre el modelo que simula)
if exist('bdroot', 'file') && ~isempty(bdroot) && bdIsLoaded(bdroot) && ...
        any(strcmp(bdroot, {'Model_aaron', 'Model_aaronC'}))
    if ver_mechanics, estado_ = 'on'; else, estado_ = 'off'; end
    set_param(bdroot, 'SimMechanicsOpenEditorOnUpdate', estado_);
    clear estado_
end
clear here_ q_
