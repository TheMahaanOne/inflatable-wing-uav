%% ========================================================================
%  INFLATABLE-WING BAFFLES -> LASER-CUT LAYOUT (DXF + PNG)
%  ------------------------------------------------------------------------
%  Works on the output of "Bumpy_Airfoil_Dim_PhD_--__--.m" (that code is NOT
%  modified). It uses the baffle-length array left in the workspace:
%       baffle_Length     (per unit chord, or already *c scaled - auto-handled)
%  and scales it by a chord YOU enter here.
%
%  ==> RUN ORDER: run the PhD code first (same session), then run THIS.
%      Backup hand-off (any session):
%        save('phd_baffle_output.mat','baffle_Length')   % after the PhD run
%
%  Layout (matches the manual drawing):
%    - Each baffle is a FILLED BAND (rectangle) of full width = span and
%      height = baffle_Length(i) + 10 mm  (the strip to be cut).
%    - 20 mm gap between consecutive bands.
%    - First baffle at the TOP (leading edge -> trailing edge downward).
%    - 20 mm border on all sides.
%      => outer width  = span + 2*20
%         outer height = sum(baffle_Length(i)+10) + 20*(N-1) + 2*20
%
%  Fixed sizes (border, +10 band add, 20 gap) are in mm, converted to the
%  chosen output unit. Chord & span are entered in that unit.
%% ========================================================================

clc;

%% ---- acquire the PhD baffle array (robust) ---------------------------
haveB = exist('baffle_Length','var') && ~isempty(baffle_Length);
if ~haveB && exist('phd_baffle_output.mat','file')
    fprintf('baffle_Length not in workspace; loading phd_baffle_output.mat ...\n');
    S = load('phd_baffle_output.mat');
    if isfield(S,'baffle_Length'), baffle_Length = S.baffle_Length; end
    haveB = exist('baffle_Length','var') && ~isempty(baffle_Length);
end
if ~haveB
    msg = sprintf([ ...
      '\n*** No baffle_Length data found (missing or EMPTY) ***\n', ...
      'Run Bumpy_Airfoil_Dim_PhD to completion first (same session), or after it type:\n', ...
      '   save(''phd_baffle_output.mat'',''baffle_Length'')\n', ...
      'then run this script again.\n']);
    error('%s', msg);
end
Lb = baffle_Length(:).';                    % row vector
fprintf('Found %d baffles (sum=%.4f).\n', numel(Lb), sum(Lb));

%% ---- user inputs ----
disp('--- BAFFLE LASER-CUT LAYOUT ---');
uChoice = ask('Output unit: 1 = mm, 2 = cm', 1);
if uChoice == 2, unit = 'cm'; u = 0.1; insunits = 5;
else,            unit = 'mm'; u = 1.0; insunits = 4; end
chord = ask(sprintf('Chord length (in %s)', unit), 300*u);   % default 30 cm
span  = ask(sprintf('Span length (in %s)',  unit), 1000*u);  % default 100 cm

%% ---- normalize baffle array to per-unit-chord ----
% Per-unit-chord baffle lengths are small (<~1). If the PhD *c step ran, the
% array arrives scaled (~c); divide it back out using the PhD chord c.
if sum(Lb) > 1.8 && max(Lb) > 1
    if exist('c','var') && isscalar(c) && isfinite(c) && c > 0
        fprintf('baffle array looks scaled (sum %.2f); dividing by PhD chord c = %.4g.\n', sum(Lb), c);
        Lb = Lb / c;
    else
        fprintf('[!] baffle array looks scaled but PhD chord c not found; cannot auto-normalize.\n');
    end
end
fprintf('Per-unit-chord baffle sum now: %.4f.\n', sum(Lb));

%% ---- fixed sizes (mm -> chosen unit) ----
BORDER  =   0 * u;     % outer border all sides
ADD     = 20 * u;     % added to each baffle length (band height = baffle + 10)
GAP     = 5 * u;     % gap between consecutive bands

%% ---- band heights & rectangle ----
band_h = Lb * chord + ADD;          % each band height [unit]
N      = numel(band_h);
stack_h = sum(band_h) + GAP*(N-1);  % total stacked height (no border)
W = span + 2*BORDER;                % outer width
H = stack_h + 2*BORDER;             % outer height

% band Y extents, first baffle at the TOP, going down
y_top = zeros(1,N);  y_bot = zeros(1,N);
ycur = H - BORDER;                  % top inner edge
for i = 1:N
    y_top(i) = ycur;
    y_bot(i) = ycur - band_h(i);
    ycur = y_bot(i) - GAP;          % drop by band + gap
end

fprintf('Baffles: %d | band heights %.2f..%.2f %s | stack %.2f | rectangle %.2f x %.2f %s\n', ...
        N, min(band_h), max(band_h), unit, stack_h, W, H, unit);

%% ====================== WRITE DXF ======================================
fn_dxf = 'bumpy_wing_baffle_DXF_Mahaan_Malhan.dxf';
[fid,msg] = fopen(fn_dxf, 'wt');
if fid == -1
    error('Could not open %s for writing: %s\n(Close it in any other program / check folder write permission.)', fn_dxf, msg);
end

% HEADER (units)
fprintf(fid, '0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n%d\n0\nENDSEC\n', insunits);
% TABLES (layers)
fprintf(fid, '0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n2\n');
fprintf(fid, '0\nLAYER\n2\n0\n70\n0\n62\n7\n6\nCONTINUOUS\n');
fprintf(fid, '0\nLAYER\n2\nCUT\n70\n0\n62\n1\n6\nCONTINUOUS\n');     % red = cut
fprintf(fid, '0\nLAYER\n2\nBORDER\n70\n0\n62\n5\n6\nCONTINUOUS\n');  % blue = border
fprintf(fid, '0\nENDTAB\n0\nENDSEC\n');
% ENTITIES
fprintf(fid, '0\nSECTION\n2\nENTITIES\n');

% outer border rectangle
dxfRect(fid, 'BORDER', 0, 0, W, H);

% baffle bands (each a closed rectangle), full width inside the border
for i = 1:N
    dxfRect(fid, 'CUT', BORDER, y_bot(i), W-BORDER, y_top(i));
end

fprintf(fid, '0\nENDSEC\n0\nEOF\n');
fclose(fid);
fprintf('DXF written: %s\n', fn_dxf);

%% ====================== PNG PREVIEW ====================================
fn_png = 'bumpy_wing_baffle_PNG_Mahaan_Malhan.png';
figure('Color','w'); hold on; axis equal;
% border
plot([0 W W 0 0],[0 0 H H 0],'-','Color',[0 0 0.6],'LineWidth',1.5);
% bands
for i = 1:N
    xb = [BORDER W-BORDER W-BORDER BORDER BORDER];
    yb = [y_bot(i) y_bot(i) y_top(i) y_top(i) y_bot(i)];
    fill(xb, yb, [0.6 0.65 0.75], 'EdgeColor',[0.7 0 0], 'LineWidth',1.2);
end
title(sprintf('Baffle laser layout  |  %.0f x %.0f %s  |  %d baffles  |  chord %.0f', W,H,unit,N,chord));
xlabel(unit); ylabel(unit);
xlim([-0.03*W 1.03*W]); ylim([-0.03*H 1.03*H]);
saveas(gcf, fn_png); close;
fprintf('PNG written: %s\n', fn_png);

%% ====================== LOCAL FUNCTIONS ================================
function dxfRect(fid, layer, x1,y1,x2,y2)
    % closed LWPOLYLINE rectangle
    fprintf(fid, '0\nLWPOLYLINE\n8\n%s\n90\n4\n70\n1\n', layer);
    xs = [x1 x2 x2 x1]; ys = [y1 y1 y2 y2];
    for k = 1:4, fprintf(fid, '10\n%.4f\n20\n%.4f\n', xs(k), ys(k)); end
end
function val = ask(prompt, def)
    val = input([prompt, ' [', num2str(def), ']: ']);
    if isempty(val), val = def; end
end
