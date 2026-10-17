%% ========================================================================
%  INFLATABLE-WING SKIN -> LASER-CUT LAYOUT (DXF + PNG)
%  ------------------------------------------------------------------------
%  Works on the output of "Bumpy_Airfoil_Dim_PhD_--__--.m" (that code is NOT
%  modified). It uses the DIMENSIONLESS (per-unit-chord) fabric-length arrays
%  left in the workspace:
%       circular_Fabric_length_Upper   (per unit chord)
%       circular_Fabric_length_Lower   (per unit chord)
%  and scales them by a chord YOU enter here. It does NOT use the old 'c'.
%
%  ==> RUN ORDER: run the PhD code, then run THIS on the dimensionless arrays
%      (case B: arrays are per-unit-chord, this code multiplies by your chord).
%
%  Layout (matches the manual drawing):
%    - Rectangle: width  = span  + 50 buffer each end
%                 height = 2*chord + 100 buffer each end
%      Vertical mid-line = wing LEADING EDGE. Above mid = upper surface,
%      below mid = lower surface.
%    - Horizontal 50 mm CUTS flush on BOTH left & right edges, stacked from
%      the mid-line: upward by upper lengths, downward by lower lengths.
%    - 20 mm floating OFFSET lines, 5 mm in from each edge, 10 mm above each
%      upper cut and 10 mm below each lower cut (both edges).
%    - Leading-edge CENTERLINE as a dashed CONSTRUCTION line (own layer).
%
%  All fixed sizes (buffers, cut/offset lengths, gaps) are specified in mm and
%  converted to your chosen output unit. Chord & span are entered in that unit.
%% ========================================================================

clc;

%% ---- acquire the PhD-code fabric-length arrays (robust) --------------
% The two scripts share data through the base workspace, so run the PhD code
% FIRST in the SAME session. As a reliable backup across sessions, after the
% PhD run you can save the two arrays and this script will load them:
%   save('phd_skin_output.mat','circular_Fabric_length_Upper','circular_Fabric_length_Lower')
haveU = exist('circular_Fabric_length_Upper','var') && ~isempty(circular_Fabric_length_Upper);
haveL = exist('circular_Fabric_length_Lower','var') && ~isempty(circular_Fabric_length_Lower);
if ~(haveU && haveL) && exist('phd_skin_output.mat','file')
    fprintf('Arrays not in workspace; loading phd_skin_output.mat ...\n');
    S = load('phd_skin_output.mat');
    if isfield(S,'circular_Fabric_length_Upper'), circular_Fabric_length_Upper = S.circular_Fabric_length_Upper; end
    if isfield(S,'circular_Fabric_length_Lower'), circular_Fabric_length_Lower = S.circular_Fabric_length_Lower; end
    haveU = exist('circular_Fabric_length_Upper','var') && ~isempty(circular_Fabric_length_Upper);
    haveL = exist('circular_Fabric_length_Lower','var') && ~isempty(circular_Fabric_length_Lower);
end
if ~(haveU && haveL)
    msg = sprintf([ ...
      '\n*** No fabric-length data found (arrays missing or EMPTY) ***\n', ...
      'In the SAME MATLAB session, run Bumpy_Airfoil_Dim_PhD to completion first.\n', ...
      'It must reach its get_Lengths_of_Fabrics line so the arrays get filled.\n', ...
      'Backup (works across sessions): after the PhD run, type:\n', ...
      '   save(''phd_skin_output.mat'',''circular_Fabric_length_Upper'',''circular_Fabric_length_Lower'')\n', ...
      'then run this script again.\n']);
    error('%s', msg);
end
Lup = circular_Fabric_length_Upper(:).';   % row, per unit chord
Llo = circular_Fabric_length_Lower(:).';
fprintf('Found %d upper segments (sum=%.4f) and %d lower segments (sum=%.4f).\n', ...
        numel(Lup), sum(Lup), numel(Llo), sum(Llo));
if numel(Lup) < 1 || numel(Llo) < 1
    error('Fabric-length arrays are empty (0 segments). Re-run the PhD code to completion.');
end
% --- Normalize to per-unit-chord -----------------------------------------
% A dimensionless (per-unit-chord) developed length is ~1. The PhD code, when
% run to the end, multiplies these arrays by its OWN chord c, so they often
% arrive ALREADY SCALED (sum ~ c). Detect that and divide it back out, so we
% always end up per-unit-chord, then multiply by YOUR chord below.
if sum(Lup) > 1.8 || sum(Llo) > 1.8
    if exist('c','var') && isscalar(c) && isfinite(c) && c > 0
        fprintf('Arrays look scaled (sum %.2f / %.2f); dividing by PhD chord c = %.4g to recover per-unit-chord.\n', ...
                sum(Lup), sum(Llo), c);
        Lup = Lup / c;  Llo = Llo / c;
    else
        fprintf(['[!] Arrays look scaled (sum %.2f / %.2f) but PhD chord c was not found,\n', ...
                 '    so they cannot be auto-normalized. Provide per-unit-chord arrays.\n'], sum(Lup), sum(Llo));
    end
end
fprintf('Per-unit-chord sums now: upper %.4f, lower %.4f (should be ~1).\n', sum(Lup), sum(Llo));

%% ---- user inputs ----
disp('--- LASER-CUT SKIN LAYOUT ---');
uChoice = ask('Output unit: 1 = mm, 2 = cm', 1);
if uChoice == 2, unit = 'cm'; u = 0.1; insunits = 5;   % mm -> cm factor
else,            unit = 'mm'; u = 1.0; insunits = 4; end
chord = ask(sprintf('Chord length (in %s)', unit), 300*u);   % default 30 cm
span  = ask(sprintf('Span length (in %s)',  unit), 1000*u);  % default 100 cm

%% ---- fixed sizes (defined in mm, converted to chosen unit) ----
Buffer_X   = 50  * u;   % horizontal buffer each end of span
Buffer_Y   = 60 * u;   % vertical buffer each end of chord (above/below 2*chord band)
Sealing_Line_1 = 10  * u;   % Sealing Line 1 horizontal length
Sealing_Line_2 = 5  * u;   % Sealing Line 2 (Sealing line 1 offset line length)
Sealing_Line_2_Off_Gap = 0   * u;   % gap from edge to start of Sealing Line 2
Offset_Gap   = 5  * u;   % Sealing Line Width (Distance between sealing line 1 and 2)

%% ---- actual fabric lengths (dimensionless * chord) ----
seg_up = Lup * chord;            % upper segment lengths
seg_lo = Llo * chord;            % lower segment lengths

%% ---- rectangle & geometry ----
W   = span  + 2*Buffer_X;           % total width
H   = 2*chord + 2*Buffer_Y;         % total height
ymid = H/2;                      % leading-edge mid-line

% cut Y positions (FLIPPED vs original): the array that used to sit on top now
% sits on the bottom and vice-versa, mirroring the whole layout about mid-line.
% First cut one segment from the mid-line, then cumulative outward.
y_up = ymid - cumsum(seg_up);    % circular_Fabric_length_Upper -> BOTTOM half
y_lo = ymid + cumsum(seg_lo);    % circular_Fabric_length_Lower -> TOP half

%% ---- overrun warnings (direction-agnostic) ----
skin_top = ymid + chord;  skin_bot = ymid - chord;
y_off_all = [y_up - Offset_Gap, y_lo + Offset_Gap];      % offsets sit outward (mirrored)
if max([y_up y_lo]) > skin_top || min([y_up y_lo]) < skin_bot
    fprintf('[!] Some cuts run past the +/-chord skin band into the buffer.\n');
end
if max(y_off_all) > H || min(y_off_all) < 0
    fprintf('[!] Cuts/offsets overrun the RECTANGLE. Increase the buffer or check the input chord.\n');
end
fprintf('Rectangle: %.2f x %.2f %s | mid-line y = %.2f | upper cuts %d | lower cuts %d\n', ...
        W, H, unit, ymid, numel(y_up), numel(y_lo));
fprintf('Developed skin: upper %.2f %s, lower %.2f %s (vs chord %.2f).\n', ...
        sum(seg_up), unit, sum(seg_lo), unit, chord);

%% ====================== WRITE DXF ======================================
fn_dxf = 'bumpy_wing_skin_DXF_Mahaan_Malhan.dxf';
fid = fopen(fn_dxf, 'wt');

% HEADER (units)
fprintf(fid, '0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n%d\n0\nENDSEC\n', insunits);

% TABLES (linetypes + layers)
fprintf(fid, '0\nSECTION\n2\nTABLES\n');
fprintf(fid, '0\nTABLE\n2\nLTYPE\n70\n2\n');
fprintf(fid, '0\nLTYPE\n2\nCONTINUOUS\n70\n0\n3\nSolid line\n72\n65\n73\n0\n40\n0.0\n');
dash = 5*u; gap = 3*u;
fprintf(fid, '0\nLTYPE\n2\nDASHED\n70\n0\n3\nDashed\n72\n65\n73\n2\n40\n%.4f\n49\n%.4f\n49\n%.4f\n', dash+gap, dash, -gap);
fprintf(fid, '0\nENDTAB\n');
fprintf(fid, '0\nTABLE\n2\nLAYER\n70\n3\n');
fprintf(fid, '0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n');
fprintf(fid, '0\nLAYER\n2\nCUT\n70\n0\n62\n1\n6\nCONTINUOUS\n');           % red
fprintf(fid, '0\nLAYER\n2\nCONSTRUCTION\n70\n0\n62\n3\n6\nDASHED\n');      % green dashed
fprintf(fid, '0\nENDTAB\n0\nENDSEC\n');

% ENTITIES
fprintf(fid, '0\nSECTION\n2\nENTITIES\n');

% rectangle (closed polyline) on CUT
fprintf(fid, '0\nLWPOLYLINE\n8\nCUT\n90\n4\n70\n1\n');
rx = [0 W W 0]; ry = [0 0 H H];
for k = 1:4, fprintf(fid, '10\n%.4f\n20\n%.4f\n', rx(k), ry(k)); end

% leading-edge centerline on CONSTRUCTION
%dxfLine(fid, 'CONSTRUCTION', 0, ymid, W, ymid);

% upper cuts + offsets
for i = 1:numel(y_up)
    dxfLine(fid, 'CUT', 0,        y_up(i), Sealing_Line_1,    y_up(i));   % left flush cut
    dxfLine(fid, 'CUT', W-Sealing_Line_1,y_up(i), W,          y_up(i));   % right flush cut
    yo = y_up(i) - Offset_Gap;                                          % offset outward (below, bottom half)
    dxfLine(fid, 'CUT', Sealing_Line_2_Off_Gap,         yo, Sealing_Line_2_Off_Gap+Sealing_Line_2, yo); % left floating
    dxfLine(fid, 'CUT', W-Sealing_Line_2_Off_Gap-Sealing_Line_2,yo, W-Sealing_Line_2_Off_Gap,      yo); % right floating
end
% lower cuts + offsets
for i = 1:numel(y_lo)
    dxfLine(fid, 'CUT', 0,        y_lo(i), Sealing_Line_1,    y_lo(i));
    dxfLine(fid, 'CUT', W-Sealing_Line_1,y_lo(i), W,          y_lo(i));
    yo = y_lo(i) + Offset_Gap;                                          % offset outward (above, top half)
    dxfLine(fid, 'CUT', Sealing_Line_2_Off_Gap,         yo, Sealing_Line_2_Off_Gap+Sealing_Line_2, yo);
    dxfLine(fid, 'CUT', W-Sealing_Line_2_Off_Gap-Sealing_Line_2,yo, W-Sealing_Line_2_Off_Gap,      yo);
end

fprintf(fid, '0\nENDSEC\n0\nEOF\n');
fclose(fid);
fprintf('DXF written: %s\n', fn_dxf);

%% ====================== PNG PREVIEW ====================================
fn_png = 'bumpy_wing_skin_PNG_Mahaan_Malhan.png';
figure('Color','w'); hold on; axis equal;
fill(rx([1 2 3 4 1]), ry([1 2 3 4 1]), [0.85 0.95 1.0], 'EdgeColor',[0 0 0.6],'LineWidth',1.5);
plot([0 W],[ymid ymid],'--','Color',[0 0.5 0],'LineWidth',1.2);   % centerline (construction)
for i = 1:numel(y_up)
    plot([0 Sealing_Line_1],[y_up(i) y_up(i)],'r-','LineWidth',1.4);
    plot([W-Sealing_Line_1 W],[y_up(i) y_up(i)],'r-','LineWidth',1.4);
    yo = y_up(i)-Offset_Gap;
    plot([Sealing_Line_2_Off_Gap Sealing_Line_2_Off_Gap+Sealing_Line_2],[yo yo],'-','Color',[0 0.6 0],'LineWidth',1.2);
    plot([W-Sealing_Line_2_Off_Gap-Sealing_Line_2 W-Sealing_Line_2_Off_Gap],[yo yo],'-','Color',[0 0.6 0],'LineWidth',1.2);
end
for i = 1:numel(y_lo)
    plot([0 Sealing_Line_1],[y_lo(i) y_lo(i)],'r-','LineWidth',1.4);
    plot([W-Sealing_Line_1 W],[y_lo(i) y_lo(i)],'r-','LineWidth',1.4);
    yo = y_lo(i)+Offset_Gap;
    plot([Sealing_Line_2_Off_Gap Sealing_Line_2_Off_Gap+Sealing_Line_2],[yo yo],'-','Color',[0 0.6 0],'LineWidth',1.2);
    plot([W-Sealing_Line_2_Off_Gap-Sealing_Line_2 W-Sealing_Line_2_Off_Gap],[yo yo],'-','Color',[0 0.6 0],'LineWidth',1.2);
end
title(sprintf('Skin laser layout  |  %.0f x %.0f %s  |  chord %.0f, span %.0f', W,H,unit,chord,span));
xlabel(unit); ylabel(unit);
xlim([-0.05*W 1.05*W]); ylim([-0.05*H 1.05*H]);
saveas(gcf, fn_png); close;
fprintf('PNG written: %s\n', fn_png);

%% ====================== LOCAL FUNCTIONS ================================
function dxfLine(fid, layer, x1,y1,x2,y2)
    fprintf(fid, '0\nLINE\n8\n%s\n10\n%.4f\n20\n%.4f\n30\n0\n11\n%.4f\n21\n%.4f\n31\n0\n', ...
            layer, x1,y1,x2,y2);
end
function val = ask(prompt, def)
    val = input([prompt, ' [', num2str(def), ']: ']);
    if isempty(val), val = def; end
end
