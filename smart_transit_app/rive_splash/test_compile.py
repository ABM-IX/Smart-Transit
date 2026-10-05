import subprocess

rml_test = '''<Rive version="1" kind="fragment">
    <Artboard defaultStateMachineId="0:7" styleId="0:5" width="500" height="500" name="Artboard" id="0:2">
        <LayoutComponentStyle name="Artboard Style" id="0:5"/>
        <Fill name="Background"><SolidColor colorValue="FFFFFFFF" name="Color"/></Fill>
        
        <StateMachine name="State Machine 1" id="0:7">
            <StateMachineBool name="appReady" id="0:10"/>
            <StateMachineLayer name="Layer 1" id="0:8">
                <AnyState x="200" y="-200"/>
                <ExitState x="600" y="200" id="0:19"/>
                <EntryState>
                    <StateTransition stateToId="0:11"/>
                </EntryState>
                <AnimationState animationId="0:51" id="0:11">
                    <StateTransition stateToId="0:12" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <AnimationState animationId="0:52" id="0:12">
                    <StateTransition stateToId="0:13" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <AnimationState animationId="0:53" id="0:13">
                    <StateTransition stateToId="0:14" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <AnimationState animationId="0:54" id="0:14">
                    <StateTransition stateToId="0:15" enableExitTime="true" exitTimeIsPercetange="true" exitTime="100"/>
                </AnimationState>
                <AnimationState animationId="0:55" id="0:15">
                    <StateTransition stateToId="0:19">
                        <TransitionBoolCondition inputId="0:10" opValue="equal"/>
                    </StateTransition>
                </AnimationState>
            </StateMachineLayer>
        </StateMachine>

        <LinearAnimation duration="1" name="Static" id="0:51"/>
        <LinearAnimation duration="42" name="TraceAndConnect" id="0:52"/>
        <LinearAnimation duration="12" name="Arrival" id="0:53"/>
        <LinearAnimation duration="12" name="Wordmark" id="0:54"/>
        <LinearAnimation loopValue="loop" duration="108" name="Idle" id="0:55"/>
    </Artboard>
</Rive>'''

with open(r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash\scene.rml', 'w', encoding='utf-8') as f:
    f.write(rml_test)

res = subprocess.run([r'C:\Users\araba\.rive\bin\rive.exe', r'c:\Users\araba\Desktop\SmartTransit\smart_transit_app\rive_splash', '--once'], capture_output=True, text=True)
print('STDERR:', res.stderr)
print('Code:', res.returncode)
