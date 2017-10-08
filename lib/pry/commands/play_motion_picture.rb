# coding: utf-8
# frozen_string_literal: true
class Pry::Command::PlayMotionPicture < Pry::ClassCommand
  #
  # Note that Pry doesn't own the rights to any of these motion pictures.
  # Links to official sources are given preference. The artists who created these
  # videos should receive royalities in cases where the links use official sources.
  #
  MOTION_PICTURES = [
    ['https://www.youtube.com/watch?v=lk5iMgG-WJI', 'Kasbian - ClubFoot'],
    ['https://www.youtube.com/watch?v=svJvT6ruolA', 'The Prodigy - No Good (Start The Dance)'],
    ['https://www.youtube.com/watch?v=l-L3zeCNzH8', 'Michael Collins eliminates "Cairo Gang"'],
    ['https://www.youtube.com/watch?v=QrY9eHkXTa4', 'Bob Marley - Redemption Song'],
    ['https://www.youtube.com/watch?v=VhdHwphvhxU', 'Vinnie Paz - Same Story.'],
    ['https://www.youtube.com/watch?v=mcTKcMzembk', 'Bob Marley - No Women No Cry'],
    ['https://www.youtube.com/watch?v=PGYAAsHT4QE', 'Bob Marley - Three Little Birds'],
    ['https://www.youtube.com/watch?v=79Y-EHqZNQA', 'Babyshambles - Delivery'],
    ['https://www.youtube.com/watch?v=zU9fu-lC3fY', 'Vlog 43 - Love and Peace are our Motivation'],
    ['https://www.youtube.com/watch?v=BaACrT6Ydik', 'Wiz Khalifa & others - Shell Shocked'],
    ['https://www.youtube.com/watch?v=U8U_gR58eJU', 'DMX - Lord Give Me a Sign'],
    ['https://www.youtube.com/watch?v=mBCVEcjScTQ', 'Elton John - Your Song.'],
    ['https://www.youtube.com/watch?v=ymNFyxvIdaM', 'Bomfunk MCs - Freestyler.'],
    ['https://www.youtube.com/watch?v=jyrawwOwdH4', 'Dream Letter - Tim Buckley'],
    ['https://www.youtube.com/watch?v=bDjREVKAvq4', '1916 Easter Rising'],
    ['https://www.youtube.com/watch?v=n_yRvxy9HVs', 'Pink Floyd - Mother'],
    ['https://www.youtube.com/watch?v=MT9yNzCCDhU', 'Blood Diamond clip'],
    ['https://www.youtube.com/watch?v=T38v3-SSGcM', 'Johnny B Goode (1959)'],
    ['https://www.youtube.com/watch?v=79vCiXg3njY', 'Blues Brothers - Sweet Home Chicago'],
    ['https://www.youtube.com/watch?v=Q8Tiz6INF7I', 'Hit the road Jack!'],
    ['https://www.youtube.com/watch?v=HAfFfqiYLp0', 'All Of The Lights. Kanye West.'],
    ['https://www.youtube.com/watch?v=Ag3Rv9FzQb0', 'Zayeed Song&Dance'],
    ['https://www.youtube.com/watch?v=8ZcmTl_1ER8', 'Epic Sax Guy 10 hours.'],
    ['https://www.youtube.com/watch?v=A_MjCqQoLLA', 'Hey Jude - Beatles.'],
    ['https://www.youtube.com/watch?v=QA1VGVp6FHg', 'One Root - Bun Up The Sess.'],
    ['https://www.youtube.com/watch?v=tEnCgwyvtZ4', 'One Root - That\'s Not The Way.'],
    ['https://www.youtube.com/watch?v=nElYKl2w4Jw', 'One Root - Blazing.'],
    ['https://www.youtube.com/watch?v=Izl1nbAnWjE', 'You can have your 7 minutes -Michael Collins'],
    ['https://www.youtube.com/watch?v=nYgXDr3ybA8', '2Pac - Ghetto Gospel.'],
    ['https://www.youtube.com/watch?v=naWslVT3mPg', 'The Last Samurai'],
    ['https://www.youtube.com/watch?v=t3217H8JppI', 'Symphony No. 9 ~ Beethoven.'],
    ['https://www.youtube.com/watch?v=IXdNnw99-Ic', 'Pink Floyd - Wish You Were Here.'],
    ['https://www.youtube.com/watch?v=bTHDa6Akqvo', 'MIDNIGHT EXPRESS - The Chase.'],
    ['https://www.youtube.com/watch?v=s96v_DkOug0', 'Death of Michael Collins.'],
    ['https://www.youtube.com/watch?v=72kPfWeiqz4', 'The Rolling Stones - Heart of Stone.'],
    ['https://www.youtube.com/watch?v=tJTvr833R-Q', 'Michael Collins Funeral'],
    ['https://www.youtube.com/watch?v=Mb1ZvUDvLDY', '2Pac - Dear Mama.'],
    ['https://www.youtube.com/watch?v=yaS3vaNUYgs', 'Foggy Dew.'],
    ['https://www.youtube.com/watch?v=lbQCf8F1JsE', 'Wamdue Project - King Of My Castle'],
    ['https://www.youtube.com/watch?v=foE1mO2yM04', 'Mike Posner - I Took A Pill In Ibiza'],
    ['https://www.youtube.com/watch?v=Z_ut1L7NH30', 'In the name of the Father - Giuseppe is dead,
                                                    man.'],
    ['https://www.youtube.com/watch?v=NoOhnrjdYOc', 'English Rose - Elton John.'],
    ['https://www.youtube.com/watch?v=Xu3FTEmN-eg', 'The Chemical Brothers - Galvanize'],
    ['https://www.youtube.com/watch?v=gCYcHz2k5x0', 'Martin Garrix - Animals'],
    ['https://www.youtube.com/watch?v=kn15BUFBvu8', 'Fa-fa-fa-fire! - Fawlty Towers'],
    ['https://www.youtube.com/watch?v=qEYueRVuqmg', 'Tiesto - Just Be'],
    ['https://www.youtube.com/watch?v=WlBiLNN1NhQ', "Always Look on the Bright Side of Life -
                                                     Monty Python's Life of Brian"],
    ['https://www.youtube.com/watch?v=7gMJBQoHJ4E', 'Billy Connolly - Terrorist Attack
                                                    At Glasgow Airport'],
    ['https://www.youtube.com/watch?v=JqZo07Ot-uA', 'Billy Connolly - Algebra'],
    ['https://www.youtube.com/watch?v=zs8QKXtCN9w', 'The Mad Irishman - Braveheart'],
    ['https://www.youtube.com/watch?v=UzWHE32IxUc', 'Lenny Kravitz - American Woman'],
    ['https://www.youtube.com/watch?v=hIvRkjOd1f8', 'Braveheart: Freedom Speech'],
    ['https://www.youtube.com/watch?v=IcrbM1l_BoI', 'Avicii - Wake Me Up'],
    ['https://www.youtube.com/watch?v=9jE9bXvX5cM', '11- The Beatles - Cold turkey'],
    ['https://www.youtube.com/watch?v=vefJAtG-ZKI', 'The Beatles Yellow Submarine'],
    ['https://www.youtube.com/watch?v=e-7nbcWOaws', 'Potatoes Of The Night - Billy Connolly'],
    ['https://www.youtube.com/watch?v=cbB3iGRHtqA', 'Scooter - How Much Is The Fish?'],
    ['https://www.youtube.com/watch?v=X-idP23bHCg', 'A gift of Love'],
    ['https://www.youtube.com/watch?v=viaTT859Yk0', 'Sifl & Olly - United States of Whatever'],
    ['https://www.youtube.com/watch?v=YVkUvmDQ3HY', 'Eminem - Without Me'],
    ['https://www.youtube.com/watch?v=TLV4_xaYynY', 'The Jimi Hendrix Experience ' \
                                                    '- All Along The Watchtower'],
    ['https://www.youtube.com/watch?v=YTBC7ckTWpo', 'Luke Kelly - Scorn Not His Simplicity'],
    [
      'http://sayyidali.com/leading-iran/o-leader-please-dont-talk-about-leaving.html',
      'O Leader, please don\'t talk about leaving'
    ],
    ['https://www.youtube.com/watch?v=eFTLKWw542g', 'Billy Joel - We Didn\'t Start the Fire'],
    ['https://www.youtube.com/watch?v=QE3yMEfpk6E', 'The Last Samurai - They are not ready'],
    ['https://www.youtube.com/watch?v=cIJOSSVqqVc', 'Johnny Cash - Hurt (Official Video) HD'],
    ['https://www.youtube.com/watch?v=66pE67m_Hf4', 'Thin Lizzy Cowboy Song'],
    ['https://www.youtube.com/watch?v=8Tf6mrA0-tA', 'Roy Keane - The Real Captain Fantastic'],
    ['https://www.youtube.com/watch?v=Nt4fp43U2ys', 'Armin van Buuren feat. ' \
                                                    'Josh Cumbee - Sunny Days ' \
                                                    '(Official Music Video)'],
    ['https://www.youtube.com/watch?v=60N3R455lHc', 'Michael Collins'],
    ['https://www.youtube.com/watch?v=iMewtlmkV6c', 'Working Class Hero ' \
                                                    '- John Lennon/Plastic Ono Band'],
    ['https://www.youtube.com/watch?v=tBWFofJSm-c', 'Bob Marley - Iron Lion Zion'],
    ['https://www.youtube.com/watch?v=3T1c7GkzRQQ', 'The Police - Roxanne'],
    ['https://www.youtube.com/watch?v=DtVBCG6ThDk', 'Elton John - Rocket Man ' \
                                                    '(Official Music Video)'],
    ['https://www.youtube.com/watch?v=h68CfIUkPKs', 'Billy Connolly - on swearing'],
    ['https://www.youtube.com/watch?v=tAGnKpE4NCI', 'Metallica - Nothing Else Matters' \
                                                    '[Official Music Video]'],
    ['https://www.youtube.com/watch?v=31sZ9xZr_Ew', 'Franz Ferdinand - Ulysses (2009)'],
    ['https://www.youtube.com/watch?v=yuFI5KSPAt4', 'Red Hot Chili Peppers ' \
                                                    '- Snow (Hey Oh) (Official Music Video)'],
    ['https://www.youtube.com/watch?v=Bi2x7nlP_PM', 'Michael Collins- riddled with bullets'],
    ['https://www.youtube.com/watch?v=iGk5fR-t5AU', 'Katy Perry - ' \
                                                    'Swish Swish (Official) ft. Nicki Minaj'],
    ['https://www.youtube.com/watch?v=1wYNFfgrXTI', 'Eminem - When I\'m Gone'],
    ['https://www.youtube.com/watch?v=kimPUWSwxIs', 'Kasabian - You\'re In Love With a Psycho ' \
                                                    '(Official Video)'],
    ['https://www.youtube.com/watch?v=CevxZvSJLk8', 'Katy Perry - Roar (Official)'],
    ['https://www.youtube.com/watch?v=OVJSjD7nCKU', 'But what a day!'],
    ['https://www.youtube.com/watch?v=RYnFIRc0k6E', 'Limp Bizkit - Rollin\' (Air Raid Vehicle)'],
    ['https://www.youtube.com/watch?v=Ggu9d4xlTFo', 'Paul Scholes - The Shy Genius - ' \
                                                    'We Will Never Forget You - HD'],
    ['https://www.youtube.com/watch?v=LdPL9RMzQAY', 'Michael Collins - Give us back our country'],
    ['https://www.youtube.com/watch?v=i9nnnM-__JQ', 'Billy Connelly : National Anthem'],
    ['https://www.youtube.com/watch?v=1TO48Cnl66w', 'Dido - Thank You'],
    ['https://www.youtube.com/watch?v=0pBOLdZZT6s', 'Blood Diamond Leo Accents'],
    ['https://www.youtube.com/watch?v=LHCob76kigA', 'Lukas Graham - 7 Years [OFFICIAL MUSIC VIDEO]'],
    ['https://www.youtube.com/watch?v=dPPi2D6GK7A', 'Oasis - The Masterplan'],
    ['https://www.youtube.com/watch?v=oofSnsGkops', 'James Blunt - You\'re Beautiful (Video)'],
    ['https://www.youtube.com/watch?v=AeXOlgA-XuM', 'Surah Yasin, Surah Ar-Rahman & ' \
                                                    'Surah Al-Waqiah Full - Abdul Rahman Al Ossi'],
    ['https://www.youtube.com/watch?v=-MUotqxKSRs', 'Vlog 42 - Palliative Care'],
    [
      'https://www.youtube.com/watch?v=4zLfCnGVeL4',
      'The Sound of Silence (Original Version from 1964)'
    ],
    ['https://www.youtube.com/watch?v=3Bv27OcVlMQ', 'Chezidek - Call Pon Dem'],
    ['https://www.youtube.com/watch?v=co6WMzDOh1o', 'U2 - Beautiful Day'],
    ['https://www.youtube.com/watch?v=OP-A16Uybaw', 'Michael Collins 1996 - pułapka']
  ].freeze

  MOTION_PICTURES_SEQ = MOTION_PICTURES.dup.to_enum
  private_constant :MOTION_PICTURES, :MOTION_PICTURES_SEQ

  match 'play-motion-picture'
  group 'Misc'
  description 'Bored? Play a motion picture.'
  command_options argument_required: false

  def options(o)
    o.on :m, :match,
         'Play first motion picture that matches through a fuzzy search.',
         argument: true
    o.on :s, :sequential,
         'Play motion pictures in sequential order. Rewinds to start at the end.',
         argument: false
    o.on :i, :index,
         'Play a motion picture at a specific index.',
         argument: true
    o.on :c, :count,
         'Print the number of motion pictures available to play.',
         argument: false
  end

  def process
    case
    when opts.count?
      process_count MOTION_PICTURES.size
    when opts.index?
      process_index opts[:i]
    when opts.sequential?
      process_seq MOTION_PICTURES_SEQ
    when opts.match?
      process_fuzz_match opts[:m]
    else # Play motion picture at random.
      play
    end
  end

  private
  def process_count(count)
    _pry_.pager.page '%s motion pictures available' % count
  end

  def process_index(int)
    raise IndexError, "unsigned integer required (>= 0)" if int.to_i < 0
    play MOTION_PICTURES[Integer(int)][0]
  end

  def process_seq(seq)
    play seq.next[0]
  rescue Pry::RescuableException
    seq.rewind
    retry
  end

  def process_fuzz_match(pattern)
    result = MOTION_PICTURES.find {|(_, title)| title =~ /#{pattern}/i}
    return _pry_.pager.page "No matches :(" if not result
    play result[0]
  end

  def play(motion_picture=nil)
    motion_picture ||= begin
      require 'securerandom'
      randint = SecureRandom.random_number(MOTION_PICTURES.size)
      MOTION_PICTURES[randint][0]
    end
    syscall = _pry_.config.system
    syscall.call _pry_.output, "%s %s" % [_pry_.config.media_player, motion_picture].map {|input|
      Shellwords.shellescape(input)
    }
  end
  Pry::Commands.add_command(self)
  Pry::Commands.alias_command 'play-motion-picture-seq', 'play-motion-picture -s'
end
