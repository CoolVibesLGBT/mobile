import Cocoa
// Host-only integration driver. Public CGEvent input; no screenshots.
let args = CommandLine.arguments.dropFirst().compactMap(Double.init)
guard args.count == 4 || args.count == 6 else { exit(2) }
func event(_ type: CGEventType, _ x: Double, _ y: Double) {
  CGEvent(mouseEventSource: nil, mouseType: type,
    mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cghidEventTap)
}
event(.mouseMoved, args[0], args[1])
event(.leftMouseDown, args[0], args[1])
Thread.sleep(forTimeInterval: 0.1)
if args.count == 6 {
  for step in 1...10 {
    let t = Double(step) / 10
    event(.leftMouseDragged, args[0] + (args[4] - args[0]) * t, args[1] + (args[5] - args[1]) * t)
    Thread.sleep(forTimeInterval: 0.02)
  }
  event(.leftMouseUp, args[4], args[5])
} else {
  event(.leftMouseUp, args[0], args[1])
}
