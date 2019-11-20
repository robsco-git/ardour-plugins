ardour {
	["type"]    = "dsp",
	name        = "a-Distort",
	category    = "Distort",
	license     = "GPLv2",
	author      = "Robert Scott",
	description = [[A distortion plugin with a number of algorithms to choose from.]]
}

function dsp_ioconfig ()
	return
	{
		-- -1, -1 = any number of channels as long as input and output count matches
		{ audio_in = -1, audio_out = -1},
	}
end

function dsp_params ()
	return
	{
		{ ["type"] = "input", name = "Type", min = 0, max = 1, default = 1, enum = true, scalepoints =
			{
				["LoFi"] = 0,
				["DAFX"] = 1,
				["Hard clip"] = 2,
				["Soft clip"] = 3,
			}
		},
		{ ["type"] = "input", name = "Input Gain", min = -20, max = 60, default = 0, unit="dB"},
		{ ["type"] = "input", name = "Output Gain", min = -40, max = 20, default = 0, unit="dB"},
	}
end

function dsp_configure (ins, outs)
	audio_ins = ins:n_audio();
	local audio_outs = outs:n_audio()
	assert (audio_ins == audio_outs)
end

function lofi_distort (f)
	-- Based on LoFi as a part of the CMT collection
	-- https://www.ladspa.org/cmt/overview.html
	-- https://searchcode.com/file/18573523/cmt/src/lofi.cpp
	if f > 0 then
		return (f * 1) / (f + 1) * 2
	else
		return -1* (-1 * f * 1) / (-1 * f + 1) * 2
	end
end

function dafx_distort (f)
	-- Based on formula in DAFX book by Udo Zölzer
	-- https://dsp.stackexchange.com/a/28962
	if (f > 0) then
   		return 1 - math.exp(-f);
	else
		return -1 + math.exp(f);
	end
end

function hard_clip (f)
	-- https://www.dsprelated.com/freebooks/pasp/Nonlinear_Distortion.html
	if f > 1 then
		return 1
	elseif f < -1 then
		return -1
	else
		return f
	end
end

function soft_clip (f)
	-- https://www.dsprelated.com/freebooks/pasp/Nonlinear_Distortion.html
	if f >= 1 then
		return 2 / 3
	elseif f <= -1 then
		return -2 / 3
	else
		
		return f - (f ^ 3) / 3
	end
end

function dsp_runmap (bufs, in_map, out_map, n_samples, offset)
	local ctrl = CtrlPorts:array() -- get control port array (read/write)
	for c = 1,audio_ins do
		-- ensure that processing does happen in-place
		local ib = in_map:get(ARDOUR.DataType("audio"), c - 1); -- get id of mapped input buffer for given cannel
		local ob = out_map:get(ARDOUR.DataType("audio"), c - 1); -- get id of mapped output buffer for given cannel
		assert (ib ~= ARDOUR.ChanMapping.Invalid);
		assert (ob ~= ARDOUR.ChanMapping.Invalid);

		local bi = bufs:get_audio(ib)
		local bo = bufs:get_audio(ob)
		assert (bi == bo)

		local dist_type = ctrl[1]
		local input_gain = ARDOUR.DSP.dB_to_coefficient (ctrl[2])
		local output_gain = ARDOUR.DSP.dB_to_coefficient (ctrl[3])

		local a = bufs:get_audio(ib):data(offset):array() -- get a reference (pointer to array)

		local dist_func
		if dist_type == 0 then
			dist_func = lofi_distort
		elseif dist_type == 1 then
			dist_func = dafx_distort
		elseif dist_type == 2 then
			dist_func = hard_clip
		else
			dist_func = soft_clip
		end

		for s = 1,n_samples do
			a[s] = dist_func(a[s] * input_gain) * output_gain
		end
	end
end
