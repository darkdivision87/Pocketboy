#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#endif

/// NPCs, side quests, signs and the main story steps of Phase 1. Later phases append to these lists.
enum LanternVillage {
    static func npc(_ id: String, _ name: String, _ hair: Int, _ cloth: Int, _ lines: [String]) -> LanternNPC {
        var n = LanternNPC(id: id, name: name)
        n.hair = hair
        n.cloth = cloth
        n.lines = lines
        return n
    }

    static func questNpc(_ id: String, _ name: String, _ hair: Int, _ cloth: Int, _ quest: String) -> LanternNPC {
        var n = LanternNPC(id: id, name: name)
        n.hair = hair
        n.cloth = cloth
        n.quest = quest
        return n
    }

    static func npcs() -> [LanternNPC] {
        var l: [LanternNPC] = []

        var elder = npc("elder", "ELDER MAPLE", LanternC.grayL, LanternC.purple, ["Hello, hero!"])
        elder.talk = { g in
            if !g.hasItem("sword") {
                return ["Ah, you are up! Before anything else, fetch your sword from the chest in your house. Then come back and see me."]
            }
            if !g.save.flag(LanternFlag.metElder) {
                g.save.setFlag(LanternFlag.metElder)
                g.giveReward("item:lantern", announce: true)
                return ["The great Lantern is dark, and its six Sparks flew away. Take my old hand lantern, it was a gift from the first lamplighter.",
                        "Press SELECT to choose your B item, then B to use it. Flames burn thorns and light torches. Try it on the thorny hedge north of the meadow!"]
            }
            let n = g.save.sparkCount()
            if n == 0 {
                return ["Burn the thorns north of the meadow and enter the Whispering Forest. The first Spark hides in the Hollow Oak."]
            }
            if n == 1 {
                return ["The first Spark glows again! Wonderful! Bombs can open cracked walls, try the rocks east of the meadow to find Sandy Dunes."]
            }
            return ["Two Sparks are home! The lantern flickers a little. The other four gates still sleep, but more of the valley will open soon. Keep exploring and helping folks!"]
        }
        l.append(elder)

        l.append(npc("shopkeeper", "PENNY", LanternC.orange, LanternC.pink, ["Welcome to Penny's Pocket Shop! Everything is shiny and nothing is cursed. Probably. Face the shelf and press A to buy."]))

        var smith = npc("smith", "TINKA THE SMITH", LanternC.brown, LanternC.red, ["Clang!"])
        smith.talk = { g in
            let lv = g.itemLevel("sword")
            if lv >= 3 { return ["Your sword is the sharpest in the valley! I can see my own face in it. Not a good face, but still."] }
            if lv < 2 { return ["I only sharpen swords that already got a little bit stronger. Help Captain Pip with the blobbos and come back!"] }
            if g.save.gems >= 100 {
                g.save.gems -= 100
                g.giveReward("item:sword", announce: true)
                return ["Hammer time! Clang clang CLANG!"]
            }
            return ["A master edge costs 100 gems. Cut some grass and smash some pots, then come back!"]
        }
        l.append(smith)

        l.append(questNpc("hazel", "FARMER HAZEL", LanternC.orange, LanternC.lime, "chicks"))
        l.append(questNpc("basil", "COOK BASIL", LanternC.brown, LanternC.white, "mushrooms"))
        l.append(questNpc("captain", "CAPTAIN PIP", LanternC.grayD, LanternC.blue, "slimes"))
        l.append(questNpc("sandy", "SANDY", LanternC.gold, LanternC.cyan, "shells"))
        l.append(questNpc("finn", "OLD FINN", LanternC.grayL, LanternC.blue, "lure"))
        l.append(questNpc("frosty", "FROSTY", LanternC.white, LanternC.cyan, "scarf"))

        l.append(npc("mira", "MIRA", LanternC.red, LanternC.pink, ["I tried to teach my chicken to fly. Now it teaches ME to run."]))
        l.append(npc("bobo", "BOBO", LanternC.brown, LanternC.orange, ["Pots are full of hearts! Smash them when you feel sad. The pots, I mean. Not you."]))
        l.append(npc("wanda", "WANDA", LanternC.grayL, LanternC.purple, ["I lost my glasses! Oh wait, they are on my head. Thank you for listening!"]))
        l.append(npc("biscuit", "BISCUIT THE CAT", LanternC.orange, LanternC.orange, ["MEOW. (That means: you have a very nice lantern, now go catch me a Spark.)"]))
        l.append(npc("gus", "GUS", LanternC.brown, LanternC.tunic, ["I chop trees. The trees chop back. Mostly with leaves."]))
        l.append(npc("dusty", "DUSTY", LanternC.gold, LanternC.red, ["Sand in my shoes, sand in my hat, sand in my sandwich. I love it here!"]))
        l.append(npc("marla", "MARLA", LanternC.grayD, LanternC.orange, ["Cracked walls sound hollow. Tap, tap... boom! Bring a bomb and see what hides inside."]))
        l.append(npc("ripple", "RIPPLE", LanternC.cyan, LanternC.blue, ["The lake is called Mirror Lake because it shows how silly my hat looks."]))
        l.append(npc("moss", "MOSS", LanternC.lime, LanternC.tunic, ["This marsh is misty. Or maybe my glasses are fogged. Either way, I cannot see my feet."]))
        l.append(npc("ember", "EMBER", LanternC.red, LanternC.gold, ["It is hot here! I would offer you a marshmallow, but they all got toasted."]))
        return l
    }

    static func quest(_ id: String, _ num: Int, _ name: String, _ goal: Int, _ kind: Int, _ kill: String, _ reward: String, _ icon: Int,
                      _ area: Int, _ gx: Int, _ gy: Int, _ hint: String,
                      _ offer: [String], _ progress: [String], _ done: [String], _ after: [String]) -> LanternQuestDef {
        return LanternQuestDef(id: id, num: num, name: name, goal: goal, kind: kind, killId: kill, reward: reward,
                               offer: offer, progress: progress, done: done, after: after, hint: hint,
                               areaNum: area, gx: gx, gy: gy, icon: icon)
    }

    static func quests() -> [LanternQuestDef] {
        var q: [LanternQuestDef] = []
        q.append(quest("chicks", 0, "LOST CHICKS", 3, 0, "", "gems:40", 0, 0, 2, 7, "Find 3 lost chicks in the meadow.",
                       ["Oh dear, my three chicks ran off again! They are small, yellow and very bouncy. Could you find them in the meadow?"],
                       ["Peep? Not all three are here yet. Keep looking around the meadow!"],
                       ["Peep peep peep! All three chicks! Here, a few gems for your trouble."],
                       ["The chicks are asleep in a pile. Thank you again, hero!"]))
        q.append(quest("mushrooms", 1, "MUSHROOM SOUP", 3, 0, "", "gems:30", 2, 0, 3, 4, "Pick 3 red mushrooms in the Whispering Forest.",
                       ["My soup needs three red mushrooms, and they only grow in the Whispering Forest. Do not eat them raw, they taste like socks!"],
                       ["Still need more red mushrooms for the soup. Look around the Whispering Forest!"],
                       ["Perfect mushrooms! The soup will be delicious. Here are some gems."],
                       ["Slurp! Best soup in the valley. Hehe, only soup in the valley."]))
        q.append(quest("slimes", 2, "BLOBBO TROUBLE", 8, 1, "blobbo", "item:sword", 0, 0, 3, 6, "Defeat 8 blobbos around the valley.",
                       ["Those wobbly blobbos are bouncing all over the place! Defeat eight of them and I will have Tinka sharpen your sword."],
                       ["Keep bopping blobbos! They puff into sparkles, so it is perfectly polite."],
                       ["Eight blobbos bopped! Here is a sharper sword, courtesy of the Guard."],
                       ["The blobbos are much calmer now. Thank you, hero!"]))
        q.append(quest("shells", 3, "SHINY SHELLS", 3, 0, "", "item:boots", 1, 0, 6, 6, "Find 3 shiny shells in Sandy Dunes.",
                       ["I am building the world's best sand castle but I need three shiny shells. They are hiding somewhere in the dunes. Please?"],
                       ["Not enough shells yet. They sparkle in the sand!"],
                       ["Look at them sparkle! The castle will be perfect. Take these dash boots, they are too fast for sand castles."],
                       ["The castle is magnificent. Do not step on the moat."]))
        q.append(quest("lure", 4, "LUCKY LURE", 1, 0, "", "piece", 3, 0, 2, 3, "Find Finn's lucky lure in the Misty Marsh.",
                       ["I lost my lucky lure in the Misty Marsh. Without it the fish just laugh at me. Could you find it?"],
                       ["The lure is somewhere in the Misty Marsh. Look for a shiny chest!"],
                       ["My lucky lure! The fish will not laugh now. Here, I found this heart piece in my fishing bucket."],
                       ["The fish are biting! Mostly my fingers, but still."]))
        q.append(quest("scarf", 5, "WARM SCARF", 1, 0, "", "gems:60", 4, 0, 3, 1, "Bring Frosty his scarf from Stone Hills.",
                       ["Brrr! I am a snowman and I am cold. I know, that is silly. My scarf blew away to the Stone Hills. Could you fetch it?"],
                       ["My scarf is in the Stone Hills, far to the east. Please hurry, I am melting. Not really."],
                       ["My scarf! Cozy at last. Here are some gems I found in the snow."],
                       ["Toasty warm! Well, snowman warm."]))
        return q
    }

    static func texts() -> [String: [String]] {
        var t: [String: [String]] = [:]
        t["village"] = ["WELCOME TO DAWNBROOK, HOME OF THE GREAT LANTERN. CURRENTLY OUT OF ORDER. PLEASE BE PATIENT."]
        t["forestsign"] = ["WHISPERING FOREST. PLEASE KEEP YOUR WHISPERS DOWN. THE TREES ARE SLEEPING."]
        t["dunesign"] = ["SANDY DUNES. WATCH FOR MOLES, THEY POP UP WITHOUT ASKING."]
        t["lakesign"] = ["MIRROR LAKE. NO SWIMMING UNTIL YOUR REFLECTION AGREES."]
        t["marshsign"] = ["MISTY MARSH. FOLLOW THE PATH OR THE PATH FOLLOWS YOU."]
        t["frostsign"] = ["FROST PEAKS. WE ARE NOT RESPONSIBLE FOR FROZEN NOSES."]
        t["cratersign"] = ["EMBER CRATER. HOT SPOTS AHEAD. THIS IS NOT A JOKE. OK IT IS A LITTLE BIT OF A JOKE."]
        t["hillsign"] = ["STONE HILLS. HIDDEN CAVES AHEAD. BRING A BOMB AND GOOD MANNERS."]
        t["d1sign"] = ["HOLLOW OAK. PUSH BLOCKS ONTO SWITCHES. YES, YOU CAN PUSH."]
        return t
    }

    static func step(_ hint: String, _ gx: Int, _ gy: Int, _ kind: Int, _ arg: Int) -> LanternStep {
        return LanternStep(hint: hint, areaNum: 0, gx: gx, gy: gy, condKind: kind, condArg: arg)
    }

    static func story() -> [LanternStep] {
        return [
            step("Open the chest in your house and take your sword. Face it and press A.", 3, 7, 2, 0),
            step("Visit Elder Maple, in the house on the right of the village, to get a lantern.", 3, 7, 2, 6),
            step("Use the lantern (B) to burn the thorny hedge north of the meadow, then enter the Whispering Forest.", 3, 6, 0, LanternFlag.enteredForest),
            step("Find the Hollow Oak entrance in the Whispering Forest. Win the first Spark!", 4, 4, 1, 1),
            step("Bombs open cracked walls. Blow up the cracked rocks east of the meadow, then find the Sunken Sandhouse in Sandy Dunes.", 7, 5, 1, 2)
        ]
    }
}
