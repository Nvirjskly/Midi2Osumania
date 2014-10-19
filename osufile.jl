module OsuFile

function midiToms(midiInfo,s)
  iround((s * 60 * 1000)/( midiInfo.bpm * midiInfo.timeDivision))
end

function createTimingPoints(midiInfo)
  mspb = 60000.0 / midiInfo.bpm
  return "0,$mspb,$(midiInfo.numerator),2,0,1,0"
end

function createHitobjects(midiInfo,trackNums)
  ret = "[Hitobjects]\n"
  for track = midiInfo.tracks[trackNums]
    for note = 1:128
      notes = track[1,note]
      if size(notes,1) > 0
        for j = 1:2:size(notes,1)
          #println(notes[j+1])
          ret = "$(ret)$(32 + 64 * (note % 8)),192,$(midiToms(midiInfo,notes[j])),128,0,$(midiToms(midiInfo,notes[j+1])):0:0:0:0:\r\n"
          #write(file,"$(32 + 64 * (note % 8)),192,$(midiToms(notes[j])),128,0,$(midiToms(notes[j+1])):0:0:0:0:\r\n")
          #println("$(32 + 64 * (note % 8)),192,$(midiToms(notes[j])),128,0,$(midiToms(notes[j+1])):0:0:0:0:")
          #32,192,4187,128,0,4436:0:0:0:0:
        end
      end
    end
  end
  ret
end

function createMetadata()


end

function createDifficulty()


end


function createEvents()

end

function createDifficulty()

end

function createOsuFile(midiInfo)
  ret = "osu file format v13"


end


end
