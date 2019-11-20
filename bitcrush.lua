ardour {
	["type"]    = "dsp",
	name        = "a-Bitcrush",
	category    = "Bitcrush",
	license     = "MIT",
	author      = "Ardour Team",
	description = [[Bitcrush]]
}

function dsp_ioconfig ()
	return
	{
		-- -1, -1 = any number of channels as long as input and output count matches
		{ audio_in = -1, audio_out = -1},
	}
end

function dsp_params ()
	return {}
end

function dsp_configure (ins, outs)
	audio_ins = ins:n_audio();
	local audio_outs = outs:n_audio()
	assert (audio_ins == audio_outs)
end

function dsp_init (rate)
    bit_depth = 4
    max = (2 ^ bit_depth) - 1;
    step = math.floor(rate / 11000); -- The number of samples that need to have the same value based on the session's sample rate
    key_samples = {}
    SampleSums = {}
end

function round (f)
    if f > 0.0 then 
        return math.floor(f + 0.5)
    else 
        return math.ceil(f - 0.5)
    end
end

-- the DSP callback function to process audio audio
-- "ins" and "outs" are http://manual.ardour.org/lua-scripting/class_reference/#C:FloatArray
function dsp_run (ins, outs, n_samples)
	for c = 1, #outs do -- for each output channel (count from 1 to number of output channels)
		if ins[c] ~= outs[c] then -- if processing is not in-place..
			ARDOUR.DSP.copy_vector (outs[c], ins[c], n_samples) -- ..copy data from input to output.
        end

        if not SampleSums[c] then
            SampleSums[c] = 1
        end

		-- direct audio data access, in-place processing of output buffer
		local buf = outs[c]:array() -- get channel's 'c' data as lua array reference

		-- process all audio samples
        for s = 1, n_samples do
            if not key_samples[c] then
                key_samples[c] = round((buf[s] + 1.0) * max) / max - 1.0;
                SampleSums[c] = 2
            elseif SampleSums[c] == step then
                key_samples[c] = round((buf[s] + 1.0) * max) / max - 1.0;
                SampleSums[c] = 1
            else
                SampleSums[c] = SampleSums[c] + 1
            end
            buf[s] = key_samples[c]
		end
	end
end
