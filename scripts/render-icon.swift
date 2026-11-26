import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fail("Usage: swift scripts/render-icon.swift SOURCE.svg OUTPUT.png|OUTPUT.icns")
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let icon = NSImage(contentsOf: source) else { fail("Could not load \(source.path).") }

let data: Data
switch output.pathExtension.lowercased() {
case "png":
    data = renderPNG(icon, size: 1024)
case "icns":
    data = renderIconFamily(icon)
default:
    fail("The output file must end with .png or .icns.")
}

try data.write(to: output, options: .atomic)

func renderPNG(_ icon: NSImage, size: Int) -> Data {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let bitmap = CGContext(
              data: nil,
              width: size,
              height: size,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        fail("Could not allocate the \(size) × \(size) image.")
    }

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    bitmap.clear(bounds)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
    icon.draw(in: bounds)
    NSGraphicsContext.restoreGraphicsState()

    let data = NSMutableData()
    guard let image = bitmap.makeImage(),
          let png = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        fail("Could not create the PNG.")
    }
    CGImageDestinationAddImage(png, image, nil)
    guard CGImageDestinationFinalize(png) else { fail("Could not encode the PNG.") }
    return data as Data
}

func renderIconFamily(_ icon: NSImage) -> Data {
    // The 1× and 2× representations cover 16, 32, 128, 256, and 512 points.
    let representations = [
        ("icp4", 16), ("ic11", 32), ("icp5", 32), ("ic12", 64), ("ic07", 128),
        ("ic13", 256), ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024),
    ]
    var family = Data()
    for (type, size) in representations {
        family.append(iconChunk(type: type, payload: renderPNG(icon, size: size)))
    }
    return iconChunk(type: "icns", payload: family)
}

func iconChunk(type: String, payload: Data) -> Data {
    // An ICNS chunk stores its four-byte type and total length before its payload.
    var length = UInt32(8 + payload.count).bigEndian
    var chunk = Data(type.utf8)
    withUnsafeBytes(of: &length) { chunk.append(contentsOf: $0) }
    chunk.append(payload)
    return chunk
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
