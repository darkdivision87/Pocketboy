/// Turns raw `PointerState` into the gestures kids actually use: tap, long-press and swipe.
/// Keep one `TouchGesture` in your game, call `update(input.pointer)` once per frame, then read its flags (valid for that frame only).
public struct TouchGesture {
    /// True on the frame the finger lifts after a quick touch that barely moved.
    public private(set) var tapped = false
    /// True once, when a still finger has been held for about 0.45 s.
    public private(set) var longPressed = false
    /// 1 up, 2 down, 4 left, 8 right on the frame a swipe is recognised (0 otherwise). Chained swipes within one touch are allowed.
    public private(set) var swipe: Int = 0
    /// Current finger position (last known) and whether the finger is down.
    public private(set) var x = 0
    public private(set) var y = 0
    public private(set) var down = false
    /// True on the first frame of a touch.
    public private(set) var began = false
    /// Where this touch started, total movement since then, and frames held.
    public private(set) var startX = 0
    public private(set) var startY = 0
    public private(set) var dx = 0
    public private(set) var dy = 0
    public private(set) var frames = 0

    private var originX = 0
    private var originY = 0
    private var moved = false
    private var swiped = false
    private var longDone = false
    private var active = false

    public init() {}

    public mutating func update(_ p: PointerState, swipeDistance: Int = 12) {
        tapped = false
        longPressed = false
        swipe = 0
        began = false
        down = p.down
        if p.x >= 0 && p.y >= 0 {
            x = p.x
            y = p.y
        }
        if p.pressed {
            startX = x
            startY = y
            originX = x
            originY = y
            dx = 0
            dy = 0
            frames = 0
            moved = false
            swiped = false
            longDone = false
            active = true
            began = true
        }
        if active && p.down {
            frames += 1
            dx = x - startX
            dy = y - startY
            if abs(dx) > 5 || abs(dy) > 5 { moved = true }
            let sx = x - originX
            let sy = y - originY
            if abs(sx) >= swipeDistance || abs(sy) >= swipeDistance {
                if abs(sx) >= abs(sy) {
                    swipe = sx > 0 ? 8 : 4
                } else {
                    swipe = sy > 0 ? 2 : 1
                }
                originX = x
                originY = y
                swiped = true
            }
            if !moved && !longDone && frames >= 27 {
                longPressed = true
                longDone = true
            }
        }
        if p.released && active {
            if !moved && !longDone && !swiped && frames <= 20 { tapped = true }
            active = false
        }
    }
}
