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
add_block('simulink/Sources/In1', [c '/ref'], 'Position', [40 40 70 54], 'SampleTime', num2str(Ts), 'OutDataTypeStr', 'single');
add_block('simulink/Sources/In1', [c '/x'], 'Position', [40 100 70 114], 'SampleTime', num2str(Ts), 'OutDataTypeStr', 'single');
add_block('simulink/Math Operations/Sum', [c '/e'], 'Inputs', '+-', 'Position', [120 60 140 80]);
add_block('simulink/Discrete/Discrete PID Controller', [c '/PI'], 'Position', [190 50 290 90], ...
    'Controller', 'PI', 'P', '60', 'I', '1', 'SampleTime', num2str(Ts), ...
    'IntegratorMethod', 'Trapezoidal', 'LimitOutput', 'on', ...
    'UpperSaturationLimit', '1', 'LowerSaturationLimit', '-1', 'AntiWindupMode', 'clamping');
add_block('simulink/Sinks/Out1', [c '/u'], 'Position', [340 63 370 77]);
add_line(c, 'ref/1', 'e/1'); add_line(c, 'x/1', 'e/2');
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
src_ref = pc(1).SrcBlock; src_x = pc(2).SrcBlock; src_xp = pc(2).SrcPort;
dst_u = pc(3).DstBlock; dst_up = pc(3).DstPort;
lh = get_param(mf, 'LineHandles');
delete_line([lh.Inport lh.Outport]); delete_block(mf);
nom = @(h) get_param(h, 'Name');

p0 = get_param(dst_u, 'Position');                     % ubica lo nuevo bajo la planta
y0 = p0(4) + 60; x0 = p0(1) - 420;
add_block('simulink/Discrete/Zero-Order Hold', [m '/ZOH x'], 'SampleTime', num2str(Ts), 'Position', [x0+620 y0 x0+650 y0+30]);
add_block('simulink/Math Operations/Bias', [m '/Sesgo'], 'Bias', 'sens.bias', 'Position', [x0+500 y0 x0+540 y0+30]);
add_block('simulink/Discontinuities/Backlash', [m '/Histeresis'], 'BacklashWidth', 'sens.backlash', ...
    'InitialOutput', '0', 'Position', [x0+400 y0 x0+440 y0+30]);
add_block('simulink/Discontinuities/Quantizer', [m '/ADC'], 'QuantizationInterval', 'sens.q', 'Position', [x0+300 y0 x0+340 y0+30]);
add_block('simulink/Discontinuities/Saturation', [m '/Rango ADC'], 'UpperLimit', 'sens.xmax', ...
    'LowerLimit', 'sens.xmin', 'Position', [x0+200 y0 x0+240 y0+30]);
add_block('simulink/Discrete/Zero-Order Hold', [m '/ZOH ref'], 'SampleTime', num2str(Ts), 'Position', [x0+40 p0(2)-10 x0+70 p0(2)+20]);
add_block('simulink/Ports & Subsystems/Model', [m '/Controlador'], 'ModelName', 'ctrl_pi', ...
    'Position', [x0+130 p0(2)-10 x0+260 p0(2)+60]);
conv = 'simulink/Signal Attributes/Data Type Conversion';
add_block(conv, [m '/ref single'], 'OutDataTypeStr', 'single', 'Position', [x0+90 p0(2)-5 x0+110 p0(2)+15]);
add_block(conv, [m '/x single'], 'OutDataTypeStr', 'single', 'Position', [x0+90 y0 x0+120 y0+30]);
add_block(conv, [m '/u double'], 'OutDataTypeStr', 'double', 'Position', [x0+300 p0(2)+10 x0+330 p0(2)+30]);
for b = {'Sesgo', 'Histeresis', 'ADC', 'Rango ADC', 'x single'}, set_param([m '/' b{1}], 'Orientation', 'left'); end
set_param([m '/ZOH x'], 'Orientation', 'left');

add_line(m, [nom(src_ref) '/1'], 'ZOH ref/1', 'autorouting', 'smart');
add_line(m, 'ZOH ref/1', 'ref single/1', 'autorouting', 'smart');
add_line(m, 'ref single/1', 'Controlador/1', 'autorouting', 'smart');
add_line(m, 'Controlador/1', 'u double/1', 'autorouting', 'smart');
add_line(m, 'u double/1', [nom(dst_u) '/' num2str(dst_up + 1)], 'autorouting', 'smart');
add_line(m, [nom(src_x) '/' num2str(src_xp + 1)], 'ZOH x/1', 'autorouting', 'smart');
add_line(m, 'ZOH x/1', 'Sesgo/1', 'autorouting', 'smart');
add_line(m, 'Sesgo/1', 'Histeresis/1', 'autorouting', 'smart');
add_line(m, 'Histeresis/1', 'ADC/1', 'autorouting', 'smart');
add_line(m, 'ADC/1', 'Rango ADC/1', 'autorouting', 'smart');
add_line(m, 'Rango ADC/1', 'x single/1', 'autorouting', 'smart');
add_line(m, 'x single/1', 'Controlador/2', 'autorouting', 'smart');

% registro a Ts: t, ref, x real, x medida, u
reg = {'log_ref', 'ZOH ref'; 'log_x', 'ZOH x'; 'log_xm', 'Rango ADC'; 'log_u', 'u double'};
for i = 1:size(reg, 1)
    blk = [m '/' reg{i,1}];
    add_block('simulink/Sinks/To Workspace', blk, 'VariableName', reg{i,1}, 'SaveFormat', 'Array', ...
        'SampleTime', num2str(Ts), 'Position', [x0+700 y0+60*i x0+770 y0+60*i+25]);
    add_line(m, [reg{i,2} '/1'], [reg{i,1} '/1'], 'autorouting', 'smart');
end
set_param([m '/Controlador'], 'SimulationMode', 'Processor-in-the-loop (PIL)');   % se abre ya en modo PIL
save_system(m);
disp('pil_oficial_setup OK');
