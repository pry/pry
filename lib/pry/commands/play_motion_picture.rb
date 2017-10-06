# frozen_string_literal: true
class Pry::Command::PlayMotionPicture < Pry::ClassCommand
  MOTION_PICTURES = [
    'https://www.youtube.com/watch?v=nOSuObRNBUA',
    'https://www.youtube.com/watch?v=svJvT6ruolA',
    'https://www.youtube.com/watch?v=l-L3zeCNzH8',
    'https://www.youtube.com/watch?v=QrY9eHkXTa4',
    'https://www.youtube.com/watch?v=VhdHwphvhxU',
    'https://www.youtube.com/watch?v=mcTKcMzembk',
    'https://www.youtube.com/watch?v=PGYAAsHT4QE',
    'https://www.youtube.com/watch?v=79Y-EHqZNQA'
  ].freeze

  match 'play-motion-picture'
  group 'Misc'
  description 'Bored? Play a motion picture.'

  def process
    if _pry_.h.windows?
    else
      syscall = _pry_.config.system
      syscall.call _pry_.output, "%s %s" % [_pry_.config.media_player, MOTION_PICTURES.sample].map{|input|
        Shellwords.shellescape(input)
      }
    end
  end
  Pry::Commands.add_command(self)
end
