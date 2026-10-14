import AppKit
import Foundation
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16), ("icon_16x16@2x",32), ("icon_32x32",32), ("icon_32x32@2x",64), ("icon_128x128",128), ("icon_128x128@2x",256), ("icon_256x256",256), ("icon_256x256@2x",512), ("icon_512x512",512), ("icon_512x512@2x",1024)] {
    let s = CGFloat(pixels)
    let image = NSImage(size: NSSize(width:s, height:s))
    image.lockFocus()
    let background = NSBezierPath(roundedRect: NSRect(x:s*0.07, y:s*0.07, width:s*0.86, height:s*0.86), xRadius:s*0.20, yRadius:s*0.20)
    NSGradient(starting: NSColor(srgbRed:0.43, green:0.39, blue:0.98, alpha:1), ending: NSColor(srgbRed:0.23, green:0.24, blue:0.72, alpha:1))!.draw(in:background, angle:-60)
    let frame = NSBezierPath(roundedRect:NSRect(x:s*0.25,y:s*0.25,width:s*0.5,height:s*0.5), xRadius:s*0.055,yRadius:s*0.055)
    NSColor.white.setFill(); frame.fill()
    NSColor(srgbRed:0.35,green:0.33,blue:0.88,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:s*0.29,y:s*0.30,width:s*0.42,height:s*0.32),xRadius:s*0.018,yRadius:s*0.018).fill()
    NSColor(srgbRed:0.28,green:0.85,blue:0.70,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:s*0.58,y:s*0.18,width:s*0.23,height:s*0.23),xRadius:s*0.065,yRadius:s*0.065).fill()
    NSColor.white.setStroke(); let arrow = NSBezierPath(); arrow.lineWidth=s*0.023; arrow.lineCapStyle = .round
    arrow.move(to:NSPoint(x:s*0.64,y:s*0.25)); arrow.line(to:NSPoint(x:s*0.74,y:s*0.35)); arrow.move(to:NSPoint(x:s*0.65,y:s*0.35)); arrow.line(to:NSPoint(x:s*0.74,y:s*0.35)); arrow.line(to:NSPoint(x:s*0.74,y:s*0.26)); arrow.stroke()
    image.unlockFocus()
    let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
    let scaled = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:scaled)
    rep.draw(in:NSRect(x:0,y:0,width:s,height:s)); NSGraphicsContext.restoreGraphicsState()
    try scaled.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name + ".png"))
}
