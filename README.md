# LAB-DE-CONTROL-GR5

Modelado e identificación de sistemas: plataforma de estabilización **MARLUP**
(roll, pitch y heave) con tres actuadores hidráulicos.

## Estructura

```
CAD/                   Piezas y ensamble de SolidWorks (.SLDPRT / .SLDASM)
DOCS/                  Enunciados de actividades y avances
├── CERTIFICADOS/      Certificados de Simulink y Simscape
└── FIGS/              Figuras de resultados (.png / .fig)
MODELOS/
├── CINEMATICA/        Modelo completo: cinemática inversa, Kalman y control LQI
└── PISTON/            Modelo del actuador hidráulico y sus parámetros
```

## Uso

Requiere MATLAB/Simulink con Simscape (desarrollado en R2025b).

1. **Modelo completo:** abrir `MODELOS/CINEMATICA/`, correr `script_aaron.m`
   y simular `Model_aaron.slx`. El script agrega `CAD/` al path para cargar
   las piezas.
2. **Pistón:** abrir `MODELOS/PISTON/`, correr `MARLUP_hydr_params.m` y
   simular `MARLUP_hydraulic_model.slx`.
