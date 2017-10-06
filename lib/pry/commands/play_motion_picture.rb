# frozen_string_literal: true
class Pry::Command::PlayMotionPicture < Pry::ClassCommand
  MOTION_PICTURES = [
    'https://www.youtube.com/watch?v=lk5iMgG-WJI', # Kasbian - ClubFoot.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=svJvT6ruolA', # The Prodigy - No Good (Start The Dance).
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=l-L3zeCNzH8', # Michael Collins eliminates "Cairo Gang".
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=QrY9eHkXTa4', # Bob Marley - Redemption Song
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=VhdHwphvhxU', # Vinnie Paz - Same Story.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=mcTKcMzembk', # Bob Marley - No Women No Cry.
                                                   # (Pry does not own the rights to this video).

    'https://www.youtube.com/watch?v=PGYAAsHT4QE', # Bob Marley - Three Little Birds
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=79Y-EHqZNQA', # Babyshambles - Delivery
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=zU9fu-lC3fY', # Vlog 43 - Love and Peace are our Motivation.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=BaACrT6Ydik', # Wiz Khalifa & others - Shell Shocked.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=U8U_gR58eJU', # DMX - Lord Give Me a Sign.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=mBCVEcjScTQ', # Elton John - Your Song.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=ymNFyxvIdaM', # Bomfunk MC's - Freestyler.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=jyrawwOwdH4', # Dream Letter - Tim Buckley
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=bDjREVKAvq4', # 1916 Easter Rising
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=n_yRvxy9HVs', # Pink Floyd - Mother (Pry does not
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=MT9yNzCCDhU', # Blood Diamond clip
                                                   # (Pry does not own the rights to this video.)


    'https://www.youtube.com/watch?v=T38v3-SSGcM', # Johnny B Goode (1959)
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=79vCiXg3njY', # Blues Brothers - Sweet Home Chicago
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=Q8Tiz6INF7I', # Hit the road Jack!
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=HAfFfqiYLp0', # All Of The Lights. Kanye West.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=Ag3Rv9FzQb0', # Zayeed Song.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=8ZcmTl_1ER8', # Epic Sax Guy 10 hours.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=A_MjCqQoLLA', # Hey Jude - Beatles.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=QA1VGVp6FHg', # One Root - Bun Up The Sess.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=tEnCgwyvtZ4', # One Root - That's Not The Way.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=nElYKl2w4Jw', # One Root - Blazing.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=Izl1nbAnWjE', # You can have your 7 minutes (Michael Collins)
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=nYgXDr3ybA8', # 2Pac - Ghetto Gospel.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=naWslVT3mPg', # The Last Samurai
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=t3217H8JppI', # Symphony No. 9 ~ Beethoven.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=IXdNnw99-Ic', # Pink Floyd - Wish You Were Here.
                                                   # (Pry does not own the rights to this video.)

    'https://www.youtube.com/watch?v=bTHDa6Akqvo', # MIDNIGHT EXPRESS - The Chase.
                                                   # (Pry does not own the rights to this video.)
  ].freeze

  match 'play-motion-picture'
  group 'Misc'
  description 'Bored? Play a motion picture.'
  command_options argument_required: false

  def process
    syscall = _pry_.config.system
    syscall.call _pry_.output, "%s %s" % [
      _pry_.config.media_player,
      MOTION_PICTURES.sample
    ].map {|input|
      Shellwords.shellescape(input)
    }
  end
  Pry::Commands.add_command(self)
end
