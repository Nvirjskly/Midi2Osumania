module MidiFile
export parseMidiFile


type Midi
  copyright::String
  trackName::String
  numerator::Uint64
  bpm::Float64
  ppq::Float64
  timeDivision::Float64
  tracks::Array{Any}
end


const MICROSECONDS_PER_MINUTE = 60000000

function getStream(fname)
  return open(fname, "r")
end

function parseHeader(s)
  chunkID = hton(read(s, Uint32))
  chunkSize = hton(read(s, Uint32))
  formatType = hton(read(s, Uint16))
  numberOfTracks = hton(read(s, Uint16))
  timeDivision = hton(read(s, Uint16))
  #println("TIMEDIV: $timeDivision")
  assert(chunkID == 0x4d546864)
  return numberOfTracks,timeDivision
end

function parseTrackHeader(s)
  chunkID = hton(read(s, Uint32))
  chunkSize = hton(read(s, Uint32))
  assert(chunkID == 0x4d54726b)
  return chunkSize
end

function getNextByte(s)
  hton(read(s, Uint8))
end

macro nb()
  return :(getNextByte(s); i += 1)
end

function parseMidiFile(fname)
  bpm = 120
  ppq = 3
  tempo = 960
  numerator = 4
  copyright = ""
  trackName = ""
  tracks = Any[]

  s = getStream(fname)

  notes = cell(1,128)

  numTracks, timeDiv = parseHeader(s)
  for t = 1:numTracks

    notes = cell(1,128)
    for as = 1:128
      notes[1,as] = Any[]
    end

    absoluteΔ::Uint64 = 0
    trackSize = parseTrackHeader(s)
    #println("TRACK:")
    i = 1
    while  i <= trackSize
      #delta event reader
      nextByte = getNextByte(s); i += 1
      ΔEvent::Uint64 = nextByte & 0b01111111
      d::Uint64 = 0
      while nextByte & 0b10000000 != 0
        nextByte = getNextByte(s); i += 1
        d += 1
        ΔEvent = ΔEvent << 7
        ΔEvent += nextByte & 0b01111111
      end
      #@printf("Δ:%d,",ΔEvent)
      absoluteΔ += ΔEvent

      #Normal Event
      nextByte = getNextByte(s); i += 1
      eventType = (nextByte & 0b11110000) >> 4
      channel = (nextByte & 0b00001111)
      #@printf("ϵτ:%#02x|c:%#02x\n",eventType,channel)

      #Meta Event
      if (eventType == 0xf && channel == 0xf)
        #type of meta event
        nextByte = getNextByte(s); i += 1
        metaType = nextByte
        #@printf("METAEVENTTYPE:%#04x\n",nextByte)

        #time signature
        if (metaType == 0x58)
          length = getNextByte(s); i += 1
          numerator = getNextByte(s); i += 1
          denominator = getNextByte(s); i += 1
          pulse = getNextByte(s); i += 1
          noteperquarter = getNextByte(s); i += 1
          ppq = pulse/noteperquarter
          #@printf("timeSignature:%d/%d\n",numerator,2^denominator)
          #println("pulse:$pulse,npq:$noteperquarter")
        end

        #sequencer specific
        if (metaType == 0x7f)
          length = getNextByte(s); i += 1
          for k = 1:length
            getNextByte(s); i += 1
          end
        end


        #copyright notice
        if (metaType == 0x02)
          length = getNextByte(s); i += 1
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s) ; i += 1
          end
          copyright = ASCIIString(cbs)
        end

        if (metaType == 0x51)
          length = getNextByte(s); i += 1
          mpqn = 0
          for k = 1:length
            mpqn = mpqn << 8
            mpqn += getNextByte(s); i += 1
          end

          bpm = MICROSECONDS_PER_MINUTE / mpqn
        end

        #Key Signature
        if (metaType == 0x59)
          length = getNextByte(s); i += 1
          key = getNextByte(s); i += 1
          scale = getNextByte(s); i += 1
        end

        #Text Event
        if (metaType == 0x01)
          length = getNextByte(s); i += 1
          for k = 1:length
            getNextByte(s); i += 1
          end
        end

        #End Of Track
        if (metaType == 0x2f)
          length = getNextByte(s); i += 1
          println(length)
        end

        #Sequence/Track Name
        if (metaType == 0x03)
          length = getNextByte(s); i += 1
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s) ; i += 1
          end
          if trackName == ""
            trackName = ASCIIString(cbs)
          end
        end

        #MIDI Channel Prefix
        if (metaType == 0x20)
          length = getNextByte(s); i += 1
          for k = 1:length
            getNextByte(s); i += 1
          end
        end

      #Program Change
      elseif (eventType == 0xc)
        programNumber = getNextByte(s); i += 1
        #println("PROG CHANGE:$programNumber")

      #Note ON
      elseif (eventType == 0x9)
        noteNumber = getNextByte(s); i += 1
        velocity = getNextByte(s); i += 1
        #println("NOTEON:$noteNumber, $velocity")
        push!(notes[1,noteNumber],absoluteΔ)

      #Note OFF
      elseif (eventType == 0x8)
        noteNumber = getNextByte(s); i += 1
        velocity = getNextByte(s); i += 1
        #println("NOTEOFF:$noteNumber, $velocity")
        push!(notes[1,noteNumber],absoluteΔ)
      end
    end
    push!(tracks,notes)
    #println(notes)
  end
  Midi(copyright,trackName,numerator,bpm,ppq,timeDiv,tracks)
end





end
