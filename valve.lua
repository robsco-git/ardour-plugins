-- Based on https://github.com/swh/lv2/blob/master/plugins/valve-swh.lv2/plugin.xml

ardour {
    ["type"]    = "dsp",
    name        = "Valve",
    category    = "Saturation",
    license     = "GPLv2",
    author      = "Robert Scott",
    description = [[An extremely expensive valve saturation plugin.]]
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

-- y = e^x
function f_exp(x)
    return math.exp(x)
    -- return 2.71828 ^ x -- approximation
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

    for c = 1,audio_ins do
        local ib = in_map:get(ARDOUR.DataType("audio"), c - 1);
        local ob = out_map:get(ARDOUR.DataType("audio"), c - 1);

        if ib == ARDOUR.ChanMapping.Invalid and ob ~= ARDOUR.ChanMapping.Invalid then
            bufs:get_audio(ob):silence(n_samples, offset)
            goto nextchannel
        end

        local i = bufs:get_audio(ib):data(offset):array()
        local o = bufs:get_audio(ob):data(offset):array()

        if q == 0 then
            for pos = 1,n_samples
            do
                if i[pos] == q then
                    fx = 1.0 / dist
                else
                    fx = i[pos] / (1.0 - f_exp(-dist * i[pos]))
                end
                otm1 = 0.999 * otm1 + fx - itm1
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
                itm1 = fx
                o[pos] = otm1
            end
        end

        ::nextchannel::
    end
end