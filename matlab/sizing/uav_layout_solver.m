%% ========================================================================
%  FIXED-WING UAV -- LAYOUT SYNTHESIS / SIZING SOLVER
%  ------------------------------------------------------------------------
%  YOU SPECIFY:  wing (chord, span), airfoil data (CL, CD, CLmax), component
%                masses, propulsion/battery, and V-tail preferences.
%  THE CODE SOLVES FOR:
%       * tail moment arm  Lt
%       * V-tail area and panel geometry
%       * wing mounting station          (x_wLE)
%       * tail mounting station          (x_tail)
%       * battery station                (CG trim)
%       * overall aircraft length        (minimised)
%
%  OBJECTIVE:  shortest overall length, subject to
%       (a) minimum tail volume coefficients (control authority)
%       (b) static margin inside the target band
%       (c) V-tail area not exceeding a chosen fraction of wing area
%       (d) battery physically inside the fuselage pod
%
%  METHOD: the tail is sized by volume coefficient (S ~ 1/Lt), so a longer
%  boom shrinks the tail but lengthens the aircraft. The solver sweeps Lt
%  and the wing station, computes the neutral point for each candidate,
%  places the battery to hit the target static margin, rejects infeasible
%  layouts, and keeps the shortest survivor.
%
%  Coordinates: x measured AFT FROM THE NOSE [m]. Masses in GRAMS.
%% ========================================================================

clc; clear; close all;
fprintf('==============================================================\n');
fprintf('   UAV LAYOUT SYNTHESIS  --  solves fuselage, tail & stations\n');
fprintf('==============================================================\n\n');
g = 9.81;

%% ====================== 1. WING & AIRFOIL (given) ======================
fprintf('--- 1. WING & AIRFOIL DATA ---\n');
c     = ask('Wing chord (m)', 0.30);
b     = ask('Wing span  (m)', 1.00);
CLmax = ask('CL_max (airfoil/wing)', 1.20);
CL_cr = ask('Cruise CL', 0.70);
CD0   = ask('Parasite drag coefficient CD0', 0.035);
e     = ask('Oswald efficiency e', 0.80);
S = b*c;  MAC = c;  AR = b^2/S;
fprintf('S = %.4f m^2 | MAC = %.3f m | AR = %.2f\n', S, MAC, AR);

%% ====================== 2. ENVIRONMENT =================================
h_alt = ask('Operating altitude (m)', 50);
rho   = 1.225*(1-2.2557e-5*h_alt)^4.2559;

%% ====================== 3. COMPONENT MASSES (given) ====================
fprintf('\n--- 2. COMPONENT MASSES (g) ---\n');
m_motor = ask('Motor (g)', 240);
m_prop  = ask('Propeller (g)', 20);
m_pay   = ask('Payload (g)', 200);
m_avio  = ask('Avionics (g)', 20);
m_wing  = ask('Wing, measured (g)', 210);
m_batt  = ask('Battery (g)', 480);
err_pct = ask('Contingency margin (%)', 10);

% Stations of items fixed inside the nose/pod (aft of nose)
fprintf('\n--- 3. POD LAYOUT (fixed items, x aft of nose) ---\n');
L_pod   = ask('Fuselage pod length (m)', 0.25);
x_motor = ask('Motor station (m)', 0.02);
x_prop  = ask('Propeller station (m)', 0.005);
x_pay   = ask('Payload station (m)', 0.10);
x_avio  = ask('Avionics station (m)', 0.18);
x_b_min = ask('Battery: min station (m)', 0.02);
x_b_max = ask('Battery: max station (m)', L_pod);

%% ====================== 4. TAIL PREFERENCES ============================
fprintf('\n--- 4. V-TAIL PREFERENCES ---\n');
Gamma0  = ask('Preferred dihedral (deg)', 45);
Cvh_min = ask('Minimum horizontal tail volume coeff.', 0.35);
Cvv_min = ask('Minimum vertical   tail volume coeff.', 0.03);
ARv     = ask('V-tail aspect ratio', 3.5);
lamv    = ask('V-tail taper ratio', 0.70);
f_rud   = ask('Ruddervator chord fraction', 0.30);
k_pen   = ask('V-tail interference penalty', 1.10);
cap_S   = ask('Max V-tail area as fraction of wing', 0.30);
SM_lo   = ask('Static margin: lower bound', 0.08);
SM_hi   = ask('Static margin: upper bound', 0.18);
eta_t   = ask('Tail dynamic pressure ratio', 0.95);
tail_rho= ask('Tail areal mass (g/m^2, foam+servos)', 900);
boom_lin= ask('Boom mass per metre (g/m)', 35);
tail_ovh= ask('Structure aft of tail qc (m)', 0.05);

%% ====================== 5. LAYOUT SOLVER ===============================
% Sweep dihedral candidates (preferred first, then reduce if infeasible),
% tail arm, and wing station. Keep the shortest feasible aircraft.
Gam_list = unique([Gamma0, 40, 35, 30], 'stable');
Lt_list  = 0.20:0.01:0.90;
xw_list  = 0.03:0.005:0.30;

best = []; used_G = NaN;
for Gi = 1:numel(Gam_list)
    Gam = Gam_list(Gi);  Gr = deg2rad(Gam);
    for Lt = Lt_list
        % --- tail sized by the binding volume coefficient ---
        S_ht = Cvh_min*MAC*S/Lt;
        S_vt = Cvv_min*b*S/Lt;
        S_V  = k_pen*max(S_ht/cos(Gr)^2, S_vt/sin(Gr)^2);
        if S_V/S > cap_S, continue; end                      % tail too big

        % --- tail geometry & neutral point ---
        S_h_eff = S_V*cos(Gr)^2;
        b_V     = sqrt(ARv*S_V);
        span_pj = b_V*cos(Gr);
        ARh_eff = span_pj^2/S_h_eff;
        a_w  = 2*pi*AR/(AR+2);
        a_t  = 2*pi*ARh_eff/(ARh_eff+2);
        deps = 2*a_w/(pi*AR);
        Cvh_a= S_h_eff*Lt/(MAC*S);
        Cvv_a= S_V*sin(Gr)^2*Lt/(b*S);
        a_tot= a_w + eta_t*a_t*(S_h_eff/S)*(1-deps);
        x_np = 0.25 + eta_t*(a_t/a_tot)*Cvh_a*(1-deps);

        m_tail = S_V*tail_rho;                                % [g]

        for x_wLE = xw_list
            x_tail = x_wLE + 0.25*MAC + Lt;
            L_tot  = max(x_tail + tail_ovh, L_pod);
            m_boom = max(0, Lt-0.15)*boom_lin;
            x_boom = (x_wLE + MAC + x_tail)/2;

            % fixed-mass moment (everything except the battery)
            mm = [m_motor m_prop m_pay m_avio m_wing m_tail m_boom];
            xx = [x_motor x_prop x_pay x_avio x_wLE+0.42*MAC x_tail x_boom];
            M_fix = sum(mm);  Mom_fix = sum(mm.*xx);

            % battery station required to hit each static margin in the band
            for SM = SM_lo:0.005:SM_hi
                x_cg_t = x_wLE + (x_np - SM)*MAC;             % target CG [m]
                x_batt = (x_cg_t*(M_fix+m_batt) - Mom_fix)/m_batt;
                if x_batt >= x_b_min && x_batt <= min(x_b_max, x_wLE+MAC)
                    if isempty(best) || L_tot < best.L_tot
                        best.L_tot=L_tot; best.Lt=Lt; best.S_V=S_V; best.Gam=Gam;
                        best.x_wLE=x_wLE; best.x_tail=x_tail; best.x_batt=x_batt;
                        best.SM=SM; best.x_np=x_np; best.x_cg=x_cg_t;
                        best.m_tail=m_tail; best.m_boom=m_boom;
                        best.Cvh=Cvh_a; best.Cvv=Cvv_a; best.S_h_eff=S_h_eff;
                        best.ARh=ARh_eff; best.deps=deps; best.b_V=b_V;
                        best.span_pj=span_pj;
                    end
                    break                                      % smallest SM wins
                end
            end
        end
    end
    if ~isempty(best), used_G = Gam; break; end                % accept first feasible dihedral
end

if isempty(best)
    error(['No feasible layout found. Relax a constraint: raise the tail-area cap, ', ...
           'lower Cvh_min, widen the static-margin band, or allow the battery to move further aft.']);
end
if used_G ~= Gamma0
    fprintf('\n[!] Preferred dihedral %.0f deg was INFEASIBLE within the %.0f%% tail-area cap.\n', ...
            Gamma0, cap_S*100);
    fprintf('    Solver reduced dihedral to %.0f deg. (cos^2 penalty: 45 deg needs 2.0x the\n', used_G);
    fprintf('    horizontal area, %.0f deg needs %.2fx.)\n', used_G, 1/cosd(used_G)^2);
end

%% ====================== 6. RESULTING AIRCRAFT ==========================
m_total = (m_motor+m_prop+m_pay+m_avio+m_wing+m_batt+best.m_tail+best.m_boom)*(1+err_pct/100);
W0 = m_total/1000*g;   WS = W0/S;
Vstall = sqrt(2*W0/(rho*S*CLmax));
LDmax  = 0.5*sqrt(pi*AR*e/CD0);
CLopt  = sqrt(CD0*pi*AR*e);
V_LD   = sqrt(2*W0/(rho*S*CLopt));
V_mp   = V_LD/3^0.25;

% V-tail panel geometry
Gr = deg2rad(best.Gam);
L_pan = best.b_V/2;
c_bar = best.S_V/best.b_V;
c_r   = 2*c_bar/(1+lamv);
c_t   = lamv*c_r;
h_tail= L_pan*sin(Gr);
G_ideal = atand(sqrt((Cvv_min*b*S/best.Lt)/(Cvh_min*MAC*S/best.Lt)));

fprintf('\n==============================================================\n');
fprintf('                 SOLVED LAYOUT (shortest feasible)\n');
fprintf('==============================================================\n');
fprintf('OVERALL LENGTH        : %.3f m   <-- minimised\n', best.L_tot);
fprintf('  Fuselage pod        : %.3f m  (nose to %.3f)\n', L_pod, L_pod);
fprintf('  Nose length         : %.3f m  (nose to wing LE)\n', best.x_wLE);
fprintf('  Boom, wing TE->tail : %.3f m\n', best.x_tail-(best.x_wLE+MAC));
fprintf('TAIL MOMENT ARM Lt    : %.3f m  (%.2f x MAC)\n', best.Lt, best.Lt/MAC);
fprintf('--------------------------------------------------------------\n');
fprintf('MOUNTING STATIONS (aft of nose)\n');
fprintf('  Wing leading edge   : %.3f m\n', best.x_wLE);
fprintf('  Wing quarter-chord  : %.3f m\n', best.x_wLE+0.25*MAC);
fprintf('  V-tail quarter-chord: %.3f m\n', best.x_tail);
fprintf('  BATTERY             : %.3f m   <-- slide here to trim CG\n', best.x_batt);
fprintf('  Motor / payload     : %.3f / %.3f m\n', x_motor, x_pay);
fprintf('--------------------------------------------------------------\n');
fprintf('V-TAIL\n');
fprintf('  Dihedral            : %.0f deg   (ideal for these Cv: %.1f deg)\n', best.Gam, G_ideal);
fprintf('  Total area          : %.4f m^2  (%.0f%% of wing)\n', best.S_V, best.S_V/S*100);
fprintf('  Area per panel      : %.0f mm^2\n', best.S_V/2*1e6);
fprintf('  Panel length        : %.0f mm\n', L_pan*1000);
fprintf('  Chord root/tip      : %.0f / %.0f mm\n', c_r*1000, c_t*1000);
fprintf('  Projected span      : %.0f mm  |  height %.0f mm\n', best.span_pj*1000, h_tail*1000);
fprintf('  Ruddervator (%.0f%%)  : %.0f / %.0f mm\n', f_rud*100, c_r*f_rud*1000, c_t*f_rud*1000);
fprintf('  Delivered Cvh / Cvv : %.3f / %.3f\n', best.Cvh, best.Cvv);
fprintf('--------------------------------------------------------------\n');
fprintf('BALANCE\n');
fprintf('  Neutral point       : %.3f MAC  (%.3f m)\n', best.x_np, best.x_wLE+best.x_np*MAC);
fprintf('  CG (target)         : %.3f MAC  (%.3f m)\n', (best.x_cg-best.x_wLE)/MAC, best.x_cg);
fprintf('  STATIC MARGIN       : %.1f %%\n', best.SM*100);
fprintf('--------------------------------------------------------------\n');
fprintf('MASS & PERFORMANCE\n');
fprintf('  Tail %.0f g | boom %.0f g | TOTAL %.0f g (%.2f N)\n', best.m_tail, best.m_boom, m_total, W0);
fprintf('  Wing loading        : %.2f N/m^2\n', WS);
fprintf('  Stall speed         : %.2f m/s\n', Vstall);
fprintf('  (L/D)max            : %.2f at %.2f m/s\n', LDmax, V_LD);
fprintf('  Best-endurance speed: %.2f m/s\n', V_mp);
fprintf('==============================================================\n');

%% ====================== 7. TRADE STUDY =================================
% How overall length trades against tail area, at the chosen dihedral.
fprintf('\n--- TRADE: tail arm vs tail area vs length (dihedral %.0f deg) ---\n', best.Gam);
fprintf('%8s %10s %10s %12s\n','Lt[m]','S_V[m^2]','%% of wing','overall L[m]');
for Lt = 0.25:0.05:0.80
    S_ht=Cvh_min*MAC*S/Lt; S_vt=Cvv_min*b*S/Lt;
    S_Vt=k_pen*max(S_ht/cos(Gr)^2, S_vt/sin(Gr)^2);
    Lt_tot = best.x_wLE+0.25*MAC+Lt+tail_ovh;
    flag=''; if S_Vt/S>cap_S, flag=' (over cap)'; end
    fprintf('%8.2f %10.4f %9.0f%% %11.3f%s\n', Lt, S_Vt, S_Vt/S*100, Lt_tot, flag);
end

%% ====================== 8. LAYOUT PLOT =================================
figure('Color','w','Position',[80 80 980 340]); hold on; axis equal; grid on;
plot([0 best.L_tot],[0 0],'k-','LineWidth',2);
rectangle('Position',[0 -0.03 L_pod 0.06],'FaceColor',[0.92 0.92 0.92],'EdgeColor',[0.4 0.4 0.4]);
rectangle('Position',[best.x_wLE -0.006 MAC 0.012],'FaceColor',[0.55 0.78 1],'EdgeColor',[0 0 0.5]);
plot([best.x_tail best.x_tail],[0 h_tail],'-','Color',[0.2 0.55 0.2],'LineWidth',3);
plot(best.x_batt,0,'s','MarkerSize',10,'MarkerFaceColor',[1 0.6 0],'MarkerEdgeColor','k');
plot(best.x_cg,0,'ro','MarkerSize',11,'MarkerFaceColor','r');
plot(best.x_wLE+best.x_np*MAC,0,'bs','MarkerSize',11,'MarkerFaceColor','b');
plot([best.x_wLE+0.25*MAC best.x_tail],[-0.055 -0.055],'k-','LineWidth',1.2);
text(mean([best.x_wLE+0.25*MAC best.x_tail]),-0.072,sprintf('L_t = %.3f m',best.Lt),...
     'HorizontalAlignment','center','FontWeight','bold');
legend('Fuselage','','Wing','V-tail','Battery','CG','Neutral point','Location','northeast');
xlabel('x aft of nose [m]');
title(sprintf('Solved layout: overall %.3f m, tail %.0f%% of wing, SM %.1f%%', ...
      best.L_tot, best.S_V/S*100, best.SM*100));

%% ====================== HELPER =========================================
function val = ask(prompt, def)
    val = input([prompt, ' [', num2str(def), ']: ']);
    if isempty(val), val = def; end
end
