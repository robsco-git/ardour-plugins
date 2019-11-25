-- Based on https://github.com/swh/lv2/blob/master/plugins/valve-swh.lv2/plugin.xml

-- <?xml version="1.0"?>
-- <!DOCTYPE ladspa SYSTEM "ladspa-swh.dtd">
-- <?xml-stylesheet href="ladspa.css" type="text/css"?>

-- <ladspa>
--   <global>
--     <meta name="maker" value="Steve Harris &lt;steve@plugin.org.uk&gt;"/>
--     <meta name="copyright" value="GPL"/>
--     <meta name="properties" value="HARD_RT_CAPABLE"/>
--     <code><![CDATA[
--       #include "ladspa-util.h"
--     ]]></code>
--   </global>

--   <plugin label="valve" id="1209" class="DistortionPlugin,SimulatorPlugin">
--     <name>Valve saturation</name>
--     <p>A model of valve (tube) distortion, lacking some of the harmonics you would get in a real tube amp, but sounds good nonetheless.</p>
--     <p>Taken from Ragnar Bendiksen's thesis: \url{http://www.notam02.no/~rbendiks/Diplom/Innhold.html}.</p>

--     <callback event="activate"><![CDATA[
--       itm1 = 0.0f;
--       otm1 = 0.0f;
--     ]]></callback>

function round_to_zero(f)
    -- Not sure what this function is doing in the sw code
    return f
end

local itm1 = 0.0
local otm1 = 0.0

--     <callback event="run"><![CDATA[
-- unsigned long pos;
-- LADSPA_Data fx;

-- const float q = q_p - 0.999f;
-- const float dist = dist_p * 40.0f + 0.1f;

-- q_p is a control between 0 and 1 - distortion level
local q_p = 0.5
local q = q_p - 0.999;

-- dist_p is a control between 0 and 1 - hardness level
local dist_p = 0.5
local dist = dist_p * 40.0 + 0.1;

-- if (q == 0.0f) {
-- 	for (pos = 0; pos < sample_count; pos++) {
-- 		if (input[pos] == q) {
-- 			fx = 1.0f / dist;
-- 		} else {
-- 			fx = input[pos] / (1.0f - f_exp(-dist * input[pos]));
-- 		}
-- 		otm1 = 0.999f * otm1 + fx - itm1;
-- 		round_to_zero(&otm1);
-- 		itm1 = fx;
-- 		buffer_write(output[pos], otm1);
-- 	}
-- } else {
-- 	for (pos = 0; pos < sample_count; pos++) {
-- 		if (input[pos] == q) {
-- 			fx = 1.0f / dist + q / (1.0f - f_exp(dist * q));
-- 		} else {
-- 			fx = (input[pos] - q) /
-- 			 (1.0f - f_exp(-dist * (input[pos] - q))) +
-- 			 q / (1.0f - f_exp(dist * q));
-- 		}
-- 		otm1 = 0.999f * otm1 + fx - itm1;
-- 		round_to_zero(&otm1);
-- 		itm1 = fx;
-- 		buffer_write(output[pos], otm1);
-- 	}
-- }

-- Fast exponentiation function, y = e^x
function f_exp(x)
    return math.exp(f)
end

if q == 0 then
    for pos = 0,sample_count
    do
        if input[pos] == q then
            fx = 1.0 / dist
        else
            fx = input[pos] / (1.0 - f_exp(-dist * input[pos]))
        end
        otm1 = 0.999 * otm1 + fx - itm1
        round_to_zero(otm1)
        itm1 = fx
        output[pos] = otm1
    end
else
    for pos = 0,sample_count
    do
        if input[pos] == q then
		    fx = 1.0 / dist + q / (1.0 - f_exp(dist * q))
		else
			fx = (input[pos] - q) / (1.0 - f_exp(-dist * (input[pos] - q))) + q / (1.0 - f_exp(dist * q))
        end
		otm1 = 0.999 * otm1 + fx - itm1
		round_to_zero(otm1)
		itm1 = fx
        output[pos] = otm1
    end       
end

-- plugin_data->itm1 = itm1;
-- plugin_data->otm1 = otm1;
--     ]]></callback>

--     <port label="q_p" dir="input" type="control" hint="default_0">
--       <name>Distortion level</name>
--       <p>How hard the signal is driven against the limit of the amplifier.</p>
--       <range min="0" max="1"/>
--     </port>

--     <port label="dist_p" dir="input" type="control" hint="default_0">
--       <name>Distortion character</name>
--       <p>The hardness of the sound, low for soft, high for hard.</p>
--       <range min="0" max="1"/>
--     </port>

--     <port label="input" dir="input" type="audio">
--       <name>Input</name>
--     </port>

--     <port label="output" dir="output" type="audio">
--       <name>Output</name>
--     </port>

--     <instance-data label="itm1" type="LADSPA_Data"/>
--     <instance-data label="otm1" type="LADSPA_Data"/>

--   </plugin>
-- </ladspa>