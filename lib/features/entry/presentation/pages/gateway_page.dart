import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:everglow/features/dashboard/domain/models/milestone.dart';
import 'package:provider/provider.dart';
import 'package:everglow/services/auth_service.dart';
import '../state/gateway_state.dart';
import '../widgets/animated_door.dart';
import '../widgets/passcode_input.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  final GatewayNotifier _notifier = GatewayNotifier();
  bool _hasNavigated = false;
  GatewayState? _lastProcessedState;

  @override
  void initState() {
    super.initState();
    _notifier.addListener(_onStateChange);
    _seedDataOnce();
  }

  Future<void> _seedDataOnce() async {
    try {
      print("Checking for memories to seed...");
      final db = FirebaseFirestore.instance;

    Future<void> seedIfMissing(String title, Milestone data) async {
      try {
        final snap = await db.collection('milestones').where('title', isEqualTo: title).get();
        if (snap.docs.isEmpty) {
          await db.collection('milestones').add(data.toFirestore());
          print("Seeded: $title");
        } else {
          print("Already exists: $title");
        }
      } catch (e) {
        print("Error seeding $title: $e");
      }
    }

    await seedIfMissing("First Date", Milestone(
      id: '',
      title: "First Date",
      date: DateTime(2026, 2, 14),
      author: "Khent",
      description: "Okay what happened here is i asked her out for valentines and it seems she was shocked i guess? I dont know why pero she was like “OMLLLL” pero its understandable since from her words, its her first time having someone ask her out for valentines pud daw, and for me, its also gonna be my first time giving out flowers so im kinda nervous too, so fast forward nagkita mi at 5:30 since mao na ang sabot and it was kinda cute kay nag tago sya atbang sa csu and not exactly at our meetup place which is 7/11, cutiee kaayo na and damn was i starstruck sa iyahang beauty, i know shes beautiful already based from her pics pero the beauty when seen personally is even a whole’nother level so i kinda forgot my script and even when i finally remembered it, it’s useless cause pan os na ang scene pero either way wa mi nagdugay didto csu since niadto mi diretso sa zackies and we talked there, thats where i knew her abit, specially her hobbies and about her love with ethel cain and her songs, the highlight really was just the fact that she didnt get uncomfy i guess? She really was in the mood to talk maybe cause i asked about ethel cain and the convo swayed from there making it work out best, either way i can say rhat i really did clutch Valentines, we took cute pictures and did a trend nga kabalo sya which was to put the flower para tabunan among faces in rhat video, it will look like a lowkey fit check or ootd something which was cuteee. Ofc ended the night nga gihatud nako sya and it seems tapok2 sya? Or maybe wa ra kaabot, idk pero didto sya sa luyo sa csu, i hope maka adto gyud ko door to door",
      imageUrls: [
        'assets/images/milestones/valentines_khent_1.jpg',
        'assets/images/milestones/valentines_khent_2.png',
        'assets/images/milestones/valentines_khent_3.jpg',
        'assets/images/milestones/valentines_khent_4.jpg',
      ],
    ));

    await seedIfMissing("Our First Kiss", Milestone(
      id: '',
      title: "Our First Kiss",
      date: DateTime(2026, 2, 17),
      author: "Khent",
      description: """So i started the day on a worrisome note cause naa syag butuan and it seems nilakaw sya 2pm pa, she only told me kay hapon na so ofcourse im very worried so i did everything in my power mga sugtan ko mu adtog butuan and good thing gi sugtan ko, and ofcourse after that ni adto kog butuan doing the maximum speed i can and got there in 30 minutes despite huge traffic sa bridge got into sm fast and shes waiting sa second floor and when i see her, cute kaayo na kay pink na pink kaayo iyang fit, both hoodie and cap HAHAHAHAHA, we ate sa mang inasal which was funny kay katong big nga pecho lang ang available and when compared to her fist, its literally bigger HAHAHAHA after that mo uli nami and guess what, we decided nga musakay together, after borrowing some helmet from my bro edward, we hop on our meh way, at first from butuan to 7/11 in somewhere sa ampayon, we stopped kay ulan man and did some quality time there doing stuff i thought was cringe but it felt natural HAHAHAHA after that wala na ang rain so we went on, it seems to me she was really scared and the intercom was barely making her less scared than usual which is funny since she says shes scared pero shes drowsy, literally sleeping on my back while im driving which was worrisome, time flied past and somehow abot nami, decided nga muagi sa la union and then didto mi agi sa calibunan and then gawas traffic light mabini and ofc gi hatud nako sya, pero we both talked about it and decided on some coffee instead sa 7/11 since shes drowsy and she was planning on staying up late kay naa daw silay quiz so after we bought some coffee and i picked a mogu2 like drink, but its a diff brand, then nagsabot mi nga adtog creek, unfortunately nahulog ang helmet which is ouchy but its fine, it inevitably happens but it seems shes more affected than me about it, we spend a good few minutes on it but di gyud maayo without tools so i just promised ill fix it back home, so after a few talks and cuddles here and there, she suddenly kissed me which was surprising but not at the same time since she keeps mentioning about “what if mag kiss ta” and stuff like that as well as our convo being about kisses and all pero still, when it happened it was still a shocker, completely mind blowing, we both wanted more so ofcourse more kisses as we both also melted while doing so, it was a fun moment, she was somehow scared that we got recorded since there were people a good few meters away from where we stayed but its impossible since its night and dark, the iso would just make the video blurry even when zoomed so our identities would be kept safe, all in all we both decided to finally go home since she was already getting calls as well as myself getting calls, and ofcourse we also kissed there at the back of csu where i dropped her off, overall it was a day of continuous plot twists that i will never forget, her first time of being a passenger princess on a motorcycle under a considerable amount of distance and the happiness to know that she trusted me on it, as well as the spicy things that happened.. its a day i will never forget.""",
      imageUrls: [
        'assets/images/milestones/kiss_khent_1.jpg',
        'assets/images/milestones/kiss_khent_2.jpg',
        'assets/images/milestones/kiss_khent_3.jpg',
        'assets/images/milestones/kiss_khent_4.png',
        'assets/images/milestones/kiss_khent_5.jpg',
      ],
    ));

    await seedIfMissing("A Day Before Your Birthday", Milestone(
      id: '',
      title: "A Day Before Your Birthday",
      date: DateTime(2026, 2, 20),
      author: "Khent",
      description: """A day before her birthday so we planned on going to butuan and finally it seems iyaha nagyud kong ingnun unlike 3days ago where kalit ra syag naa na sa butuan at night which was worrisome, im finally with her at the start of the journey but unfortunately naa syay class so we can only do it after shes done with her schedule for the day, nahumana sya mga 4pm ish ni uli sya para mag ilis and diretso namis terminal, didto rapud mi nag kita duha, sakay mig van padulong and it was cute cause katulgon gyud diay sya, natulog gyud sya didtos van atoosh, so nig abot namo we decided mag eat, and somehow we picked a luxury dining restaurant like gaddamn geabe ka extravagant mag gasto ois, sya pagyud mag gasto, grabe ka rich kid na, since kulang akoa money dala, tua syay nigasto, which is ofc urang ra ang i will pay it back later on pero later on pana kay ofc tigum pa ihihi, then after were done eating we go trifting in which ofcourse sya gihapon gasto, atat gakaulaw ko na, my pride as a man is slowly going to be broken HAHAHAHAH, like the embarassment pag abot sa paying time nga dili ako mo duol sa cashier but ang babae, like dayum those cashiers might be thinking “wtf” due to what theyre seeing pero ofc i dont care, i will just pay it back to her in the future anyways, thats the whole point of an rs, a give and take relationship but either way after thrifting ni sakay namig bus, ofc nag pursigi kog bus para naa syay space maka tulog gyud since katong sa van kay putol2 man and guess i made the right decision kay nakatulog gihapon sya, she woke up just like how a normal person would wake up after a sleep which is atooosh so cutee, then after ni abot namis terminal we decided on mag mcdo kay ga crave kog fries, this time ako nay bayad kay atat basad pati kani kay siya gihapon huhu, and we also ordered buy 1 take 1 ice cream which we ate and since nangita naman iyahang parents, nanakayan rami padung didtos likod sa csu in which nig abot ni naog sa ko so that we can kiss and yes we did, although pingis lang lagi, kay kadiyot ra since she told the driver nga i hatud pako padung sa amoa, so the driver waited so i didnt take long ofc kay ulaw man, which ended the day. Overall i fot alot of things nga siyay ni libre that i would infact keep always, and ofcourse pay her back kay medyo mahal2 gyud ni iyang nalibre, mga 2.5k guro, and i need to pay back that kind of amount in the future, puhon2 but for now, im happy since i can see that although shes still avoidant, shes starting to trust me more na, atoosh so cute""",
      imageUrls: [
        'assets/images/milestones/birthday_pre_khent_1.jpg',
        'assets/images/milestones/birthday_pre_khent_2.jpg',
        'assets/images/milestones/birthday_pre_khent_3.jpg',
        'assets/images/milestones/birthday_pre_khent_4.jpg',
        'assets/images/milestones/birthday_pre_khent_5.png',
      ],
    ));

    await seedIfMissing("Puting Bato x Zackie's Restaurant Date", Milestone(
      id: '',
      title: "Puting Bato x Zackie's Restaurant Date",
      date: DateTime(2026, 3, 14),
      author: "Khent",
      description: """Time flies fast, its been a month since i met her, we planned to meet at 4pm but it got delayed to 4:30pm since mag ready padaw sya which is cute pero as i go there, timing pud mao pay pag gawas niya, fate really moves in mysterious ways, and one thing thats interesting is that i said that we will go to puting bato to check that good view and she excitedly said yes pero ofc i dont know what changed her mind, probably gas price or the distance in which kapuyon ata ko, but she said ayaw nalang daw kay layo, pero ofcourse once i made up my mind, i go for it so we just go, then after byahe of 30-40min kaabot nami didtos peak where we can see the S view of the road and it was a moment of my life that i will never forget, shes probably the first woman that ive been with to enjoy that view, we took pictures, did a public display of affection despite there being people around and best of all, we get to spend time with each other talking about random stuff. As time passed, nag rain naman so we quickly got out and got down, and then we planned to go to that coffee something shop in which she said that she saw on facebook or tiktok and unfortunately the owner said its closed already which put a frown on her face for abit but like i said, fate moves in mysterious ways, the owner or ang nagbantay actually said that its still fine to go and standby so ofcourse we took up her offer, and we got there and little did we know it really was what she saw in social media which made her act childish and to my eyes it was insanely cute, like a child finally getting their favorite toy, and ofcourse doing the usual, we spent time, hugging always sa duyan never breaking contact and i believe it was an hour, the time that we were like that, we did a few kisses here and there and talked casually, spending time together and damn i wish it would just last forever cause as time passed and we need to go back cbr, we ate ilocos impanada didto sa terminal in which the taste wasnt really what i liked unfortunately, so i wasnt able to finish it which was sad but i really just cant, grabe ka bidli HAHAHAHAHAH, either way tho, we go to zackies and ate, we watched a few funny tiktok clips while waiting for our order to get served then after it finally got served we ate and i was very full, full of protein it seems due to how much chicken i ate and rice i gobbled up, which probably looks like im bulking or something, another lovely time moment spent and then after that we ended it on our usual place rhats close to her house, which is creek, unfortunately there were guards and police in the end of where we stayed so we can let losse and theres also a few randoms here and there but it seems she just can hold it back and we did it despite the guards and police being there and it spiced it up it seems, the thought of being caught just made it more.. good? Either way as time goes by and the inevitable thing of me taking her back home is etching and etching closer, i somehow kinda regret not cherishing the time at the coffe shop view didtos puting bato, i did hug her always there but i kinda just dozed off and let myself comfortable rather than actively feeling that kind of situation which was quite sad, the inevitable happened as i finally got her didtos luyo sa csu and ofcourse as per the usual, we ended the moment with a hot kiss, and by hot i meant REAL hot. From 4:30pm to 10pm, a mere 5 and a half hours yet alot has happened in those 5 hours, and it felt like its been 5 days really, i just hope i can spend more time casually with her, but thats not going to happen, not until i can introduce her to my fam or the other way around.""",
      imageUrls: [
        'assets/images/milestones/puting_bato_khent_1.jpg',
        'assets/images/milestones/puting_bato_khent_2.png',
        'assets/images/milestones/puting_bato_khent_3.png',
        'assets/images/milestones/puting_bato_khent_4.jpg',
        'assets/images/milestones/puting_bato_khent_5.jpg',
      ],
    ));

    await seedIfMissing("Your Friends, Cafe, and Bar", Milestone(
      id: '',
      title: "Your Friends, Cafe, and Bar",
      date: DateTime(2026, 3, 27),
      author: "Khent",
      description: """It started on 5 or 6 something ish pm, iyaha ko nakit an so ni sulod mi, unfortunately bawal gyud ang outsiders so we were akward there standing, trying to find a way so then we decided on mag id ko and i proposed going to the front gate and she said dili kay im gonna be alone daw so i reassured her its fine, fortunately i was able to convince her so i went on to go, got in the front gate and ni straight ko, directly didtos construction nga di ma agian, i asked the people there as aang agianan, thankfully there was a door, and they were helpful so ofcourse ni diretso nako didtoa but then i saw them rotc pips again so i took a detour and waited nga naay kasabay, nakasulod ra dayon ko sa oval or unsa bay tawag ana, then comes the hardest part, ang pagsulod sa gym, same strategy—i waited for daghan tao and fortunately i got in, was trying to find them but i just opt to go sit on the right wing and fortunately i found them there, gi uli nako ofcourse ang id ni justine, and it was kinda awkward at first pero paglakaw ni clair, i inteoduced my self to the three of them, and i spent my time there just staying silent since banha sab kaayo, i also just read manwhas ofc, then as time goes by, nanglakaw nami, to go to cafelaz kay didtoa daw mag eat, naguna sila kay magbaktas pako pa adto sa motor nga nakapark didtos 7/11, then pag apas nako sa cafelaz, i sat down close to her ofcourse and whats funny is that she felt awkward i guess, since she wanted us to eat outside so they can take “pictures” kuno daw and me and justine were having the same brain neuron activation as we just said that its fine and shes just the one thats making it weird, insane link up by me and bro, and then they took a bunch of pictures, actually who am i kidding, they took a lot and even then “alot” is an understatement, cause imagine nalang good—they took an insane amount of pictures that one of the staff that was handing out a drink asked us if nag order naba mi and in which case, wala pa HAHAHAHAHA and even after that, WALA pa gihapon naka order, like whaduhelly, we probably took a good hour or something there just taking pics and delaying, probably even more than an hour HAHAHAHA. It was good actually cause atleast naa nay character sakoa ang mga friends ni clair and not just sa kuan lang, iyahang mga story, i actualy get to experience their personalities and they were such a vibe, both recca and justine, as for the other one, she was just silent the whole time or atleast didnt talk much,  then ofcourse we ordered and me and justine were the ones going sa counter to pick a order and after were done and ga repeat na ang staff sa amoang order, unfortunately we can only buy one pancake, so they need to decide which flavor and damn was it so long, it was very long that it was getting awkward between me and the staff kay ako may nabilin and si justine ang nag talk sa ilaha and thankfully it didnt take long that much as finally they decided and picked choco as it was clair’s pick and it was mine to pay man sab, and i picked grilled chicken, in which inig serve very gamay rapud kaayo and it was not “aesthetic” and sabotaged their picture HAHAHAH, im not sure if gi myday ba nila apil akoang food since were not moots with her friends man pero i dont really care, its just a funny thought, so as time goes by and we finished eating we got out na and saka didto sa bros bar in which i thought all four of them would go on a bar and mo uli ra unta ko pero after knowing duha ra sila ni recca, i just go ahead and uban in which nagkita sila sa ilang mga cm and we got into their table and as per the usual they asked if i was gonna drink and i politely declined and said i dont drink, and my plan was just to stay there and just let her go all out  and yes thats what happened, i just stayed there and bided my time peacefully even though the place was chaotic, i was getting drowsy but i held myself back so that she wont feel bad sakoa, and then theres this one time nga nibalik na sya from dancing and she opened up how she was kinda envious on how other girls are having friends with their “boyfriend” daw kuno and im still overwhelmed and im not used to the place so i was kinda semi avoiding it and wa man pud sya namugos so i guess it was fine, now as tome goes by it was just me being in a drowzy state trying to relieve some boredom by observing the people and seeing different types and observing this pretty much unfamiliar teritory para sakoa and she is “nitpicking” me cause i was checking out other girls daw kuno and ofcourse thats not entirely false cause i am observing pero the thing is—whether it be a girl,boy,gay,lesbian,stone,rock,walls or whatever, im checking out everything cause im bored but shes just nitpicking on the fact that i am checking on “girls” in which i just assured her and her mood got down due to that i guess, which i was trying to comfort and assure her and it worked, i guess? Now its 2am and nag on suga ang bros bar and it seems that ends the party HAHAHAHAH, nakulangan pato mga cm nila bisag hubog na kaayo and we decided to hatud recca first ofc, and then we both got on our merry way to the spot nga duol sa amoang house as always and pag abot namo didto nag maoy sya, she talked about cheat lagi daw and how gina story sa iyaha mga friends that they got cheated on and i reassured her nga the man that cheated on her friends is not the same as me, i explained about the law of causality, i explained about how in every light there is darkness typa things and she just says “shut up” and thats when i realized that shes in her baby baby kind of state i guess, i dont really know, and the convo even went on to one of her friends on how she just cheats on every single test and exam and how even on pe kuno daw mag cheat sya HAHAHAHAH, but either way she kepy saying we should cooloff and ofcourse i hadnt thought much about it since its probably just one of those tendencies again, as gihatud na nako sya pauli, i let her read in my keep notes which somehow proves to be a bad thing but it is what it is, whats important is that i got to meet her friends and my first time in a bar was with her. Ofc it ended with me hatud her likod csu aswell as a kiss.""",
      imageUrls: [
        'assets/images/milestones/friends_bar_khent_1.jpg',
        'assets/images/milestones/friends_bar_khent_2.jpg',
        'assets/images/milestones/friends_bar_khent_3.jpg',
        'assets/images/milestones/friends_bar_khent_4.jpg',
      ],
    ));

    print("Seeding process complete.");
    } catch (e) {
      print("Global seeding error (likely permission denied): $e");
    }
  }

  Future<void> _onStateChange() async {
    if (!mounted) return;
    
    final newState = _notifier.currentState;
    if (newState == _lastProcessedState) return;
    _lastProcessedState = newState;

    setState(() {});

    if (newState == GatewayState.unlocking) {
      final passcode = _notifier.lastEnteredPasscode;
      final authService = context.read<AuthService>();
      
      // Use real authenticated accounts for better persistence and rules compatibility
      if (passcode == '1111') {
        await authService.loginWithPasscode('clairjassen');
      } else if (passcode == '2222') {
        await authService.loginWithPasscode('khentsgdz');
      } else {
        await authService.ensureAuthenticated();
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _notifier.updateState(GatewayState.revealingSite);
      });
    } else if (newState == GatewayState.revealingSite) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) _notifier.updateState(GatewayState.complete);
      });
    } else if (newState == GatewayState.complete) {
      if (!_hasNavigated) {
        _hasNavigated = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
                const DashboardScreen(animate: false),
            transitionDuration: Duration.zero,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_onStateChange);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.twilight,
              AppTheme.velvet,
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _buildMainContent(),
            if (_notifier.currentState != GatewayState.complete)
              _buildGatewayOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildGatewayOverlay() {
    final state = _notifier.currentState;
    
    return IgnorePointer(
      ignoring: state == GatewayState.revealingSite,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: (state == GatewayState.revealingSite || state == GatewayState.complete) ? 1.0 : 0.0,
        ),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInQuint,
        builder: (context, zoom, child) {
          return ClipPath(
            clipper: _DoorMaskClipper(zoom: zoom),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: AppTheme.twilight,
              child: Center(
                child: AnimatedDoor(
                  isUnlocked: state == GatewayState.unlocking || 
                              state == GatewayState.revealingSite ||
                              state == GatewayState.complete,
                  isError: state == GatewayState.error,
                  isRevealing: state == GatewayState.revealingSite ||
                               state == GatewayState.complete,
                  onEntranceComplete: () {
                    if (_notifier.currentState == GatewayState.initialLoad) {
                      _notifier.updateState(GatewayState.awaitingInput);
                    }
                  },
                  keypad: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: (state == GatewayState.awaitingInput ||
                            state == GatewayState.evaluating ||
                            state == GatewayState.error)
                        ? Transform.scale(
                            scale: 0.8,
                            child: PasscodeInput(
                              input: _notifier.currentInput,
                              isError: state == GatewayState.error,
                              onDigitPressed: _notifier.appendDigit,
                              onBackspace: _notifier.backspace,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    final state = _notifier.currentState;
    final isRevealing = state == GatewayState.revealingSite || state == GatewayState.complete;
    
    return AnimatedOpacity(
      opacity: isRevealing ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: isRevealing ? const DashboardScreen(animate: true) : const SizedBox.shrink(),
    );
  }
}

class _DoorMaskClipper extends CustomClipper<Path> {
  final double zoom;

  _DoorMaskClipper({this.zoom = 0.0});

  @override
  Path getClip(Size size) {
    Path path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    double baseWidth = 300;
    double baseHeight = 500;
    double scale = 1.0 + (4.0 * zoom);
    
    double doorWidth = baseWidth * scale;
    double doorHeight = baseHeight * scale;
    
    Rect doorRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: doorWidth - (10 * scale),
      height: doorHeight - (10 * scale),
    );
    
    Path hole = Path()..addRRect(RRect.fromRectAndRadius(doorRect, Radius.circular(8 * scale)));
    
    return Path.combine(PathOperation.difference, path, hole);
  }

  @override
  bool shouldReclip(_DoorMaskClipper oldClipper) => oldClipper.zoom != zoom;
}
