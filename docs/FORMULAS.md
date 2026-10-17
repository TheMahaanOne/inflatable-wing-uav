**Fixed-Wing UAV Design — Formula Reference**

*Iterative sizing + constraint (matching) analysis — uav_sizing.m*

Rectangular inflatable-wing RC UAV \| June 2026

Contents

Introduction

This reference lists every formula in the uav_sizing.m script, in the
order the code uses them, with each symbol defined and matched to its
code variable. All quantities are SI internally (kg, m, m/s, N, W);
component masses are entered in grams and converted to newtons. A
companion flowchart of the program flow is provided as a separate file
(flowchart.png).

Nomenclature

| **Symbol**      | **Meaning**                   | **Code variable**   | **Units** |
|-----------------|-------------------------------|---------------------|-----------|
| ρ               | ISA air density               | rho                 | kg/m³     |
| h               | operating altitude            | h_alt               | m         |
| g               | gravity                       | g                   | m/s²      |
| GSM             | wing skin areal density       | GSM                 | g/m²      |
| W0              | gross weight                  | W0                  | N         |
| S               | wing area                     | S                   | m²        |
| S_wet           | wetted area (=2.2 S)          | Swet                | m²        |
| b               | span                          | b                   | m         |
| c               | chord (=MAC)                  | c                   | m         |
| AR              | aspect ratio                  | AR                  | —         |
| CL_max          | max lift coefficient          | CLmax               | —         |
| CL              | cruise lift coefficient       | CL                  | —         |
| CD0             | parasite drag coefficient     | CD0                 | —         |
| e               | Oswald efficiency             | e                   | —         |
| V_stall         | stall speed                   | Vstall              | m/s       |
| V               | cruise speed (swept)          | V                   | m/s       |
| W/S             | wing loading (force)          | WS                  | N/m²      |
| η_prop, η_motor | prop / motor efficiency       | eta_prop, eta_motor | —         |
| Kv              | motor velocity constant       | Kv                  | RPM/V     |
| V_batt          | battery voltage               | Vbatt               | V         |
| P_draw          | max electrical power          | Pdraw               | W         |
| FM              | prop static figure of merit   | FM                  | —         |
| Cvh, Cvv        | tail volume coefficients      | Cvh, Cvv            | —         |
| Lt              | tail moment arm               | Lt                  | m         |
| RC              | required rate of climb        | RC                  | m/s       |
| x_np, x_cg      | neutral point / CG (frac MAC) | x_np, x_cg          | —         |
| SM              | static margin                 | SM                  | —         |

1\. Air Density (ISA Troposphere)

Density is computed from the operating altitude using the ISA
troposphere model rather than a fixed value:

*ρ* = 1.225 · (1 − 2.2557×10<sup>−5</sup> · *h*)<sup>4.2559</sup>

Component masses (grams) convert to weights (newtons) via *W* =
*m*\[g\]/1000 · *g*.

2\. Wing Loading (Stall + Margin)

The stall condition sets the maximum allowable wing loading; the design
value sits a chosen margin below it for safe slow flight:

(W/S)<sub>stall</sub> = ½ *ρV<sub>stall</sub>*<sup>2</sup>
*C<sub>Lmax</sub>*

*W*/*S* = (1 − margin/100) · (W/S)<sub>stall</sub>

This is a force-based loading (N/m²), consistent with the matching chart
in Section 12.

3\. Iterative Weight Convergence

Fixed (non-structural) weight collects the items that do not scale with
geometry; propulsion is treated as fixed hardware:

*W*<sub>fixed</sub> = *W*<sub>pay</sub> + *W*<sub>avio</sub> +
*W*<sub>batt</sub> + *W*<sub>prop</sub>

Each iteration computes area from the current gross weight, recomputes
the wing weight from the GSM fabric model (with a 12.5% allowance for
valves and reinforcement), and rebuilds the gross weight with the
contingency margin:

*S* = *W*<sub>0</sub> / (*W*/*S*), *S*<sub>wet</sub> = 2.2 *S*

*W*<sub>wing</sub> = 1.125 · ( GSM · *S*<sub>wet</sub> · *g* / 1000 )

*W*<sub>0,new</sub> = ( *W*<sub>fixed</sub> + *W*<sub>tail</sub> +
*W*<sub>wing</sub> ) · (1 + err/100)

*f*<sub>struct</sub> = ( *W*<sub>wing</sub> + *W*<sub>tail</sub> ) /
*W*<sub>0,new</sub>

**Convergence:** iterate until *ε* = \| *W*<sub>0,new</sub> −
*W*<sub>0</sub> \| / *W*<sub>0</sub> \< 0.01. Only the wing weight
scales with *W*<sub>0</sub> (through area), making this a stable
fixed-point iteration.

4\. Wing Geometry (Rectangular)

Two modes. Fixed aspect ratio derives the chord; fixed chord derives the
aspect ratio:

Mode AR: *b* = √(*AR* *S*), *c* = *b* / *AR*

Mode chord: *b* = *S* / *c*, *AR* = *b*<sup>2</sup> / *S*

MAC = *c*, WCL = (*W*<sub>0</sub>/*g*) / *S*<sup>3/2</sup>

MAC equals the chord for a rectangular wing. WCL is the wing cubic
loading (kg/m³) used as a class back-check.

5\. Stall-Speed Verification

After convergence, the actual stall speed is recomputed from the final
weight and area:

*V*<sub>stall,act</sub> = √( 2 *W*<sub>0</sub> / ( *ρSC<sub>Lmax</sub>*
) )

Because the design loading is set below the stall limit by the margin,
the actual stall speed comes out below the target by the factor √(W/S ÷
(W/S)ₛₜₐₗₗ) — a safe slow-flight buffer, not an error.

6\. Aerodynamic Efficiency

Maximum lift-to-drag, the lift coefficient that achieves it, and the
airspeed at that point:

(L/D)<sub>max</sub> = ½ √( *πARe* / *C<sub>D0</sub>* )

*C<sub>L,opt</sub>* = √( *C<sub>D0</sub>* *πARe* ), *V*<sub>L/Dmax</sub>
= √( 2 *W*<sub>0</sub> / ( *ρSC<sub>L,opt</sub>* ) )

L/D peaks at *V*<sub>L/Dmax</sub> (where induced drag equals parasite
drag) and falls off on both sides — this is why the L/D-vs-speed plot is
a curve with a maximum, not a monotonic line.

7\. Cruise Performance (Swept V = 10–15 m/s)

Evaluated at each 1 m/s step:

*C<sub>L</sub>* = 2 *W*<sub>0</sub> / ( *ρV*<sup>2</sup>*S* )

*C<sub>D</sub>* = *C<sub>D0</sub>* + *C<sub>L</sub>*<sup>2</sup> / (
*πARe* ), *L*/*D* = *C<sub>L</sub>* / *C<sub>D</sub>*

*T*<sub>req</sub> = *W*<sub>0</sub> / (*L*/*D*), *P*<sub>req</sub> =
*T*<sub>req</sub>*V*

*P*<sub>motor</sub> = *P*<sub>req</sub> / (
*η*<sub>prop</sub>*η*<sub>motor</sub> ), *T*/*W* = *T*<sub>req</sub> /
*W*<sub>0</sub>

Battery energy, endurance, and the capacity needed to meet the endurance
target:

*E*<sub>usable</sub> = (cap\[mAh\]/1000) · *V*<sub>batt</sub> · usable
*P*<sub>avail</sub> =
*η*<sub>prop</sub>*η*<sub>motor</sub>*P*<sub>draw</sub>

Endurance = *E*<sub>usable</sub> / *P*<sub>motor</sub> × 60 \[min\]

cap<sub>need</sub> = *P*<sub>motor</sub> · (End<sub>req</sub>/60) / (
*V*<sub>batt</sub> · usable ) · 1000 \[mAh\]

8\. Drag at Design Cruise

*q* = ½ *ρV*<sub>des</sub><sup>2</sup>, *C<sub>Di</sub>* =
*C<sub>D</sub>* − *C<sub>D0</sub>*, Drag = *T*<sub>req</sub> at
*V*<sub>des</sub>

9\. Tail Sizing (Volume-Coefficient Method)

*S*<sub>ht</sub> = *C*<sub>vh</sub> MAC *S* / *L*<sub>t</sub>,
*b*<sub>ht</sub> = √(*AR*<sub>h</sub>*S*<sub>ht</sub>), *c*<sub>ht</sub>
= *b*<sub>ht</sub>/*AR*<sub>h</sub>

*S*<sub>vt</sub> = *C*<sub>vv</sub>*bS* / *L*<sub>t</sub>,
*b*<sub>vt</sub> = √(*AR*<sub>v</sub>*S*<sub>vt</sub>), *c*<sub>vt</sub>
= *b*<sub>vt</sub>/*AR*<sub>v</sub>

10\. Propeller

RPM<sub>noload</sub> = *K<sub>v</sub>V*<sub>batt</sub>,
RPM<sub>load</sub> = 0.80 · RPM<sub>noload</sub>

*V*<sub>pitch</sub> = (RPM<sub>load</sub>/60) · (*P*<sub>in</sub> ·
0.0254), slip = ( *V*<sub>pitch</sub> − *V* ) / *V*<sub>pitch</sub> ×
100%

Static thrust from momentum (actuator-disk) theory, with figure of merit
FM derating the ideal value; available thrust-to-weight is then
computed, not assumed:

*A*<sub>disk</sub> = *π* (*D*<sub>in</sub> · 0.0254 / 2)<sup>2</sup>,
*P*<sub>shaft</sub> = *η*<sub>motor</sub>*P*<sub>draw</sub>

*T*<sub>static</sub> = FM · ( 2
*ρA*<sub>disk</sub>*P*<sub>shaft</sub><sup>2</sup> )<sup>1/3</sup>,
*T*/*W* = *T*<sub>static</sub> / *W*<sub>0</sub>

If *T*/*W* \< 0.30 the code flags it and suggests raising power,
increasing prop diameter, or reducing weight.

11\. Longitudinal Stability

*a*<sub>w</sub> = 2*πAR*/(*AR*+2), *a*<sub>t</sub> =
2*πAR*<sub>h</sub>/(*AR*<sub>h</sub>+2)

d*ε*/d*α* = 2 *a*<sub>w</sub> / (*πAR*), *a*<sub>tot</sub> =
*a*<sub>w</sub> + *a*<sub>t</sub>(*S*<sub>ht</sub>/*S*)(1−d*ε*/d*α*)

*x*<sub>np</sub> = 0.25 + (*a*<sub>t</sub>/*a*<sub>tot</sub>)
*C*<sub>vh</sub> (1−d*ε*/d*α*), SM = *x*<sub>np</sub> − *x*<sub>cg</sub>

Note: at low AR the simplified d*ε*/d*α* estimate becomes large and
approximate; treat the neutral point as indicative for stubby
(fixed-chord) wings.

12\. Constraint Matching Chart (T/W vs W/S)

All required-thrust curves are evaluated at the design cruise dynamic
pressure q. The design is feasible above every curve and left of the
stall line.

- **Stall (vertical line):** *W*/*S* =
  ½*ρV<sub>stall</sub>*<sup>2</sup>*C<sub>Lmax</sub>*

- **Cruise:** *T*/*W* = *qC<sub>D0</sub>*/(*W*/*S*) +
  (*W*/*S*)/(*qπARe*)

- **Cruise-optimum W/S:** (*W*/*S*)<sub>opt</sub> = *q*
  √(*C<sub>D0</sub>πARe*)

- **Climb:** *V*<sub>climb</sub> =
  √((2/*ρ*)(*W*/*S*)√(1/(3*C<sub>D0</sub>πARe*))), *T*/*W* =
  *RC*/*V*<sub>climb</sub> + 2√(*C<sub>D0</sub>*/(3*πARe*))

- **Hand launch:** *T*/*W* ≥ 0.30

**Fixed-chord coupling.** In fixed-chord mode the local aspect ratio
varies along the sweep, *AR*<sub>i</sub> =
(*W*<sub>0</sub>/(W/S)<sub>i</sub>)/*c*<sup>2</sup>, so each curve uses
its own *AR*. The plotted design point uses the computed available
*T*/*W* from Section 10.
