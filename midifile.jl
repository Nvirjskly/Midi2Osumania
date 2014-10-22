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

function getNextLength(s,l)
  bs = Uint8[l]
  for i = 1:l
    bs[i] = getNextByte(s)
  end
  bs
end

function getVaribleLengthData(s)
  nextByte::Uint8 = getNextByte(s)
  dat::Uint64 = nextByte & 0b01111111
  while nextByte & 0b10000000 != 0
    nextByte = getNextByte(s)
    dat = dat << 7
    dat += nextByte & 0b01111111
  end
  dat
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
    println("TRACK:")
    previousEvent::Uint8 = 0
    previousChannel::Uint8 = 0
    offset = position(s)
    while position(s) - offset < trackSize
      #delta event reader
      nextByte::Uint8 = 0;
      ΔEvent::Uint64 = getVaribleLengthData(s)
      @printf("Δ:%d,",ΔEvent)
      absoluteΔ += ΔEvent

      #Normal Event
      nextByte = getNextByte(s);
      eventType::Uint8 = (nextByte & 0b11110000) >> 4
      channel::Uint8 = (nextByte & 0b00001111)

      if (eventType < 0x8) #RUNNING STATUS WTF
        eventType = previousEvent
        channel = previousChannel
        skip(s, -1)
      else
        previousEvent = eventType
        previousChannel = channel
      end

      @printf("ϵτ:%#02x|c:%#02x\n",eventType,channel)

      #Meta Event
      if (eventType == 0xf && channel == 0xf)
        #type of meta event
        metaType = getNextByte(s);
        length = getVaribleLengthData(s)
        @printf("METAEVENTTYPE:%#04x, LEN: \n",nextByte)

        #time signature
        if (metaType == 0x58)
          #length = getNextByte(s);
          numerator = getNextByte(s)
          denominator = getNextByte(s)
          pulse = getNextByte(s)
          noteperquarter = getNextByte(s)
          ppq = pulse/noteperquarter
          @printf("timeSignature:%d/%d\n",numerator,2^denominator)
          #println("pulse:$pulse,npq:$noteperquarter")
        end

        #sequencer specific
        if (metaType == 0x7f)
          #length = getNextByte(s); i += 1
          for k = 1:length
            getNextByte(s)
          end
        end


        #copyright notice
        if (metaType == 0x02)
          #length = getNextByte(s); i += 1
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s)
          end
          copyright = ASCIIString(cbs)
          println("copyright???:$(ASCIIString(cbs))")
        end

        if (metaType == 0x51)
          #length = getNextByte(s); i += 1
          mpqn = 0
          for k = 1:length
            mpqn = mpqn << 8
            mpqn += getNextByte(s)
          end

          bpm = MICROSECONDS_PER_MINUTE / mpqn
        end

        #Key Signature
        if (metaType == 0x59)
          #length = getNextByte(s); i += 1
          key = getNextByte(s)
          scale = getNextByte(s)
        end

        #Text Event
        if (metaType == 0x01)
          #length = getNextByte(s); i += 1
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s)
          end
          println("TEXTEVENT???:$(ASCIIString(cbs))")
        end

        #End Of Track
        if (metaType == 0x2f)
          #length = getNextByte(s); i += 1
          println("------------------END-----------------------")
        end

        #Sequence/Track Name
        if (metaType == 0x03)
          #length = getNextByte(s); i += 1
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s)
          end
          println("TRACKNAME???:$(ASCIIString(cbs))")
          if trackName == ""
            trackName = ASCIIString(cbs)
          end
        end

        #MIDI Channel Prefix
        if (metaType == 0x20)
          #length = getNextByte(s)
          cbs = zeros(Uint8,length)
          for k = 1:length
            cbs[k] = getNextByte(s)
          end
          println("MIDICHANNELPREFIX???:$(ASCIIString(cbs))")
        end

      #Program Change
      elseif (eventType == 0xc)
        programNumber = getNextByte(s)
        #println("PROG CHANGE:$programNumber")

      #Note ON
      elseif (eventType == 0x9)
        noteNumber = getNextByte(s)
        velocity = getNextByte(s)
        #println("NOTEON:$noteNumber, $velocity")
        push!(notes[1,noteNumber],absoluteΔ)

      #Note OFF
      elseif (eventType == 0x8)
        noteNumber = getNextByte(s)
        velocity = getNextByte(s)
        #println("NOTEOFF:$noteNumber, $velocity")
        push!(notes[1,noteNumber],absoluteΔ)

      elseif (eventType < 0x8)
        #THIS IS RUNNING STATUS, AS IN BRAINFUCKERY
        #WHY IS THIS IN ABSOLUTELY ZERO SITES ABOUT MIDI????

      else
        println("UNKNOWN EVENT FUCKING ABORT")
      end
    end
    push!(tracks,notes)
    #println(notes)
  end
  Midi(copyright,trackName,numerator,bpm,ppq,timeDiv,tracks)
end





end
