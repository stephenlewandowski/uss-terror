<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis version="3.34.0" styleCategories="Symbology">
  <renderer-v2 type="RuleRenderer" symbollevels="0">
    <rules key="{event-category-rules}">
      <rule key="{combat}" label="Combat, air attack, and damage" filter="regexp_match(lower(&quot;event_category&quot;), 'combat|attack|kamikaze|damage|iwo jima|okinawa')" symbol="0"/>
      <rule key="{mine}" label="Mine warfare" filter="regexp_match(lower(&quot;event_category&quot;), 'mine')" symbol="1"/>
      <rule key="{repair}" label="Repair and shipyard" filter="regexp_match(lower(&quot;event_category&quot;), 'repair|dry dock|overhaul|alteration')" symbol="2"/>
      <rule key="{weather}" label="Typhoon and weather" filter="regexp_match(lower(&quot;event_category&quot;), 'typhoon|weather')" symbol="3"/>
      <rule key="{logistics}" label="Logistics, port, and transport" filter="regexp_match(lower(&quot;event_category&quot;), 'logistic|port|transport|passenger|medical|casualty')" symbol="4"/>
      <rule key="{postwar}" label="Postwar and occupation" filter="regexp_match(lower(&quot;event_category&quot;), 'postwar|occupation')" symbol="5"/>
      <rule key="{other}" label="Transit and other" else="1" symbol="6"/>
    </rules>
    <symbols>
      <symbol name="0" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="star" type="QString"/><Option name="color" value="215,48,31,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="4.2" type="QString"/></Option></layer></symbol>
      <symbol name="1" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="diamond" type="QString"/><Option name="color" value="106,81,163,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="3.4" type="QString"/></Option></layer></symbol>
      <symbol name="2" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="cross2" type="QString"/><Option name="color" value="44,127,184,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="3.8" type="QString"/></Option></layer></symbol>
      <symbol name="3" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="triangle" type="QString"/><Option name="color" value="217,95,14,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="3.7" type="QString"/></Option></layer></symbol>
      <symbol name="4" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="square" type="QString"/><Option name="color" value="35,139,69,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="3.2" type="QString"/></Option></layer></symbol>
      <symbol name="5" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="pentagon" type="QString"/><Option name="color" value="184,134,11,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="3.4" type="QString"/></Option></layer></symbol>
      <symbol name="6" type="marker"><layer class="SimpleMarker"><Option type="Map"><Option name="name" value="circle" type="QString"/><Option name="color" value="99,99,99,255" type="QString"/><Option name="outline_color" value="30,30,30,255" type="QString"/><Option name="size" value="2.9" type="QString"/></Option></layer></symbol>
    </symbols>
  </renderer-v2>
</qgis>
