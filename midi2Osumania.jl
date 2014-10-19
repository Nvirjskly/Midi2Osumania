include("midifile.jl")
include("osufile.jl")
using MidiFile
using OsuFile


const MICROSECONDS_PER_MINUTE = 60000000



#module Midi2Osumania



#end

cd(dirname(@__FILE__))

function parseCMDARGS()
  map(println,ARGS)
end

parseCMDARGS()


midiInfo = MidiFile.parseMidiFile("test.mid")

tracks = midiInfo.tracks

println("COPYRIGHT:$(midiInfo.copyright)")
println("TRACKNAME:$(midiInfo.trackName)")
println("BPM:$(midiInfo.bpm)")
println("PPQ:$(midiInfo.ppq)")

println("WHATISTHIS:$(midiInfo.bpm * midiInfo.ppq)")

tempo = MICROSECONDS_PER_MINUTE / midiInfo.bpm
println(tempo)

#function midiToms(s)
#  iround((s * 60 * 1000)/( midiInfo.bpm * midiInfo.timeDivision))
#end

file = open("test.osu", "w")

write(file,OsuFile.createHitobjects(midiInfo, [2]))

close(file)
