<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis version="3.34.0" styleCategories="Symbology">
  <renderer-v2 type="RuleRenderer" symbollevels="0">
    <rules key="{route-default-rules}">
      <rule key="{route-high}" label="Included / high confidence" filter="&quot;include_default_map&quot; = 1 AND lower(&quot;route_confidence&quot;) = 'high'" symbol="0"/>
      <rule key="{route-estimated}" label="Included / estimated" filter="&quot;include_default_map&quot; = 1 AND lower(&quot;route_confidence&quot;) != 'high'" symbol="1"/>
    </rules>
    <symbols>
      <symbol name="0" type="line" alpha="1"><layer class="SimpleLine"><Option type="Map"><Option name="line_color" value="23,59,87,255" type="QString"/><Option name="line_width" value="0.9" type="QString"/><Option name="line_style" value="solid" type="QString"/></Option></layer></symbol>
      <symbol name="1" type="line" alpha="1"><layer class="SimpleLine"><Option type="Map"><Option name="line_color" value="178,106,46,255" type="QString"/><Option name="line_width" value="0.85" type="QString"/><Option name="line_style" value="dash" type="QString"/></Option></layer></symbol>
    </symbols>
  </renderer-v2>
</qgis>
