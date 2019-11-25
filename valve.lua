-- Based on https://github.com/swh/lv2/blob/master/plugins/valve-swh.lv2/plugin.xml

ardour {
    ["type"]    = "dsp",
    name        = "Valve",
    category    = "Saturation",
    license     = "GPLv2",
    author      = "Robert Scott",
    description = [[A valve saturation plugin.]]
}

function dsp_ioconfig()
    return
    {
        -- -1, -1 = any number of channels as long as input and output count matches
        { audio_in = -1, audio_out = -1},
    }
end

function dsp_params()
    return
    {
        { ["type"] = "input", name = "Distortion", min = 0, max = 1, default = 0.5, unit="dB"},
        { ["type"] = "input", name = "Hardness", min = 0, max = 1, default = 0.5, unit="dB"},
    }
end

function dsp_configure(ins, outs)
    audio_ins = ins:n_audio();
    local audio_outs = outs:n_audio()
    assert (audio_ins == audio_outs)
end

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

-- y = e^x
function f_exp(x)
    return math.exp(x)
end

local itm1 = 0.0
local otm1 = 0.0

function dsp_runmap(bufs, in_map, out_map, n_samples, offset)
    local ctrl = CtrlPorts:array() -- get control port array (read/write)
    -- q_p is a control between 0 and 1 - distortion level
    local q_p = ctrl[1]
    local q = q_p - 0.999

    -- dist_p is a control between 0 and 1 - hardness level
    local dist_p = ctrl[2]
    local dist = dist_p * 40.0 + 0.1

    -- local input_gain = ARDOUR.DSP.dB_to_coefficient(ctrl[2])
    -- local output_gain = ARDOUR.DSP.dB_to_coefficient(ctrl[3])

    for c = 1,audio_ins do
        local ib = in_map:get(ARDOUR.DataType("audio"), c - 1);
        local ob = out_map:get(ARDOUR.DataType("audio"), c - 1);

        if ib == ARDOUR.ChanMapping.Invalid and ob ~= ARDOUR.ChanMapping.Invalid then
            bufs:get_audio(ob):silence(n_samples, offset)
            goto nextchannel
        end

        local i = bufs:get_audio(ib):data(offset):array()
        local o = bufs:get_audio(ob):data(offset):array()

        -- for s = 1,n_samples do
            -- o[s] = dist_func(i[s] * input_gain) * output_gain

        if q == 0 then
            for pos = 1,n_samples
            do
                if i[pos] == q then
                    fx = 1.0 / dist
                else
                    fx = i[pos] / (1.0 - f_exp(-dist * i[pos]))
                end
                otm1 = 0.999 * otm1 + fx - itm1
                round_to_zero(otm1)
                itm1 = fx
                o[pos] = otm1
            end
        else
            for pos = 1,n_samples
            do
                if i[pos] == q then
                    fx = 1.0 / dist + q / (1.0 - f_exp(dist * q))
                else
                    fx = (i[pos] - q) / (1.0 - f_exp(-dist * (i[pos] - q))) + q / (1.0 - f_exp(dist * q))
                end
                otm1 = 0.999 * otm1 + fx - itm1
                round_to_zero(otm1)
                itm1 = fx
                o[pos] = otm1
            end       
        end
        -- end

        ::nextchannel::
    end
end

--     <callback event="run"><![CDATA[
-- unsigned long pos;
-- LADSPA_Data fx;

-- const float q = q_p - 0.999f;
-- const float dist = dist_p * 40.0f + 0.1f;

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