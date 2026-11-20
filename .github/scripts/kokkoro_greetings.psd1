# Root hashtable of Kokkoro's dynamic greeting templates (deterministic from WIB release tag)
# Voice rules: polite keigo, humble, devoted; no slang or casual contractions; always 'Aruji-sama'.
# Lore: Astraea = continent / Pecorine's house; Landosol = capital city / guild house;
#       Kokkoro cooks; Pecorine eats heartily; Kyaru is tsundere (protests, never 'shy').
@{
    Timezone        = 'SE Asia Standard Time'
    MaxMainLength   = 145
    MaxNoteLength   = 80
    MaxBdayLength   = 90
    SoftGreetingCap = 380
    MajorThreshold  = 15
    Calendar        = @(
        # --- Kokkoro Birthday (May 11): Window H-6 / H / H+1 ---
        @{
            Name         = 'KokkoroBDay'
            Month        = 5
            Day          = 11
            WindowBefore = 6
            WindowAfter  = 1
            Priority     = 100
            LinesBefore  = @(
                'Aruji-sama, my birthday draws near on May 11. I would be honored to celebrate the day beside you. 🌸'
                'Aruji-sama, the eleventh of May approaches — my birthday. I shall prepare quietly to mark the occasion with you.'
            )
            Lines        = @(
                'Aruji-sama, today is my birthday. Thank you for walking this path with me — I shall continue to serve you faithfully. 🎂'
                'Aruji-sama, it is my birthday today. Your trust means everything to me, and I shall do my utmost for you. 🌸'
            )
            LinesAfter   = @(
                'Aruji-sama, thank you sincerely for your birthday wishes. I shall treasure your kindness and keep guiding you. 🌸'
                'Aruji-sama, my birthday has passed, yet your warmth remains in my heart. I am grateful to remain at your side.'
            )
            NoteBefore   = 'Incidentally, my own birthday draws near on May 11. 🌸'
            Note         = 'Today also happens to be my birthday, Aruji-sama. 🎂'
            NoteAfter    = 'Thank you again for the kind wishes on my birthday. 🌸'
        }

        # --- Gourmet Guild Birthdays: Window H-1 / H ---
        @{
            Name         = 'PecorineBDay'
            Month        = 3
            Day          = 31
            WindowBefore = 1
            WindowAfter  = 0
            Priority     = 96
            LinesBefore  = @(
                'Aruji-sama, tomorrow is Pecorine-sama''s birthday. I am preparing a splendid feast to celebrate with her. 🍙'
                'Aruji-sama, Pecorine-sama''s birthday is just one day away. Let us prepare a warm celebration together. ✨'
            )
            Lines        = @(
                'Aruji-sama, today is Pecorine-sama''s birthday! I have cooked a hearty feast so she may celebrate to her heart''s content. 🎂'
                'Aruji-sama, we celebrate Pecorine-sama''s birthday today. May her bright smile shine across Landosol. 🌸'
            )
            NoteBefore   = 'Incidentally, tomorrow is Pecorine-sama''s birthday. 🍙'
            Note         = 'Today is also Pecorine-sama''s birthday! 🎂'
            NoteAfter    = 'Pecorine-sama is still beaming from her birthday feast. 🍙'
        }
        @{
            Name         = 'KyaruBDay'
            Month        = 9
            Day          = 2
            WindowBefore = 1
            WindowAfter  = 0
            Priority     = 96
            LinesBefore  = @(
                'Aruji-sama, tomorrow is Kyaru-sama''s birthday. Let us prepare a thoughtful surprise for her. 🐱'
                'Aruji-sama, Kyaru-sama''s birthday arrives tomorrow. I shall make sure everything is ready for our celebration. ✨'
            )
            Lines        = @(
                'Aruji-sama, today is Kyaru-sama''s birthday! Though she may protest, I believe she treasures our company. 🎂'
                'Aruji-sama, let us offer our warmest wishes to Kyaru-sama on her birthday today. 🌸'
            )
            NoteBefore   = 'Incidentally, tomorrow is Kyaru-sama''s birthday. 🐱'
            Note         = 'Today is also Kyaru-sama''s birthday! 🎂'
            NoteAfter    = 'Kyaru-sama seemed quietly pleased by her birthday wishes. 🐱'
        }
        @{
            Name         = 'SheffyBDay'
            Month        = 1
            Day          = 11
            WindowBefore = 1
            WindowAfter  = 0
            Priority     = 96
            LinesBefore  = @(
                'Aruji-sama, tomorrow is Sheffy-sama''s birthday. Let us prepare a gentle and joyful celebration for her. ❄️'
                'Aruji-sama, Sheffy-sama''s birthday draws near tomorrow. I shall ready everything with care. ✨'
            )
            Lines        = @(
                'Aruji-sama, today is Sheffy-sama''s birthday! May her smile shine as brightly as clear winter crystal. 🎂'
                'Aruji-sama, let us celebrate Sheffy-sama''s birthday warmly together today. 🌸'
            )
            NoteBefore   = 'Incidentally, tomorrow is Sheffy-sama''s birthday. ❄️'
            Note         = 'Today is also Sheffy-sama''s birthday! 🎂'
            NoteAfter    = 'We shared a gentle celebration for Sheffy-sama''s birthday. ❄️'
        }

        # --- Holidays & Anniversaries: Window H-3 / H / H+1 ---
        @{
            Name         = 'JPAnniv'
            Month        = 2
            Day          = 15
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 92
            LinesBefore  = @(
                'Aruji-sama, our grand anniversary milestone draws near! Festive preparations are filling Landosol. ✨'
                'Aruji-sama, the anniversary celebration approaches in just a few days. Let us look forward to it together. 🌸'
            )
            Lines        = @(
                'Aruji-sama, happy anniversary! Thank you for continuing our journey across Astraea together. 🎉'
                'Aruji-sama, let us celebrate another wonderful year of adventures in Landosol together. 🌸'
            )
            LinesAfter   = @(
                'Aruji-sama, the anniversary festivities continue! Let us keep creating cherished memories together. ✨'
                'Aruji-sama, following yesterday''s anniversary milestone, I have prepared today''s latest update for you. 🌸'
            )
            NoteBefore   = 'Incidentally, the anniversary of our journey arrives tomorrow. 🎉'
            Note         = 'Today marks the day our journey in Landosol began. 🎉'
            NoteAfter    = 'The anniversary festivities continue into today. 🎉'
        }
        @{
            Name         = 'NewYear'
            Month        = 1
            Day          = 1
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 90
            LinesBefore  = @(
                'Aruji-sama, the current year is drawing to a close. Let us prepare calmly to welcome the new year together. 🎍'
                'Aruji-sama, only a few days remain before the new year arrives. Thank you for your steadfast guidance. ✨'
            )
            Lines        = @(
                'Aruji-sama, Happy New Year! May this new year bring you good health, fortune, and peaceful journeys. 🎍'
                'Aruji-sama, a fresh year begins today. I shall continue to guide and support you faithfully. ✨'
            )
            LinesAfter   = @(
                'Aruji-sama, the new year has begun smoothly. I have arranged the latest update notes for you below. 🎍'
                'Aruji-sama, may the opening days of this new year treat you kindly as you review this update. ✨'
            )
            NoteBefore   = 'Incidentally, the new year will soon be upon us. 🎍'
            Note         = 'Today is also New Year''s Day in Landosol. 🎍'
            NoteAfter    = 'May the opening days of this new year bring you peace. 🎍'
        }
        @{
            Name         = 'Christmas'
            Month        = 12
            Day          = 25
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 88
            LinesBefore  = @(
                'Aruji-sama, Christmas draws near! Winter lights are twinkling brightly across town. 🎄'
                'Aruji-sama, the winter festivities are almost upon us. Please dress warmly while reviewing this update. ❄️'
            )
            Lines        = @(
                'Aruji-sama, Merry Christmas! Please stay warm while we enjoy this peaceful winter celebration. 🎄'
                'Aruji-sama, festive lights fill the winter air today. I have prepared a fresh update for your holiday. ✨'
            )
            LinesAfter   = @(
                'Aruji-sama, I hope you enjoyed a peaceful Christmas. Here is a fresh update as the year nears its end. ✨'
                'Aruji-sama, the gentle warmth of Christmas lingers on. Please review today''s latest changes below. 🎄'
            )
            NoteBefore   = 'Incidentally, Christmas is nearly upon us. 🎄'
            Note         = 'Today is Christmas Day as well, Aruji-sama. 🎄'
            NoteAfter    = 'The gentle warmth of Christmas still lingers today. 🎄'
        }
        @{
            Name         = 'Valentine'
            Month        = 2
            Day          = 14
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 84
            LinesBefore  = @(
                'Aruji-sama, Valentine''s Day approaches. I am preparing a small token of gratitude with utmost care. 💝'
                'Aruji-sama, only a few days remain until Valentine''s Day. Please accept this update in the meantime. 🌸'
            )
            Lines        = @(
                'Aruji-sama, Happy Valentine''s Day. Please accept this humble update prepared with sincere appreciation. 💝'
                'Aruji-sama, on this gentle day of gratitude, I am thankful to remain faithfully by your side. 🌸'
            )
            LinesAfter   = @(
                'Aruji-sama, I hope yesterday''s Valentine''s Day brought you warmth. Here is today''s newest update. 🌸'
                'Aruji-sama, thank you always for your kindness. Please inspect the latest translation notes below. 💝'
            )
            NoteBefore   = 'Incidentally, Valentine''s Day is nearly upon us. 💝'
            Note         = 'Today is Valentine''s Day as well. 💝'
            NoteAfter    = 'The warmth of yesterday''s Valentine still lingers. 💝'
        }
        @{
            Name         = 'WhiteDay'
            Month        = 3
            Day          = 14
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 80
            LinesBefore  = @(
                'Aruji-sama, White Day is just around the corner. Gentle spring breezes carry warm feelings. 🤍'
                'Aruji-sama, White Day approaches soon. I have organized today''s latest translation files for you. ✨'
            )
            Lines        = @(
                'Aruji-sama, Happy White Day. Your thoughtfulness always guides me — please accept this new update. 🤍'
                'Aruji-sama, on this serene White Day, I remain grateful for your constant care and leadership. 🌸'
            )
            LinesAfter   = @(
                'Aruji-sama, thank you for always being so considerate. Here are the newest translation updates below. 🌸'
                'Aruji-sama, following yesterday''s White Day, everything is neatly prepared for your journey. ✨'
            )
            NoteBefore   = 'Incidentally, White Day approaches soon. 🤍'
            Note         = 'Today is also White Day, Aruji-sama. 🤍'
            NoteAfter    = 'The gentle spirit of White Day remains with us today. 🤍'
        }
        @{
            Name         = 'Halloween'
            Month        = 10
            Day          = 31
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 76
            LinesBefore  = @(
                'Aruji-sama, Halloween is drawing near. Festive autumn decorations are appearing across Landosol. 🎃'
                'Aruji-sama, autumn lanterns and playful decorations announce that Halloween is nearly here. 🍂'
            )
            Lines        = @(
                'Aruji-sama, it is Halloween today. Even among playful spirits, your faithful guide remains right beside you. 🎃'
                'Aruji-sama, festive autumn mischief fills the air — please enjoy this new update safely. 🍂'
            )
            LinesAfter   = @(
                'Aruji-sama, Halloween has passed peacefully. Here is today''s latest translation update. 🍂'
                'Aruji-sama, now that the Halloween festivities have settled, please review the latest notes below. ✨'
            )
            NoteBefore   = 'Incidentally, Halloween is nearly upon us. 🎃'
            Note         = 'Today is Halloween as well, Aruji-sama. 🎃'
            NoteAfter    = 'The playful autumn air of Halloween still lingers. 🎃'
        }
        @{
            Name         = 'Tanabata'
            Month        = 7
            Day          = 7
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 72
            LinesBefore  = @(
                'Aruji-sama, Tanabata approaches soon. Have you thought of a wish to inscribe upon a paper strip? 🎋'
                'Aruji-sama, the star festival draws near. I am preparing colorful strips for our wishes. ✨'
            )
            Lines        = @(
                'Aruji-sama, it is Tanabata today. I have written a wish upon a strip of paper for your well-being. 🎋'
                'Aruji-sama, may the stars of Tanabata watch gently over our travels together across Astraea. ✨'
            )
            LinesAfter   = @(
                'Aruji-sama, may the wishes we entrusted to the stars of Tanabata soon be fulfilled. ✨'
                'Aruji-sama, following the star festival, I have prepared today''s update summary below. 🎋'
            )
            NoteBefore   = 'Incidentally, the Tanabata star festival draws near. 🎋'
            Note         = 'Today is also the Tanabata star festival. 🎋'
            NoteAfter    = 'May our Tanabata wishes reach the stars above. 🎋'
        }
        @{
            Name         = 'GoldenWeek'
            Month        = 5
            Day          = 3
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 68
            LinesBefore  = @(
                'Aruji-sama, the spring holidays are approaching. Let us prepare our equipment for restful travels. 🌿'
                'Aruji-sama, Golden Week draws near. I have tidied our translation files ahead of the holidays. ✨'
            )
            Lines        = @(
                'Aruji-sama, Happy Golden Week! May your holidays be filled with peaceful adventures across Astraea. ✨'
                'Aruji-sama, please enjoy a restful holiday while reviewing the newest translation updates below. 🌿'
            )
            LinesAfter   = @(
                'Aruji-sama, I hope you are enjoying the spring holiday season. Here is a fresh update for your journey. 🌸'
                'Aruji-sama, everything remains in good order during these pleasant holiday days. ✨'
            )
            NoteBefore   = 'Incidentally, the Golden Week holidays draw near. 🌿'
            Note         = 'Today is also part of the Golden Week holidays. 🌿'
            NoteAfter    = 'I hope your Golden Week holidays remain restful. 🌿'
        }
        @{
            Name         = 'Hanami'
            Month        = 3
            Day          = 25
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 64
            LinesBefore  = @(
                'Aruji-sama, the cherry blossom buds are about to open. Spring will soon be in full bloom. 🌸'
                'Aruji-sama, blossom season draws near. Perhaps we may enjoy a quiet tea break once the flowers open. 🍵'
            )
            Lines        = @(
                'Aruji-sama, the cherry blossoms are blooming softly. Perhaps we can enjoy a brief rest after updating. 🌸'
                'Aruji-sama, spring petals dance upon the gentle breeze today. Here is the latest update for your journey. 🌸'
            )
            LinesAfter   = @(
                'Aruji-sama, drifting cherry petals still adorn the paths today. Please check the newest notes below. 🌸'
                'Aruji-sama, the serene beauty of spring accompanies today''s fresh translation update. ✨'
            )
            NoteBefore   = 'Incidentally, the cherry blossoms will soon reach full bloom. 🌸'
            Note         = 'The cherry blossoms are in lovely bloom today. 🌸'
            NoteAfter    = 'Drifting cherry petals still grace the breeze today. 🌸'
        }
        @{
            Name         = 'Obon'
            Month        = 8
            Day          = 15
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 60
            LinesBefore  = @(
                'Aruji-sama, the midsummer lantern season draws near. Please take good care in the summer heat. 🏮'
                'Aruji-sama, gentle summer lanterns will soon be lit. Remember to rest well and stay hydrated. 🍵'
            )
            Lines        = @(
                'Aruji-sama, the midsummer lantern season is here. Please take good care of yourself in the heat. 🏮'
                'Aruji-sama, gentle lanterns glow warmly today. I have prepared a new update for you below. ✨'
            )
            LinesAfter   = @(
                'Aruji-sama, the warm glow of the summer lanterns still lingers. Here is today''s update report. 🏮'
                'Aruji-sama, please continue to stay cool and well-rested while checking the latest changes. ✨'
            )
            NoteBefore   = 'Incidentally, the midsummer lantern season draws near. 🏮'
            Note         = 'Today marks the midsummer lantern festival. 🏮'
            NoteAfter    = 'The gentle glow of the summer lanterns lingers today. 🏮'
        }
        @{
            Name         = 'Tsukimi'
            Month        = 9
            Day          = 15
            WindowBefore = 3
            WindowAfter  = 1
            Priority     = 56
            LinesBefore  = @(
                'Aruji-sama, the autumn harvest moon will soon be full. Shall I prepare some rice dumplings? 🌕'
                'Aruji-sama, moon-viewing season approaches. Clear autumn skies await us soon. ✨'
            )
            Lines        = @(
                'Aruji-sama, the autumn harvest moon shines brightly. Let us review the latest updates calmly. 🌕'
                'Aruji-sama, a serene moonlit season greets us. Please check the newest translation notes below. ✨'
            )
            LinesAfter   = @(
                'Aruji-sama, the tranquil autumn moonlight remains lovely. Here is today''s update summary. 🌕'
                'Aruji-sama, following our peaceful moon viewing, everything is neatly arranged for you below. ✨'
            )
            NoteBefore   = 'Incidentally, the autumn harvest moon will soon be full. 🌕'
            Note         = 'Today is also the autumn moon-viewing festival. 🌕'
            NoteAfter    = 'The tranquil autumn harvest moon lingers on. 🌕'
        }
    )
    Seasons         = @(
        @{
            Name   = 'Spring'
            Months = @(3, 4, 5)
            Lines  = @(
                'Aruji-sama, a gentle spring breeze accompanies today''s update. Let us review what is new. 🌸'
                'Aruji-sama, the warmth of spring has arrived in Landosol. I have organized the latest changes below. ✨'
                'Aruji-sama, fresh spring blossoms brighten our path across Astraea today. Please review the new notes. 🌸'
                'Aruji-sama, I gathered fresh spring herbs at the Landosol market before tidying today''s update files. 🌿'
                'Aruji-sama, Pecorine-sama is already eager for a spring picnic, so I prepared provisions and this patch. 🍙'
                'Aruji-sama, mild spring weather greets the Gourmet Guild today. Here is the latest translation report. ✨'
            )
        }
        @{
            Name   = 'Summer'
            Months = @(6, 7, 8)
            Lines  = @(
                'Aruji-sama, please remember to stay hydrated in this summer weather while checking the new update. ☀️'
                'Aruji-sama, bright summer skies greet Landosol today. Here is the latest report on our progress. ✨'
                'Aruji-sama, I have prepared chilled tea for the guild while organizing today''s translation updates. 🍵'
                'Aruji-sama, even under the warm summer sun, our journey across Astraea continues smoothly. 🌻'
                'Aruji-sama, Kyaru-sama insisted she was fine in the heat, though she gladly accepted a cold drink. 🐱'
                'Aruji-sama, please rest in the shade for a moment as you look over today''s newest changes. ✨'
            )
        }
        @{
            Name   = 'Autumn'
            Months = @(9, 10, 11)
            Lines  = @(
                'Aruji-sama, the crisp autumn air feels refreshing today. I have prepared the latest update report. 🍂'
                'Aruji-sama, calm autumn days have arrived in Landosol. Please review the newly updated files below. ✨'
                'Aruji-sama, the autumn harvest has filled the market with fine ingredients for the Gourmet Guild. 🍠'
                'Aruji-sama, golden leaves drift across Astraea today. I have gathered the latest translation notes for you. 🍁'
                'Aruji-sama, Pecorine-sama has been eyeing the autumn chestnuts, while I prepared this update for you. 🌰'
                'Aruji-sama, cool autumn breezes make travel pleasant. Here is a summary of what has been refined. ✨'
            )
        }
        @{
            Name   = 'Winter'
            Months = @(12, 1, 2)
            Lines  = @(
                'Aruji-sama, please keep yourself warm in this chilly weather while I present today''s update. ❄️'
                'Aruji-sama, a quiet winter day brings another step forward. Here are the latest release notes. ✨'
                'Aruji-sama, I have simmering stew ready in the guild kitchen so everyone stays warm in Landosol. 🍲'
                'Aruji-sama, Sheffy-sama seems right at home in this crisp winter air. Please review today''s update. ❄️'
                'Aruji-sama, though winter winds blow across Astraea, your faithful guide has everything in order. 🧣'
                'Aruji-sama, please enjoy a warm cup of tea while looking through the latest translation changes. 🍵'
            )
        }
    )
    Context         = @{
        Critical    = @(
            'Aruji-sama, please read the critical config notice below carefully before applying this update. ⚠️'
            'Aruji-sama, important configuration changes require your attention before you launch the game. ⚠️'
        )
        Maintenance = @(
            'Aruji-sama, only quiet housekeeping was performed this time — no translation changes were needed. 🍃'
            'Aruji-sama, everything remains calm and orderly; this is a routine maintenance release. ✨'
        )
        NewStory    = @(
            'Aruji-sama, new story chapters have arrived! Shall we read through the latest tales together? 📖'
            'Aruji-sama, fresh story translations are ready for you to experience at your leisure. ✨'
            'Aruji-sama, another chapter of our journey across Astraea and the other worlds has been translated. 📜'
        )
        Plugin      = @(
            'Aruji-sama, plugin components have been updated to keep our tools running smoothly. 🔧'
            'Aruji-sama, I have prepared a summary of the latest plugin improvements for your setup. ✨'
        )
        Major       = @(
            'Aruji-sama, a substantial batch of translations has arrived! Please take your time reviewing it. 📚'
            'Aruji-sama, we made great strides today — many files have been newly translated and refined. ✨'
        )
        Texture     = @(
            'Aruji-sama, fresh visual and interface textures have been polished to make your screen clearer. 🖼️'
            'Aruji-sama, newly translated graphics are ready so every banner and menu feels right at home. ✨'
        )
        Default     = @(
            'Aruji-sama, Pecorine-sama has already asked what is for supper. I shall prepare enough for everyone. 🍲'
            'Aruji-sama, the market in Landosol is lively today. I have gathered fresh ingredients for the guild. 🥕'
            'Aruji-sama, Kyaru-sama insists she has no interest in sweets, yet she lingered by the kitchen. 🍰'
            'Aruji-sama, our journey across Astraea continues. Please allow me to see to your preparations. 🌿'
            'Aruji-sama, I have packed provisions for the road ahead. Please rest before we set out. 🎒'
            'Aruji-sama, Sheffy-sama asked about the stars again. The zodiac tales weigh on my mind. ✨'
            'Aruji-sama, whether our path leads through Geo Gehenna, Geo Teogonia, or other worlds, I remain by your side. 🌸'
            'Aruji-sama, from Elpis Demonfront to Alshat Temptation, I shall faithfully record every step of our journey. 📜'
        )
    }
}
