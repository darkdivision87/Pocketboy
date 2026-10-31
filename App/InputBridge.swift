import Foundation
import GameController
import PocketCore

/// Maps hardware game controllers and keyboards onto the Game Boy buttons.
final class InputBridge {
    private weak var hub: Hub?
    private var keysHeld: Buttons = []

    private let keyMap: [(GCKeyCode, Buttons)] = [
        (.leftArrow, .left), (.rightArrow, .right), (.upArrow, .up), (.downArrow, .down),
        (.keyA, .left), (.keyD, .right), (.keyW, .up), (.keyS, .down),
        (.keyX, .a), (.keyZ, .b), (.spacebar, .a),
        (.returnOrEnter, .start), (.rightShift, .select), (.tab, .select)
    ]

    init(hub: Hub) {
        self.hub = hub
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(controllerConnected(_:)), name: .GCControllerDidConnect, object: nil)
        center.addObserver(self, selector: #selector(keyboardConnected(_:)), name: .GCKeyboardDidConnect, object: nil)
        for controller in GCController.controllers() { configure(controller) }
        if let keyboard = GCKeyboard.coalesced { configure(keyboard) }
    }

    @objc private func controllerConnected(_ note: Notification) {
        if let controller = note.object as? GCController { configure(controller) }
    }

    @objc private func keyboardConnected(_ note: Notification) {
        if let keyboard = note.object as? GCKeyboard { configure(keyboard) }
    }

    private func configure(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        pad.valueChangedHandler = { [weak self] gamepad, _ in
            var b: Buttons = []
            if gamepad.dpad.left.isPressed || gamepad.leftThumbstick.xAxis.value < -0.5 { b.insert(.left) }
            if gamepad.dpad.right.isPressed || gamepad.leftThumbstick.xAxis.value > 0.5 { b.insert(.right) }
            if gamepad.dpad.up.isPressed || gamepad.leftThumbstick.yAxis.value > 0.5 { b.insert(.up) }
            if gamepad.dpad.down.isPressed || gamepad.leftThumbstick.yAxis.value < -0.5 { b.insert(.down) }
            // Face buttons: the right-hand button is A, the bottom one is B (Game Boy layout).
            if gamepad.buttonB.isPressed || gamepad.buttonY.isPressed { b.insert(.a) }
            if gamepad.buttonA.isPressed || gamepad.buttonX.isPressed { b.insert(.b) }
            if gamepad.buttonMenu.isPressed { b.insert(.start) }
            if let options = gamepad.buttonOptions, options.isPressed { b.insert(.select) }
            self?.hub?.set(b, from: .pad)
        }
    }

    private func configure(_ keyboard: GCKeyboard) {
        guard let input = keyboard.keyboardInput else { return }
        input.keyChangedHandler = { [weak self] _, _, keyCode, pressed in
            guard let self = self else { return }
            for (code, button) in self.keyMap where code == keyCode {
                if pressed { self.keysHeld.insert(button) } else { self.keysHeld.remove(button) }
            }
            self.hub?.set(self.keysHeld, from: .keys)
        }
    }
}
