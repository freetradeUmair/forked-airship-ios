/* Copyright Airship and Contributors */

/// - Note: For internal use only. :nodoc:
public final class AirshipColorUtils {
    private class func normalizeColorString(_ hexString: String) -> String {
        var string = hexString.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        if string.hasPrefix("#") {
            let start = string.index(string.startIndex, offsetBy: 1)
            let range = start..<string.endIndex
            string = String(string[range])
        }
        return string
    }

    private class func parseComponent(_ component: UInt64) -> CGFloat {
        return CGFloat(component) / 255.0
    }

    public class func color(_ hexString: String) -> UIColor? {
        let string = normalizeColorString(hexString)

        let width = 8 * (string.count / 2)

        guard width == 32 || width == 24 else {
            AirshipLogger.error(
                "Invalid hex color string: \(string) (must be 24 or 32 bits wide)"
            )
            return nil
        }

        var component: UInt64 = 0
        let scanner = Scanner(string: string)
        guard scanner.scanHexInt64(&component) else {
            AirshipLogger.error("Unable to scan hexString: \(string)")
            return nil
        }

        let red: CGFloat = parseComponent((component & 0xFF0000) >> 16)
        let green: CGFloat = parseComponent((component & 0xFF00) >> 8)
        let blue: CGFloat = parseComponent((component & 0xFF))

        let alpha: CGFloat = width == 24 ? 1.0 : parseComponent((component & 0xFF00_0000) >> 24)

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public class func hexString(_ color: UIColor) -> String? {
        var red = 0.0 as CGFloat
        var green = 0.0 as CGFloat
        var blue = 0.0 as CGFloat
        var alpha = 0.0 as CGFloat

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(255.0 * red)
        let g = Int(255.0 * green)
        let b = Int(255.0 * blue)
        let a = Int(255.0 * alpha)

        return String(format: "#%02x%02x%02x%02x", a, r, g, b)
    }
}
