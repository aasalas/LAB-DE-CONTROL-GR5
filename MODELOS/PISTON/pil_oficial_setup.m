% Arma el PIL oficial de Simulink a partir de PiL.slx (que no se modifica):
%  - ctrl_pi.slx: controlador PI discreto (Tustin, saturacion +-1, anti-windup por clamping)
%    configurado para Arduino Uno; es el modelo que se compila y corre en el MCU.
%  - PiL_oficial.slx: planta + modelo del sensor en el host y un bloque Model que
%    referencia ctrl_pi en modo Normal (MiL) o Processor-in-the-loop (PIL).
here = fileparts(mfilename('fullpath')); cd(here);
Ts = 0.01;

% ---------------- controlador ----------------
c = 'ctrl_pi';
if bdIsLoaded(c), close_system(c, 0); end
if isfile([c '.slx']), delete([c '.slx']); end
new_system(c); load_system(c);
% interfaz en single: en el AVR un double ocupa 4 bytes y el PIL no admite double en la interfaz
add_block('simulink/Sources/In1', [c '/ref'], 'Position', [40 63 70 77], 'SampleTime', num2str(Ts), 'OutDataTypeStr', 'single');
add_block('simulink/Sources/In1', [c '/x'], 'Position', [40 133 70 147], 'SampleTime', num2str(Ts), 'OutDataTypeStr', 'single');
add_block('simulink/Math Operations/Sum', [c '/e'], 'Inputs', '|+-', 'IconShape', 'round', ...
    'Position', [120 60 140 80], 'ShowName', 'off');
add_block('simulink/Discrete/Discrete PID Controller', [c '/PI'], 'Position', [190 50 290 90], ...
    'Controller', 'PI', 'P', '60', 'I', '1', 'SampleTime', num2str(Ts), ...
    'IntegratorMethod', 'Trapezoidal', 'LimitOutput', 'on', ...
    'UpperSaturationLimit', '1', 'LowerSaturationLimit', '-1', 'AntiWindupMode', 'clamping');
add_block('simulink/Sinks/Out1', [c '/u'], 'Position', [340 63 370 77]);
add_line(c, 'ref/1', 'e/1', 'autorouting', 'on'); add_line(c, 'x/1', 'e/2', 'autorouting', 'on');
add_line(c, 'e/1', 'PI/1'); add_line(c, 'PI/1', 'u/1');
set_param(c, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', 'FixedStep', num2str(Ts), ...
    'SystemTargetFile', 'ert.tlc');
set_param(c, 'HardwareBoard', 'Arduino Uno');           % requiere el Support Package de Arduino
set_param(c, 'PropagateVarSize', 'During execution');   % exigido para SIL/PIL
save_system(c);
pil_puerto                                             % puerto del Arduino conectado

% ---------------- modelo host ----------------
m = 'PiL_oficial';
if bdIsLoaded(m), close_system(m, 0); end
if bdIsLoaded('PiL'), close_system('PiL', 0); end
load_system('PiL'); save_system('PiL', m);            % copia: PiL.slx queda igual en disco

mf = [m '/MATLAB Function'];
pc = get_param(mf, 'PortConnectivity');
step = pc(1).SrcBlock; planta = pc(3).DstBlock; up = pc(3).DstPort + 1;   % entrada u de la planta
xp = pc(2).SrcPort + 1;                                                    % salida x_cyl de la planta
scope = find_system(m, 'SearchDepth', 1, 'BlockType', 'Scope'); scope = scope{1};
delete_line(find_system(m, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line'));   % se redibuja todo
delete_block(mf);
nom = @(h) get_param(h, 'Name');
pos = @(x, y, w, h) [x y-h/2 x+w y+h/2];               % posicion por centro vertical

% Fila superior (y = 110): referencia -> controlador -> planta
yA = 110;
set_param(step, 'Position', pos(30, yA, 30, 30));
add_block('simulink/Discrete/Zero-Order Hold', [m '/ZOH ref'], 'SampleTime', num2str(Ts), 'Position', pos(100, yA, 30, 30));
conv = 'simulink/Signal Attributes/Data Type Conversion';
add_block(conv, [m '/ref single'], 'OutDataTypeStr', 'single', 'Position', pos(180, yA, 40, 30));
add_block('simulink/Ports & Subsystems/Model', [m '/Controlador'], 'ModelName', 'ctrl_pi', ...
    'Position', [270 yA-20 420 yA+60]);
add_block(conv, [m '/u double'], 'OutDataTypeStr', 'double', 'Position', pos(470, yA+20, 40, 30));
pp = get_param(planta, 'Position'); wp = pp(3) - pp(1); hp = pp(4) - pp(2);
set_param(planta, 'Position', [580 yA-50 580+wp yA-50+hp]);
ph = get_param(planta, 'PortHandles'); px = get_param(ph.Outport(xp), 'Position');
set_param(scope, 'Position', pos(px(1) + 110, px(2), 40, 40));

% Fila inferior (de derecha a izquierda): modelo del sensor con sus no idealidades
yB = yA - 50 + hp + 90;
sens_blk = {'simulink/Discrete/Zero-Order Hold', 'ZOH x', {'SampleTime', num2str(Ts)};
            'simulink/Math Operations/Bias', 'Sesgo', {'Bias', 'sens.bias'};
            'simulink/Discontinuities/Backlash', 'Histeresis', {'BacklashWidth', 'sens.backlash', 'InitialOutput', '0'};
            'simulink/Discontinuities/Quantizer', 'ADC', {'QuantizationInterval', 'sens.q'};
            'simulink/Discontinuities/Saturation', 'Rango ADC', {'UpperLimit', 'sens.xmax', 'LowerLimit', 'sens.xmin'};
            conv, 'x single', {'OutDataTypeStr', 'single'}};
for i = 1:size(sens_blk, 1)
    add_block(sens_blk{i,1}, [m '/' sens_blk{i,2}], sens_blk{i,3}{:}, ...
        'Orientation', 'left', 'Position', pos(px(1) + 40 - 100*i, yB, 40, 34));
end

add_line(m, [nom(step) '/1'], 'ZOH ref/1', 'autorouting', 'on');
add_line(m, 'ZOH ref/1', 'ref single/1', 'autorouting', 'on');
add_line(m, 'ref single/1', 'Controlador/1', 'autorouting', 'on');
add_line(m, 'Controlador/1', 'u double/1', 'autorouting', 'on');
add_line(m, 'u double/1', [nom(planta) '/' num2str(up)], 'autorouting', 'on');
add_line(m, [nom(planta) '/' num2str(xp)], [nom(scope) '/1'], 'autorouting', 'on');
add_line(m, [nom(planta) '/' num2str(xp)], 'ZOH x/1', 'autorouting', 'on');
for i = 1:size(sens_blk, 1) - 1
    add_line(m, [sens_blk{i,2} '/1'], [sens_blk{i+1,2} '/1'], 'autorouting', 'on');
end
add_line(m, 'x single/1', 'Controlador/2', 'autorouting', 'on');

% registro a Ts (t, ref, x real, x medida, u), cada uno junto a su fuente
reg = {'log_ref', 'ZOH ref', [170 30]; 'log_u', 'u double', [540 30]; ...
       'log_x', 'ZOH x', [px(1) - 60, yB + 80]; 'log_xm', 'Rango ADC', [px(1) - 460, yB + 80]};
for i = 1:size(reg, 1)
    add_block('simulink/Sinks/To Workspace', [m '/' reg{i,1}], 'VariableName', reg{i,1}, 'SaveFormat', 'Array', ...
        'SampleTime', num2str(Ts), 'Position', pos(reg{i,3}(1), reg{i,3}(2), 70, 26));
    add_line(m, [reg{i,2} '/1'], [reg{i,1} '/1'], 'autorouting', 'on');
end
set_param([m '/Controlador'], 'SimulationMode', 'Processor-in-the-loop (PIL)');   % se abre ya en modo PIL
save_system(m);
disp('pil_oficial_setup OK');
