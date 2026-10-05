import math
import subprocess
import numpy as np
from PIL import Image

im = Image.open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\logo_true_alpha.png')
arr = np.array(im)

SCALE = 0.38
CX_SRC = 333.5
CY_SRC = 265.0
CX_DST = 250.0
CY_DST = 215.0

def tx(x):
    return round(CX_DST + (x - CX_SRC) * SCALE, 2)

def ty(y):
    return round(CY_DST + (y - CY_SRC) * SCALE, 2)

def get_contours(mask):
    padded = np.pad(mask, 1, mode='constant', constant_values=False)
    h, w = padded.shape
    visited = np.zeros_like(padded, dtype=bool)
    contours = []
    dirs = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]
    for r in range(1, h - 1):
        for c in range(1, w - 1):
            if padded[r, c] and not padded[r, c - 1] and not visited[r, c]:
                contour = []
                curr = (r, c)
                b_dir = 6
                while True:
                    contour.append((curr[1] - 1, curr[0] - 1)) # (x, y)
                    visited[curr[0], curr[1]] = True
                    found = False
                    start_dir = (b_dir + 2) % 8
                    for i in range(8):
                        d_idx = (start_dir + i) % 8
                        nr = curr[0] + dirs[d_idx][0]
                        nc = curr[1] + dirs[d_idx][1]
                        if 0 <= nr < h and 0 <= nc < w and padded[nr, nc]:
                            b_dir = (d_idx + 4) % 8
                            curr = (nr, nc)
                            found = True
                            break
                    if not found or curr == (r, c):
                        break
                if len(contour) > 25:
                    contours.append(contour)
    return contours

def simplify_dp(pts, tol):
    if len(pts) <= 2:
        return pts
    pts = np.array(pts)
    start = pts[0]
    end = pts[-1]
    line_vec = end - start
    line_len = np.hypot(line_vec[0], line_vec[1])
    if line_len == 0:
        dists = np.hypot(pts[:,0] - start[0], pts[:,1] - start[1])
    else:
        dists = np.abs(line_vec[0] * (pts[:,1] - start[1]) - line_vec[1] * (pts[:,0] - start[0])) / line_len
    idx = np.argmax(dists)
    max_d = dists[idx]
    if max_d > tol:
        left = simplify_dp(pts[:idx+1], tol)
        right = simplify_dp(pts[idx:], tol)
        return list(left[:-1]) + list(right)
    else:
        return [list(start), list(end)]

# Extract Navy contours
is_navy = (arr[:,:,3] > 100) & (arr[:,:,0] < 40) & (arr[:,:,1] < 50) & (arr[:,:,2] < 70)
navy_contours = get_contours(is_navy)

navy_shapes_rml = []
for i, c in enumerate(navy_contours):
    pts = simplify_dp(c, 2.5)
    v_lines = []
    for pt in pts:
        v_lines.append(f'                <StraightVertex x="{tx(pt[0])}" y="{ty(pt[1])}" radius="4"/>')
    v_str = '\n'.join(v_lines)
    navy_shapes_rml.append(f'''        <Shape x="0" y="0" name="NavyBody_{i}" id="0:{110+i}">
            <PointsPath isClosed="true" name="Path">
{v_str}
            </PointsPath>
            <Fill name="Fill">
                <SolidColor colorValue="FF0F1B2E" name="NavyColor"/>
            </Fill>
        </Shape>''')

navy_rml_block = '\n'.join(navy_shapes_rml)

# Landmarks
node3_x, node3_y = tx(516.5), ty(468.5)
node2_x, node2_y = tx(544.5), ty(315.0)
node1_x, node1_y = tx(446.5), ty(75.0)
pin_head_x, pin_head_y = tx(627.5), ty(52.0)

# Speed lines
spd1_x, spd1_y = tx(86), ty(283.5)
spd2_x, spd2_y = tx(133), ty(327.5)
spd3_x, spd3_y = tx(197.5), ty(371.5)

# Ultra-smooth cubic S-trace path passing through:
# 1. Start at bottom: (tx(200), ty(516))
# 2. Through Node 3: (node3_x, node3_y)
# 3. Outer right turn: (tx(634), ty(400))
# 4. Through Node 2: (node2_x, node2_y)
# 5. Diagonal spine: (tx(245), ty(190))
# 6. Top left turn: (tx(190), ty(145))
# 7. Through Node 1: (node1_x, node1_y)
# 8. Connect to Pin: (pin_head_x - 4, pin_head_y + 12)

p_start_x, p_start_y = tx(200), ty(516)
p_bloop_x, p_bloop_y = tx(634), ty(400)
p_spine_x, p_spine_y = tx(245), ty(190)
p_tloop_x, p_tloop_y = tx(190), ty(145)
p_end_x, p_end_y = pin_head_x - 3, pin_head_y + 12

circuit_vertices = f'''                <!-- 1. Start at bottom -->
                <CubicDetachedVertex x="{p_start_x}" y="{p_start_y}" outRotation="0.0" outDistance="25" inRotation="3.14" inDistance="0"/>
                <!-- 2. Through Node 3 -->
                <CubicDetachedVertex x="{node3_x}" y="{node3_y}" inRotation="3.35" inDistance="28" outRotation="-0.65" outDistance="25"/>
                <!-- 3. Bottom Right Loop -->
                <CubicDetachedVertex x="{p_bloop_x}" y="{p_bloop_y}" inRotation="1.57" inDistance="18" outRotation="-1.57" outDistance="18"/>
                <!-- 4. Through Node 2 -->
                <CubicDetachedVertex x="{node2_x}" y="{node2_y}" inRotation="-0.5" inDistance="20" outRotation="2.65" outDistance="25"/>
                <!-- 5. Center Diagonal Spine -->
                <CubicDetachedVertex x="{p_spine_x}" y="{p_spine_y}" inRotation="-0.55" inDistance="25" outRotation="2.6" outDistance="25"/>
                <!-- 6. Top Left Loop -->
                <CubicDetachedVertex x="{p_tloop_x}" y="{p_tloop_y}" inRotation="1.57" inDistance="16" outRotation="-0.3" outDistance="22"/>
                <!-- 7. Through Node 1 -->
                <CubicDetachedVertex x="{node1_x}" y="{node1_y}" inRotation="3.14" inDistance="20" outRotation="0.0" outDistance="20"/>
                <!-- 8. Connect to Location Pin -->
                <CubicDetachedVertex x="{p_end_x}" y="{p_end_y}" inRotation="3.14" inDistance="12" outRotation="0.0" outDistance="0"/>'''

rml_content = f'''<Rive version="1" kind="fragment">
    <FontAsset file="SpaceGrotesk.ttf" name="SpaceGrotesk" id="0:100"/>
    <FontAsset file="Inter.ttf" name="Inter" id="0:101"/>

    <Artboard defaultStateMachineId="0:7" styleId="0:5" width="500" height="600" name="Artboard" id="0:2">
        <LayoutComponentStyle name="Artboard Style" id="0:5"/>
        <Fill name="Background">
            <SolidColor colorValue="FFFFFFFF" name="WhiteBg"/>
        </Fill>

        <!-- DRAW ORDER IN RIVE: First sibling declared draws ON TOP -->

        <!-- 1. Location Pin (Top Layer) -->
        <Node x="{pin_head_x}" y="{pin_head_y}" name="LocationPin" id="0:250">
            <!-- White Center Cutout (Draws on TOP of PinBody) -->
            <Shape x="0" y="-2" name="PinCutout" id="0:252">
                <Ellipse originX="0.5" originY="0.5" width="10" height="10"/>
                <Fill name="Fill"><SolidColor colorValue="FFFFFFFF" name="White"/></Fill>
            </Shape>
            <!-- Pin Body Shape -->
            <Shape x="0" y="0" name="PinBody" id="0:251">
                <PointsPath isClosed="true" name="Path">
                    <CubicDetachedVertex x="0" y="-14" inRotation="3.14159" inDistance="7.5" outRotation="0" outDistance="7.5"/>
                    <CubicDetachedVertex x="13.5" y="-2" inRotation="-1.5708" inDistance="6.5" outRotation="1.8" outDistance="6.5"/>
                    <StraightVertex x="0" y="22" radius="1"/>
                    <CubicDetachedVertex x="-13.5" y="-2" inRotation="1.34" inDistance="6.5" outRotation="-1.5708" outDistance="6.5"/>
                </PointsPath>
                <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
            </Shape>
        </Node>

        <!-- 2. Network Nodes (Draw on top of Circuit Line) -->
        <!-- Network Node 1 (Top) -->
        <Shape x="{node1_x}" y="{node1_y}" name="Node1" id="0:240">
            <Ellipse originX="0.5" originY="0.5" width="12" height="12"/>
            <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
        </Shape>

        <!-- Network Node 2 (Middle) -->
        <Shape x="{node2_x}" y="{node2_y}" name="Node2" id="0:230">
            <Ellipse originX="0.5" originY="0.5" width="12" height="12"/>
            <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
        </Shape>

        <!-- Network Node 3 (Bottom) -->
        <Shape x="{node3_x}" y="{node3_y}" name="Node3" id="0:220">
            <Ellipse originX="0.5" originY="0.5" width="12" height="12"/>
            <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
        </Shape>

        <!-- 3. Cerulean S-Circuit Line (Stroke & Trim Animation) -->
        <Shape x="0" y="0" name="SCircuitTrace" id="0:210">
            <PointsPath isClosed="false" name="Path">
{circuit_vertices}
            </PointsPath>
            <Stroke thickness="8" cap="round" join="round">
                <SolidColor colorValue="FF0A66C2" name="CeruleanBlue"/>
                <TrimPath start="0" end="1" name="Trim" id="0:211"/>
            </Stroke>
        </Shape>

        <!-- 4. Speed Trail Lines (Mobility) -->
        <Node name="SpeedTrails" id="0:200">
            <Shape x="{spd1_x}" y="{spd1_y}" name="SpeedLine1" id="0:201">
                <Rectangle originX="0.5" originY="0.5" width="{round(134*SCALE, 1)}" height="{round(24*SCALE, 1)}" cornerRadiusTL="4.5" linkCornerRadius="true"/>
                <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
            </Shape>
            <Shape x="{spd2_x}" y="{spd2_y}" name="SpeedLine2" id="0:202">
                <Rectangle originX="0.5" originY="0.5" width="{round(138*SCALE, 1)}" height="{round(24*SCALE, 1)}" cornerRadiusTL="4.5" linkCornerRadius="true"/>
                <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
            </Shape>
            <Shape x="{spd3_x}" y="{spd3_y}" name="SpeedLine3" id="0:203">
                <Rectangle originX="0.5" originY="0.5" width="{round(171*SCALE, 1)}" height="{round(24*SCALE, 1)}" cornerRadiusTL="4.5" linkCornerRadius="true"/>
                <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Cerulean"/></Fill>
            </Shape>
        </Node>

        <!-- 5. Solid Navy Body (Connectivity Core, Underneath Stroke) -->
{navy_rml_block}

        <!-- 6. Wordmark & Tagline -->
        <Node x="250" y="380" name="WordmarkGroup" id="0:300">
            <Text x="0" y="0" originX="0.5" originY="0.5" alignValue="center" name="BrandTitle" id="0:301">
                <TextStylePaint fontSize="32" fontAssetId="0:100" name="SmartStyle" id="0:302">
                    <Fill name="Fill"><SolidColor colorValue="FF0F1B2E" name="Navy"/></Fill>
                </TextStylePaint>
                <TextStylePaint fontSize="32" fontAssetId="0:100" name="TransitStyle" id="0:303">
                    <Fill name="Fill"><SolidColor colorValue="FF0A66C2" name="Blue"/></Fill>
                </TextStylePaint>
                <TextValueRun styleId="0:302" text="SMART " name="RunSmart"/>
                <TextValueRun styleId="0:303" text="TRANSIT" name="RunTransit"/>
            </Text>

            <Text x="0" y="36" originX="0.5" originY="0.5" alignValue="center" name="Tagline" id="0:310">
                <TextStylePaint fontSize="13.5" fontAssetId="0:101" name="TaglineStyle" id="0:311">
                    <Fill name="Fill"><SolidColor colorValue="FF0F1B2E" name="NavyText"/></Fill>
                </TextStylePaint>
                <TextValueRun styleId="0:311" text="Intelligent Mobility. Connected Botswana." name="RunTagline"/>
            </Text>
        </Node>

        <!-- State Machine & Controller Wiring -->
        <StateMachine name="State Machine 1" id="0:7">
            <StateMachineBool name="appReady" id="0:10"/>
            <StateMachineLayer name="Layer 1" id="0:8">
                <AnyState x="0" y="-150"/>
                <ExitState x="700" y="0" id="0:19"/>
                <EntryState>
                    <StateTransition stateToId="0:11"/>
                </EntryState>
                <!-- 1. Static (0ms, native OS launch screen match) -->
                <AnimationState x="100" y="0" animationId="0:51" id="0:11">
                    <StateTransition stateToId="0:12" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <!-- 2. TraceAndConnect (0-700ms, S-outline draw + node pulses) -->
                <AnimationState x="250" y="0" animationId="0:52" id="0:12">
                    <StateTransition stateToId="0:13" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <!-- 3. Arrival (700-900ms, Pin single arrival pulse) -->
                <AnimationState x="400" y="0" animationId="0:53" id="0:13">
                    <StateTransition stateToId="0:14" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <!-- 4. Wordmark (900-1100ms, Wordmark & tagline opacity fade-in) -->
                <AnimationState x="550" y="0" animationId="0:54" id="0:14">
                    <StateTransition stateToId="0:15" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <!-- 5. Idle (1100ms onward, Pin subtle breathing pulse loop, waits for appReady) -->
                <AnimationState x="700" y="-150" animationId="0:55" id="0:15">
                    <StateTransition stateToId="0:19">
                        <TransitionBoolCondition inputId="0:10" opValue="equal"/>
                    </StateTransition>
                </AnimationState>
            </StateMachineLayer>
        </StateMachine>

        <!-- Timelines -->
        <!-- 1. Static (t=0ms, matches native launch screen perfectly) -->
        <LinearAnimation duration="1" name="Static" id="0:51">
            <KeyedObject objectId="0:211">
                <KeyedProperty propertyKey="115">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <KeyedObject objectId="0:300">
                <KeyedProperty propertyKey="18">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <!-- 2. TraceAndConnect (0-700ms, 42 frames @ 60fps) -->
        <LinearAnimation duration="42" name="TraceAndConnect" id="0:52">
            <!-- S-Trace outline draws 0% to 100% eased -->
            <KeyedObject objectId="0:211">
                <KeyedProperty propertyKey="115">
                    <KeyFrameDouble value="0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1" frame="42" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Node 3 pulse as trace reaches it (~frame 10) -->
            <KeyedObject objectId="0:220">
                <KeyedProperty propertyKey="16"> <!-- scaleX -->
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="8" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="12" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="17" interpolationType="linear"/>
                </KeyedProperty>
                <KeyedProperty propertyKey="17"> <!-- scaleY -->
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="8" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="12" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="17" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Node 2 pulse as trace reaches it (~frame 23) -->
            <KeyedObject objectId="0:230">
                <KeyedProperty propertyKey="16">
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="20" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="24" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="29" interpolationType="linear"/>
                </KeyedProperty>
                <KeyedProperty propertyKey="17">
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="20" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="24" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="29" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Node 1 pulse as trace reaches it (~frame 34) -->
            <KeyedObject objectId="0:240">
                <KeyedProperty propertyKey="16">
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="31" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="35" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="40" interpolationType="linear"/>
                </KeyedProperty>
                <KeyedProperty propertyKey="17">
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="1.0" frame="31" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.35" frame="35" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="40" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Wordmark hidden during trace -->
            <KeyedObject objectId="0:300">
                <KeyedProperty propertyKey="18">
                    <KeyFrameDouble value="0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="0" frame="42" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <!-- 3. Arrival (700-900ms, 12 frames @ 60fps) -->
        <LinearAnimation duration="12" name="Arrival" id="0:53">
            <KeyedObject objectId="0:211">
                <KeyedProperty propertyKey="115">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Pin single arrival pulse (1.0 -> 1.15 -> 1.0) -->
            <KeyedObject objectId="0:250">
                <KeyedProperty propertyKey="16"> <!-- scaleX -->
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.15" frame="6" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="12" interpolationType="linear"/>
                </KeyedProperty>
                <KeyedProperty propertyKey="17"> <!-- scaleY -->
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.15" frame="6" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.2" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="12" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Wordmark remains hidden -->
            <KeyedObject objectId="0:300">
                <KeyedProperty propertyKey="18">
                    <KeyFrameDouble value="0" frame="0" interpolationType="linear"/>
                    <KeyFrameDouble value="0" frame="12" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <!-- 4. Wordmark (900-1100ms, 12 frames @ 60fps) -->
        <LinearAnimation duration="12" name="Wordmark" id="0:54">
            <KeyedObject objectId="0:211">
                <KeyedProperty propertyKey="115">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Wordmark fades in from opacity 0 to 1 -->
            <KeyedObject objectId="0:300">
                <KeyedProperty propertyKey="18">
                    <KeyFrameDouble value="0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.2" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1" frame="12" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>

        <!-- 5. Idle (1100ms onward, loopable, 108 frames = 1.8s per cycle) -->
        <LinearAnimation loopValue="loop" duration="108" name="Idle" id="0:55">
            <KeyedObject objectId="0:211">
                <KeyedProperty propertyKey="115">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <KeyedObject objectId="0:300">
                <KeyedProperty propertyKey="18">
                    <KeyFrameDouble value="1" frame="0" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
            <!-- Pin subtle breathing opacity pulse (1.0 -> 0.65 -> 1.0) -->
            <KeyedObject objectId="0:250">
                <KeyedProperty propertyKey="18"> <!-- opacity -->
                    <KeyFrameDouble value="1.0" frame="0" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.6" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="0.65" frame="54" interpolationType="cubic">
                        <CubicEaseInterpolator x1="0.4" y1="0" x2="0.6" y2="1"/>
                    </KeyFrameDouble>
                    <KeyFrameDouble value="1.0" frame="108" interpolationType="linear"/>
                </KeyedProperty>
            </KeyedObject>
        </LinearAnimation>
    </Artboard>
</Rive>'''

with open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\scene.rml', 'w', encoding='utf-8') as f:
    f.write(rml_content)

print('Wrote updated scene.rml with aligned landmarks')

res = subprocess.run([r'C:\Users\araba\.rive\bin\rive.exe', r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash', '--once'], capture_output=True, text=True)
print('STDERR:', res.stderr)
print('Exit Code:', res.returncode)
