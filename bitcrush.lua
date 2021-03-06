ardour {
    ["type"]    = "dsp",
    name        = "Bitcrush",
    category    = "Bitcrushing",
    license     = "MIT",
    author      = "Robert Scott",
    description = [[Apply bit reduction and/or downsampling to the audio signal.]]
}

function dsp_ioconfig ()
    return
    {
        -- -1, -1 = any number of channels as long as input and output count matches
        { audio_in = -1, audio_out = -1},
    }
end

local sample_rate

function dsp_init (rate)
    sample_rate = rate
end

function dsp_params ()
    return {
        { ["type"] = "input", name = "Bit depth", min = 1, max = 32, default = 8, unit="bit depth"},
        { ["type"] = "input", name = "Sample rate", min = 1, max = sample_rate, default = 11025, unit="sample rate"},
    }
end

function dsp_configure (ins, outs)
    local audio_ins = ins:n_audio();
    local audio_outs = outs:n_audio()
    assert (audio_ins == audio_outs)
end

local function round (f)
    if f > 0.0 then
        return math.floor(f + 0.5)
    else
        return math.ceil(f - 0.5)
    end
end

local function change_bitdepth(f, max)
    return round((f + 1.0) * max) / max - 1.0
end

local key_samples = {} -- For downsampling: store samples (for each channel) at set intervals to replace existing sample.
local sample_sums = {} -- How many samples have been visited. Reset each time a new key sample is set.

local prev_rate

function dsp_run (ins, outs, n_samples)
    local ctrl = CtrlPorts:array() -- get control port array (read/write)

    local bit_depth = ctrl[1]
    local current_rate = ctrl[2]
    if (current_rate ~= prev_rate) then
        -- Reinitialize
        key_samples = {}
        sample_sums = {}
    end

    prev_rate = current_rate
    local max = (2 ^ bit_depth) - 1;
    local step = math.floor(sample_rate / current_rate); -- The number of samples that need to have the same value based on the session's sample rate

    for c = 1, #outs do -- for each output channel (count from 1 to number of output channels)

        if ins[c] ~= outs[c] then -- if processing is not in-place..
            ARDOUR.DSP.copy_vector (outs[c], ins[c], n_samples) -- ..copy data from input to output.
        end

        if not sample_sums[c] then
            sample_sums[c] = 1
        end

        -- direct audio data access, in-place processing of output buffer
        local buf = outs[c]:array() -- get channel's 'c' data as lua array reference

        -- process all audio samples
        for s = 1, n_samples do
            if step == 1 then
                buf[s] = change_bitdepth(buf[s], max);
            elseif not key_samples[c] then
                key_samples[c] = change_bitdepth(buf[s], max);
                sample_sums[c] = 2
                buf[s] = key_samples[c]
            elseif sample_sums[c] == step then
                key_samples[c] = change_bitdepth(buf[s], max);
                sample_sums[c] = 1
                buf[s] = key_samples[c]
            else
                sample_sums[c] = sample_sums[c] + 1
                buf[s] = key_samples[c]
            end
        end
    end
end