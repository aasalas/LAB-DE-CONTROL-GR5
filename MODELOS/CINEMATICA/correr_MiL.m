cd('C:\Users\Monika\Documents\II Semestre-2026\Lab de Control\Proyecto\CINEMATICA')
run('MARLUP_hydr_params.m')                      % parámetros hidráulicos
cfg = struct('Kp',6.7,'Ki',1,'Usat',0.1);        % ganancias del modelo
out = sim('Model_aaronC');

global PIL
t = PIL.log(:,1);
figure; hold on; grid on
c = lines(3);
for i = 1:3
    plot(t, PIL.log(:,1+i), '--', 'Color', c(i,:), 'DisplayName', sprintf('ref %d', i));
    plot(t, PIL.log(:,4+i),       'Color', c(i,:), 'DisplayName', sprintf('x %d', i));
end
legend show; xlabel('t (s)'); ylabel('posición (m)')