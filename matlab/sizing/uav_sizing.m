%% ========================================================================
%  FIXED-WING UAV DESIGN  --  ITERATIVE SIZING + CONSTRAINT (MATCHING) ANALYSIS
%  ------------------------------------------------------------------------
%  RC plane, rectangular wing, inflatable TPU-nylon skin (120 gsm).
%  Interactive: press ENTER at any prompt to accept the [default]. The
%  defaults reproduce the hardcoded baseline case.
%
%  MERGED FROM TWO VERSIONS + CORRECTIONS
%    Kept from the feature-rich version:
%      ISA air density from altitude; propulsion weight fixed; 15% W/S margin;
%      GSM wing-weight model (+12.5% valves/reinforcement); load-corrected RPM;
%      CL sanity flags; constraint chart, cruise-performance panel, weight pie.
%    Restored from the interactive version:
%      user prompts for every value; wing-definition MODE (fixed chord ->
%      derive AR, OR fixed AR -> derive chord); thrust-availability check.
%    CORRECTED:
%      [F1] Design-point T/W = max(launch, cruise, climb)  (old code plotted
%           the cruise value, which sits BELOW the hand-launch line = infeasible)
%      [F2] Stall verification reframed (a 15% W/S margin necessarily lowers
%           stall speed below target; that is SAFE, not an error)
%      [F3] Feasible-region shading clipped to W/S <= stall limit
%      [F4] Low-AR caveat noted on the simplified downwash model
%
%  References: Raymer (1992); Gudmundsson (2013); Nicolai & Carichner;
%  Anderson (2012); Cadogan et al. (2004, inflatable wing UAV).
%  Units: SI (kg, m, m/s, N, W). Masses entered in grams. MATLAB R2018b+.
%% ========================================================================

clc; clear; close all;

fprintf('==============================================================\n');
fprintf('   FIXED-WING UAV  --  ITERATIVE SIZING & CONSTRAINT ANALYSIS\n');
fprintf('   RC Plane | Inflatable TPU-Nylon Wing | 120 gsm | interactive\n');
fprintf('==============================================================\n\n');

%% ====================== FIXED PHYSICAL CONSTANTS =======================
g   = 9.81;     % gravitational acceleration   [m/s^2]
GSM = 120;      % wing skin areal density      [g/m^2]

%% ====================== AIR DENSITY (ISA TROPOSPHERE) ==================
fprintf('--- ENVIRONMENT ---\n');
h_alt = ask('Operating altitude (m)', 50);
rho   = 1.225 * (1 - 2.2557e-5 * h_alt)^4.2559;   % ISA density [kg/m^3]
fprintf('Air density (ISA)  : %.4f kg/m^3\n\n', rho);

%% ====================== MISSION & AERODYNAMIC INPUTS ===================
fprintf('--- MISSION & AERODYNAMIC INPUTS ---\n');
CLmax   = ask('Maximum lift coefficient CL_max', 1.2);
Vstall  = ask('Stall speed V_stall (8-9 m/s)', 8.5);
e       = ask('Oswald span efficiency e', 0.80);
CD0     = ask('Parasite drag coefficient CD0 (inflatable ~0.035)', 0.035);
Vc_lo   = ask('Cruise sweep lower bound (m/s)', 10);
Vc_hi   = ask('Cruise sweep upper bound (m/s)', 15);
End_req = ask('Endurance requirement (min)', 30);
margin  = ask('Design W/S margin below stall (%)', 15);

%% ---- Wing-definition MODE: fixed chord OR fixed aspect ratio ----------
fprintf('\n--- WING DEFINITION ---\n');
fprintf('  1 = fixed CHORD  -> derive aspect ratio\n');
fprintf('  2 = fixed ASPECT RATIO -> derive chord & span\n');
mode = ask('Choose mode', 1);
if mode == 2
    AR_fixed = ask('Wing aspect ratio AR', 6);
    c_fixed  = NaN;
else
    c_fixed  = ask('Wing chord (m)', 0.30);
    AR_fixed = NaN;
end

%% ====================== COMPONENT WEIGHTS (grams) ======================
fprintf('\n--- COMPONENT WEIGHTS (enter in grams) ---\n');
m_pay   = ask('Payload (g)',   200);
m_batt  = ask('Battery (g)',   480);
m_avio  = ask('Avionics (g)',   20);
m_wing  = ask('Wing (g) [initial guess]', 400);
m_tail  = ask('Tail (g)',       80);
m_motor = ask('Motor (g)',     240);
m_prop  = ask('Propeller (g)',  20);
err_pct = ask('Error / contingency margin (%)', 10);
% --- Wing weight model -------------------------------------------------
% Calibrated from a wing actually built and weighed (includes baffles,
% seams, adhesive, valves - which the skin-only GSM model omits).
USE_MEASURED = ask('Wing weight: 1 = measured calibration, 0 = GSM skin model', 1);
m_wing_meas  = 210;      % measured wing mass                    [g]
S_wing_meas  = 0.30;     % planform area of THAT wing (chord*span) [m^2]
if USE_MEASURED
    wing_areal = m_wing_meas / S_wing_meas;   % g per m^2 of planform
else
    wing_areal = 1.125 * GSM * 2.2;           % original skin-only model
end
fprintf('Wing model: %.0f g/m^2 planform (skin-only model gives %.0f)\n', ...
    wing_areal, 1.125*GSM*2.2);

toN = @(mg) mg/1000 * g;                 % grams -> Newtons
W_pay  = toN(m_pay);  W_batt = toN(m_batt);  W_avio = toN(m_avio);
W_tail = toN(m_tail);
W_propulsion = toN(m_motor + m_prop);    % motor + prop = propulsion (FIXED)
W_fixed_nonstruct = W_pay + W_avio + W_batt + W_propulsion;   % non-structural

%% ====================== PROPULSION & BATTERY ===========================
fprintf('\n--- PROPULSION & BATTERY ---\n');
eta_prop  = ask('Propeller efficiency eta_prop', 0.75);
eta_motor = ask('Motor efficiency eta_motor', 0.85);
TW_min    = ask('Min thrust-to-weight (hand launch)', 0.30);
RC        = ask('Required rate of climb RC (m/s)', 1.5);
Kv        = ask('Motor Kv (RPM/V)', 550);
Vbatt     = ask('Battery nominal voltage (V)', 11.1);
cap_mAh   = ask('Battery capacity (mAh)', 5000);
usable    = ask('Usable battery fraction', 0.80);
Pdraw     = ask('Max electrical power draw (W)', 150);

P_avail = eta_prop * eta_motor * Pdraw;     % shaft power available [W]
Eusable = cap_mAh/1000 * Vbatt * usable;    % usable energy         [Wh]

%% ====================== STEP 1: WING LOADING ===========================
WS_stall = 0.5 * rho * Vstall^2 * CLmax;    % stall boundary (max W/S) [N/m^2]
WS       = (1 - margin/100) * WS_stall;     % design W/S with margin   [N/m^2]
fprintf('\n--- WING LOADING ---\n');
fprintf('Stall boundary W/S : %.3f N/m^2\n', WS_stall);
fprintf('Design W/S (-%g%%)   : %.3f N/m^2\n', margin, WS);

%% ====================== ITERATIVE WEIGHT CONVERGENCE ===================
% Direct build-up: W0 = (fixed + tail + wing(W0)) * (1+err). Only the wing
% weight scales with W0 (through area). Propulsion is fixed hardware.
W0_old = W_fixed_nonstruct + toN(m_wing + m_tail);
fprintf('\n--- ITERATIVE WEIGHT CONVERGENCE ---\n');
fprintf('%4s  %8s  %10s  %9s  %8s  %8s\n','Iter','S[m^2]','W_wing[N]','f_struct','W0[N]','eps');
fprintf('%s\n', repmat('-',1,58));
converged = false;
for it = 1:100
    S    = W0_old / WS;                        % reference area [m^2]
    W_wing_tot = wing_areal * S * g / 1000;
    W0_new   = (W_fixed_nonstruct + W_tail + W_wing_tot) * (1 + err_pct/100);
    f_struct = (W_wing_tot + W_tail) / W0_new;
    epsilon  = abs(W0_new - W0_old) / W0_old;
    fprintf('%4d  %8.4f  %10.3f  %9.4f  %8.3f  %8.5f\n', it, S, W_wing_tot, f_struct, W0_new, epsilon);
    if epsilon < 0.01, converged = true; W0_old = W0_new; break; end
    W0_old = W0_new;
end
W0 = W0_old;  S = W0/WS;  Swet = 2.2*S;
W_wing_tot = 1.125 * (GSM * Swet * g / 1000);
f_struct   = (W_wing_tot + W_tail) / W0;
fprintf('%s\n', repmat('-',1,58));
if converged, fprintf('CONVERGED in %d iterations.\n', it);
else,         fprintf('[!] NOT converged in 100 iterations.\n'); end
fprintf('Gross weight W0    : %.3f N  (%.0f g)\n', W0, W0/g*1000);
fprintf('Wing area S        : %.4f m^2\n', S);
fprintf('Wing weight (GSM)  : %.3f N  (%.0f g)\n', W_wing_tot, W_wing_tot/g*1000);
fprintf('Structure fraction : %.1f%%\n', f_struct*100);

%% ====================== GEOMETRY (rectangular) =========================
if mode == 2
    AR = AR_fixed;  b = sqrt(AR*S);  c = b/AR;
else
    c  = c_fixed;   b = S/c;         AR = b^2/S;       % = S/c^2
end
MAC = c;
WCL = (W0/g) / S^1.5;
fprintf('\n--- WING GEOMETRY (rectangular) ---\n');
fprintf('Span b   : %.3f m   |   Chord c (=MAC) : %.3f m\n', b, c);
fprintf('AR       : %.2f      |   Wing cubic loading : %.2f kg/m^3 (RC: 8-15)\n', AR, WCL);
if     AR < 4,  fprintf('[!] Low AR (%.2f): reduced L/D and the simple downwash model is approximate.\n', AR);
elseif AR > 10, fprintf('[!] High AR (%.2f): structural challenge for an inflatable wing.\n', AR); end

%% ====================== STALL-SPEED VERIFICATION [F2] ==================
Vstall_act = sqrt(2*W0/(rho*S*CLmax));    % actual stall from converged W0,S
fprintf('\n--- STALL SPEED VERIFICATION ---\n');
fprintf('Target  V_stall : %.2f m/s\n', Vstall);
fprintf('Actual  V_stall : %.2f m/s  (lower, by design, due to the %g%% W/S margin)\n', Vstall_act, margin);
if Vstall_act > Vstall + 0.1
    fprintf('[!] Actual stall ABOVE target -> unsafe. Reduce W/S or raise CLmax.\n');
else
    fprintf('[OK] Actual stall at/below target -> safe slow-flight margin.\n');
end

%% ====================== (L/D)max =======================================
LDmax = 0.5 * sqrt(pi*AR*e/CD0);
fprintf('\n(L/D)max = 0.5*sqrt(pi*AR*e/CD0) = %.2f\n', LDmax);

%% ====================== CRUISE SWEEP ===================================
Vrange = Vc_lo:1:Vc_hi;  nV = numel(Vrange);
[CL,CD_arr,LD,Treq,Preq,Pmotor,TWreq,Endur] = deal(zeros(1,nV));
T_avail = TW_min * W0;
fprintf('\n--- CRUISE SWEEP (V = %d..%d m/s) ---\n', Vc_lo, Vc_hi);
fprintf('%3s %6s %7s %6s %7s %7s %8s %6s %7s  %s\n','V','CL','CD','L/D','T_req','P_req','P_motor','T/W','Endur','Status');
fprintf('%3s %6s %7s %6s %7s %7s %8s %6s %7s\n','m/s','-','-','-','N','W','W','-','min');
fprintf('%s\n', repmat('-',1,78));
for k = 1:nV
    V = Vrange(k);
    CL(k)     = 2*W0/(rho*V^2*S);
    CD_arr(k) = CD0 + CL(k)^2/(pi*AR*e);
    LD(k)     = CL(k)/CD_arr(k);
    Treq(k)   = W0/LD(k);
    Preq(k)   = Treq(k)*V;
    Pmotor(k) = Preq(k)/(eta_prop*eta_motor);
    TWreq(k)  = Treq(k)/W0;
    Endur(k)  = Eusable/Pmotor(k)*60;
    if     CL(k) > CLmax,        status='STALL';
    elseif CL(k) < 0.10,         status='LOW-CL';
    elseif Treq(k) > T_avail,    status='THR-LIM';
    elseif Pmotor(k) > Pdraw,    status='PWR-LIM';
    elseif Endur(k) < End_req,   status='LOW-END';
    else,                        status='OK';      end
    fprintf('%3d %6.3f %7.4f %6.2f %7.3f %7.2f %8.2f %6.4f %7.1f  %s\n', ...
            V,CL(k),CD_arr(k),LD(k),Treq(k),Preq(k),Pmotor(k),TWreq(k),Endur(k),status);
end
fprintf('%s\n', repmat('-',1,78));
fprintf('Available thrust (T/W=%.2f): %.3f N   |   Power available: %.1f W\n', TW_min, T_avail, P_avail);

%% ====================== ENDURANCE CHECK ================================
fprintf('\n--- ENDURANCE CHECK (requirement: %.0f min) ---\n', End_req);
ok = Vrange(Endur >= End_req);
if isempty(ok), fprintf('[!] No cruise speed meets %.0f min. Larger battery / lighter airframe needed.\n', End_req);
else,           fprintf('Speeds meeting %.0f min: %s m/s\n', End_req, mat2str(ok)); end
cap_need = Pmotor*(End_req/60)/(Vbatt*usable)*1000;
fprintf('Capacity needed for %.0f min: %.0f - %.0f mAh across range.\n', End_req, min(cap_need), max(cap_need));

%% ====================== DESIGN CRUISE & DRAG ===========================
Vdes = ask(sprintf('\nDesign cruise speed for drag/tail/chart (%d-%d)', Vc_lo, Vc_hi), 12);
idx  = max(1, min(nV, round(Vdes)-Vc_lo+1));
qd   = 0.5*rho*Vdes^2;
fprintf('--- DRAG at V = %g m/s ---\n', Vdes);
fprintf('q=%.2f Pa | CL=%.3f | CD0=%.4f | CDi=%.4f | CD=%.4f | L/D=%.2f | Drag=%.3f N\n', ...
        qd, CL(idx), CD0, CD_arr(idx)-CD0, CD_arr(idx), LD(idx), Treq(idx));

%% ====================== TAIL SIZING ====================================
fprintf('\n--- TAIL SIZING (volume-coefficient method) ---\n');
Cvh = ask('Horizontal tail volume coeff. Vh', 0.50);
Cvv = ask('Vertical   tail volume coeff. Vv', 0.04);
Lt  = ask('Tail moment arm Lt (m)', round(3*MAC,2));
ARh = ask('Horizontal tail aspect ratio', 4.0);
ARv = ask('Vertical   tail aspect ratio', 1.5);
S_ht = Cvh*MAC*S/Lt;  b_ht = sqrt(ARh*S_ht);  c_ht = b_ht/ARh;
S_vt = Cvv*b*S/Lt;    b_vt = sqrt(ARv*S_vt);  c_vt = b_vt/ARv;
fprintf('H-tail : S=%.4f m^2 | span=%.3f m | chord=%.3f m\n', S_ht, b_ht, c_ht);
fprintf('V-tail : S=%.4f m^2 | height=%.3f m | chord=%.3f m\n', S_vt, b_vt, c_vt);

%% ====================== PROPELLER ======================================
fprintf('\n--- PROPELLER ---\n');
D_in       = ask('Prop diameter (inches)', 10);
P_in       = ask('Prop pitch (inches)', 6);
FM         = ask('Prop static figure of merit (0.5-0.7)', 0.6);
RPM_noload = Kv*Vbatt;
RPM_load   = 0.80*RPM_noload;                 % ~20% drop under load
Vpit       = RPM_load/60 * (P_in*0.0254);
fprintf('No-load RPM %.0f | loaded RPM %.0f (80%%) | pitch speed %.2f m/s\n', RPM_noload, RPM_load, Vpit);
fprintf('Slip @ %d m/s : %.1f%%  |  Slip @ %d m/s : %.1f%%\n', Vc_lo,(Vpit-Vc_lo)/Vpit*100, Vc_hi,(Vpit-Vc_hi)/Vpit*100);
if Vpit <= Vc_hi, fprintf('[!] Pitch speed below top cruise speed: increase pitch or Kv.\n');
else,             fprintf('[OK] Pitch speed clears cruise range.\n'); end

% Static thrust from momentum theory (Anderson): T = FM*(2*rho*A_disk*P_shaft^2)^(1/3)
% Static thrust uses motor shaft power; prop eta_prop is a cruise term so FM is used instead.
A_disk    = pi*(D_in*0.0254/2)^2;             % propeller disk area [m^2]
P_shaft   = eta_motor * Pdraw;                 % shaft power for static thrust [W]
T_static  = FM * (2*rho*A_disk*P_shaft^2)^(1/3);   % static thrust [N]
TW_static = T_static / W0;                      % ACTUAL available thrust-to-weight
fprintf('Disk area %.4f m^2 | static thrust %.2f N | AVAILABLE T/W = %.3f (computed)\n', ...
        A_disk, T_static, TW_static);

%% ====================== LONGITUDINAL STABILITY ========================
fprintf('\n--- LONGITUDINAL STABILITY ---\n');
a_w = 2*pi*AR/(AR+2);  a_t = 2*pi*ARh/(ARh+2);
deps = 2*a_w/(pi*AR);                       % simplified downwash gradient
a_tot = a_w + a_t*(S_ht/S)*(1-deps);
x_ac = 0.25;
x_np = x_ac + (a_t/a_tot)*Cvh*(1-deps);
x_cg = ask('CG location as fraction of MAC', 0.28);
SM   = x_np - x_cg;
fprintf('a_w=%.3f /rad | a_t=%.3f /rad | dEps/dAlpha=%.3f\n', a_w, a_t, deps);
fprintf('NP=%.3f MAC | CG=%.3f MAC | Static margin=%.1f%% (rec. CG for 10%%: %.3f)\n', x_np, x_cg, SM*100, x_np-0.10);
if     SM <= 0,    fprintf('[!] CG at/behind NP -> UNSTABLE.\n');
elseif SM < 0.05,  fprintf('[!] SM < 5%% -> marginal.\n');
elseif SM > 0.20,  fprintf('[!] SM > 20%% -> very stable/sluggish.\n');
else,              fprintf('[OK] SM in 5-20%% range.\n'); end
if AR < 4, fprintf('    (Note: at AR=%.1f the dEps/dAlpha estimate is approximate.)\n', AR); end

%% ====================== CONSTRAINT MATCHING CHART ======================
WS_vec = linspace(5, 1.3*WS_stall, 400);
TW_cruise = zeros(size(WS_vec));  TW_climb = zeros(size(WS_vec));
for i = 1:numel(WS_vec)
    if mode == 2, AR_i = AR; else, AR_i = (W0/WS_vec(i))/c^2; end   % fixed chord -> AR varies
    TW_cruise(i) = qd*CD0/WS_vec(i) + WS_vec(i)/(qd*pi*AR_i*e);
    Vclimb_i     = sqrt((2/rho)*WS_vec(i)*sqrt(1/(3*CD0*pi*AR_i*e)));
    TW_climb(i)  = RC/Vclimb_i + 2*sqrt(CD0/(3*pi*AR_i*e));
end
% Required T/W at the design W/S (what the design MUST exceed)
TWc_des  = qd*CD0/WS + WS/(qd*pi*AR*e);                         % cruise requirement
Vcl_des  = sqrt((2/rho)*WS*sqrt(1/(3*CD0*pi*AR*e)));
TWcl_des = RC/Vcl_des + 2*sqrt(CD0/(3*pi*AR*e));               % climb requirement
TW_req   = max([TW_min, TWc_des, TWcl_des]);                    % binding requirement
% ACTUAL available T/W is COMPUTED from the propulsion (not forced):
TW_design = TW_static;
WS_opt = qd*sqrt(CD0*pi*AR*e);

% --- Thrust-to-weight check: flag if the actual T/W falls short -----------
fprintf('\n--- THRUST-TO-WEIGHT CHECK ---\n');
fprintf('Available (static) T/W : %.3f   [computed from prop diameter + power]\n', TW_design);
fprintf('Required T/W -> launch %.2f | cruise %.3f | climb %.3f | binding %.3f\n', ...
        TW_min, TWc_des, TWcl_des, TW_req);
if TW_design < TW_min
    fprintf('[!] T/W = %.3f is BELOW the 0.30 hand-launch threshold. Suggested changes:\n', TW_design);
    fprintf('    - Raise max power draw Pdraw (higher-C battery or larger motor)\n');
    fprintf('    - Use a larger-diameter propeller (more disk area = more static thrust)\n');
    fprintf('    - Reduce gross weight (lighter payload/battery/structure)\n');
    fprintf('    - Need T/W>=0.30 -> static thrust >= %.2f N (have %.2f N)\n', TW_min*W0, T_static);
elseif TW_design < TW_req
    fprintf('[!] T/W meets launch but is below the %.3f cruise/climb requirement.\n', TW_req);
    fprintf('    Increase power or prop diameter, or reduce drag (CD0) / weight.\n');
else
    fprintf('[OK] Available T/W %.3f exceeds all requirements (binding %.3f).\n', TW_design, TW_req);
end

figure('Color','k','Position',[100 100 820 560]); hold on; grid on; box on;
TW_curve = max([TW_cruise; TW_climb; TW_min*ones(size(WS_vec))], [], 1);
TWmax  = max([0.6, max(TW_curve(WS_vec<=WS_stall))*1.3, TW_design*1.15]);
mfeas  = WS_vec <= WS_stall;                                   % [F3] clip fill
xf = WS_vec(mfeas); yf = TW_curve(mfeas);
fill([xf fliplr(xf)], [yf TWmax*ones(size(xf))], [0.85 0.95 0.85], 'EdgeColor','none','FaceAlpha',0.35);
p1=plot(WS_vec,TW_cruise,'b-','LineWidth',2);
p2=plot(WS_vec,TW_climb,'g-','LineWidth',2);
p3=yline(TW_min,'m--','LineWidth',1.8);
p4=xline(WS_stall,'r--','LineWidth',1.8);
p5=plot(WS,TW_design,'kp','MarkerSize',15,'MarkerFaceColor','y','LineWidth',1.5);
xlabel('Wing Loading  W/S  [N/m^2]'); ylabel('Thrust-to-Weight  T/W  [-]');
title(sprintf('Constraint Matching Chart | V_{cruise}=%g m/s | W_0=%.0f g', Vdes, W0/g*1000));
legend([p1 p2 p3 p4 p5], {'Cruise (be above)','Climb (be above)', ...
    sprintf('Hand launch T/W>=%.2f',TW_min), sprintf('Stall limit %.1f N/m^2',WS_stall), ...
    sprintf('Design: available T/W=%.2f',TW_design)}, 'Location','northwest');
ylim([0 TWmax]); xlim([5 1.3*WS_stall]);
fprintf('\n--- MATCHING CHART ---\n');
fprintf('Stall W/S %.2f | Design W/S %.2f | Cruise-opt W/S %.2f\n', WS_stall, WS, WS_opt);
fprintf('Available T/W %.3f vs binding requirement %.3f (%s).\n', ...
        TW_design, TW_req, pickbind(TW_min,TWc_des,TWcl_des));

%% ====================== CRUISE PERFORMANCE PANEL =======================
figure('Color','k','Position',[950 100 720 560]);
subplot(2,2,1); plot(Vrange,CL,'b-o','LineWidth',1.5,'MarkerFaceColor','b');
yline(CLmax,'r--','CL_{max}'); xlabel('V [m/s]'); ylabel('C_L'); title('Lift Coefficient'); grid on;
subplot(2,2,2); plot(Vrange,LD,'g-o','LineWidth',1.5,'MarkerFaceColor','g'); hold on;
CL_opt = sqrt(CD0*pi*AR*e);  V_LDmax = sqrt(2*W0/(rho*S*CL_opt));   % speed at best L/D
yline(LDmax,'r--','(L/D)_{max}'); xline(V_LDmax,'b:','V_{L/Dmax}','LineWidth',1.2);
xlabel('V [m/s]'); ylabel('L/D'); title('Lift-to-Drag (peaks at best-L/D speed)'); grid on;
subplot(2,2,3); plot(Vrange,Preq,'r-o','LineWidth',1.5,'MarkerFaceColor','r'); hold on;
plot(Vrange,Pmotor,'m-s','LineWidth',1.5,'MarkerFaceColor','m'); yline(Pdraw,'k--','P_{draw}');
xlabel('V [m/s]'); ylabel('Power [W]'); title('Power'); legend('P_{req}','P_{motor}','Location','northwest'); grid on;
subplot(2,2,4); plot(Vrange,Endur,'k-o','LineWidth',1.5,'MarkerFaceColor','k');
yline(End_req,'r--',sprintf('%d min',End_req)); xlabel('V [m/s]'); ylabel('Endurance [min]'); title('Endurance'); grid on;
sgtitle('Cruise Performance Sweep','FontWeight','bold');

%% ====================== WEIGHT BREAKDOWN PIE ===========================
figure('Color','k','Position',[100 700 520 420]);
W_margin = max(W0 - (W_pay+W_batt+W_avio+W_wing_tot+W_tail+W_propulsion), 0);
vals   = [W_pay W_batt W_avio W_wing_tot W_tail W_propulsion W_margin];
labels = {'Payload','Battery','Avionics','Wing','Tail','Propulsion','Margin'};
pie(vals, labels);
title(sprintf('Weight Breakdown  (W_0 = %.0f g)', W0/g*1000));

%% ====================== FINAL SUMMARY =================================
fprintf('\n==============================================================\n');
fprintf('                    FINAL DESIGN SUMMARY\n');
fprintf('==============================================================\n');
fprintf('Gross weight W0    : %7.3f N  (%.0f g)\n', W0, W0/g*1000);
fprintf('Wing loading W/S   : %7.3f N/m^2  (stall limit %.2f)\n', WS, WS_stall);
fprintf('Wing area S        : %7.4f m^2\n', S);
fprintf('Span / chord       : %7.3f / %.3f m   (AR %.2f)\n', b, c, AR);
fprintf('Actual stall speed : %7.2f m/s\n', Vstall_act);
fprintf('(L/D)max           : %7.2f\n', LDmax);
[mLD,iLD] = max(LD);
fprintf('Best cruise L/D    : %7.2f  at %d m/s\n', mLD, Vrange(iLD));
fprintf('Endurance range    : %5.1f - %.1f min\n', min(Endur), max(Endur));
fprintf('H-tail / V-tail S  : %7.4f / %.4f m^2\n', S_ht, S_vt);
fprintf('NP / CG / SM       : %7.3f / %.3f MAC / %.1f%%\n', x_np, x_cg, SM*100);
fprintf('Design point       : W/S=%.2f N/m^2 , T/W=%.3f\n', WS, TW_design);
fprintf('==============================================================\n');

%% ====================== HELPER FUNCTIONS ===============================
function val = ask(prompt, def)
    val = input([prompt, ' [', num2str(def), ']: ']);
    if isempty(val), val = def; end
end
function s = pickbind(launch, cruise, climb)
    [~,i] = max([launch, cruise, climb]); names = {'hand-launch','cruise','climb'};
    s = names{i};
end
