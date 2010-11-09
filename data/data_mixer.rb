# static file with predefined mixer values for some drivers

{
    "snd-emu10k1" =>
    {
	"mixer" =>		# channels to be initialized (unmuted and volume adjusted)
	{
	    "PCM" =>	80,
	    "CD" =>	80,
	    "Synth" =>	80,
	    "Master" =>	80,
	    "Wave" =>	100,
	    "Music" =>	100
	}
    },
    "snd-trident" =>
    {
        "mixer" =>                # channels to be initialized (unmuted and volume adjusted)
        {
            "PCM" =>     80,
            "CD" =>       80,
            "Synth" =>    80,
            "Master" =>   80,
            "Wave" =>     100,
            "Music" =>    100
        }
    },
    "snd-ymfpci" =>
    {
	"mixer" =>                # channels to be initialized (unmuted and volume adjusted)
        {
            "PCM" =>     80,
            "CD" =>       80,
            "Synth" =>    80,
            "Master" =>   80,
            "Wave" =>     100,
            "Music" =>    100
        }
    },
    "snd-hda-intel" =>
    {
	"mixer" =>
	{
	    "Front" =>	100,
	    "Surround" =>	100,
	    "Center" =>	100,
	    "LFE" =>	100,
	    "PCM" =>	100,
	}
    },
}
