import SwiftUI

/// A hand-picked subset of Central Icons (centralicons.com) — replacing the
/// SF Symbols and hand-drawn glyphs scattered through the history window
/// with one consistent icon family, per direct request. Each raw SVG
/// fragment below was pulled from the `round-outlined-radius-3-stroke-2`
/// style (24×24 grid, 2pt stroke, the largest of Central Icons' four corner
/// options, per direct request) so every icon shares the same weight. Only
/// individual icon fragments are copied here, not the asset library itself
/// — well within Iconists' license, which caps at 300 icons per style per
/// end product and explicitly forbids bundling "the complete Asset."
enum CentralIcons {
    static let search = #"<path d="M11 18C14.866 18 18 14.866 18 11C18 7.13401 14.866 4 11 4C7.13401 4 4 7.13401 4 11C4 14.866 7.13401 18 11 18Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M20 20L16.05 16.05" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let settingsGear = #"<path d="M10.53 3.82729C11.4432 3.31361 12.5583 3.31361 13.4715 3.82729L18.4716 6.63977C19.4162 7.17112 20.0008 8.17067 20.0008 9.2545L20.0008 14.7454C20.0008 15.8292 19.4162 16.8288 18.4715 17.3601L13.4715 20.1726C12.5583 20.6863 11.4432 20.6863 10.53 20.1726L5.53008 17.3604C4.58539 16.8291 4.00077 15.8295 4.00077 14.7456L4.00077 9.25448C4.00077 8.17065 4.58536 7.17109 5.53 6.63974L10.53 3.82729Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M12 15C13.6569 15 15 13.6569 15 12C15 10.3431 13.6569 9 12 9C10.3431 9 9 10.3431 9 12C9 13.6569 10.3431 15 12 15Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let arrowUpRight = #"<path d="M18 15V6M18 6H9M18 6L6.25 17.75" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let checkCircle = #"<path d="M15 9.5L10.5 15L8.5 13M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let circle = #"<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/>"#

    static let exclamationCircle = #"<circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2"/><path d="M12 8V12.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="15.7996" r="1.2" fill="currentColor"/>"#

    static let trash = #"<path d="M5 6.5L5.80734 18.2064C5.91582 19.7794 7.22348 21 8.80023 21H15.1998C16.7765 21 18.0842 19.7794 18.1927 18.2064L19 6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M3.5 6H20.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M8.07092 5.74621C8.42348 3.89745 10.0485 2.5 12 2.5C13.9515 2.5 15.5765 3.89745 15.9291 5.74621" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let copy = #"<path d="M15 9V5.25C15 4.00736 13.9926 3 12.75 3H5.25C4.00736 3 3 4.00736 3 5.25V12.75C3 13.9926 4.00736 15 5.25 15H9M11.25 9H18.75C19.9926 9 21 10.0074 21 11.25V18.75C21 19.9926 19.9926 21 18.75 21H11.25C10.0074 21 9 19.9926 9 18.75V11.25C9 10.0074 10.0074 9 11.25 9Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let finder = #"<path d="M13.25 13H11.25C11.429 9.92032 11.9121 6.95315 12.6834 4M8 9V10M16 9V10M8 15.5C11 17.5 13 17.5 16 15.5M12.6834 4H7C5.34315 4 4 5.34315 4 7V17C4 18.6569 5.34315 20 7 20H17C18.6569 20 20 18.6569 20 17V7C20 5.34315 18.6569 4 17 4H12.6834Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let chevronDown = #"<path d="M8 10L10.9393 12.9393C11.5251 13.5251 12.4749 13.5251 13.0607 12.9393L16 10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let grid = #"<path d="M8.5 4V20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M15.5 4V20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M4 8.5H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M4 15.5H20" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let fileText = #"<path d="M12.1716 3H8C6.34315 3 5 4.34315 5 6V18C5 19.6569 6.34315 21 8 21H16C17.6569 21 19 19.6569 19 18V9.82843C19 9.29799 18.7893 8.78929 18.4142 8.41421L13.5858 3.58579C13.2107 3.21071 12.702 3 12.1716 3Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M13 3.5V7C13 8.10457 13.8954 9 15 9H18.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 13H12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 17H15.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let settingsSlider = #"<path d="M15 10C16.6575 10 18 8.6575 18 7C18 5.3425 16.6575 4 15 4C13.3425 4 12 5.3425 12 7C12 8.6575 13.3425 10 15 10Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M12 7H4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M20 7H18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M9 20C10.6575 20 12 18.6575 12 17C12 15.3425 10.6575 14 9 14C7.3425 14 6 15.3425 6 17C6 18.6575 7.3425 20 9 20Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M6 17H4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M20 17H12.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let megaphone = #"<path d="M17.9961 14C19.6529 14 20.9961 12.6569 20.9961 11C20.9961 9.34318 19.6529 8.00003 17.9961 8.00003M12.8254 18C12.4136 19.1652 11.3023 20 9.99609 20C8.33924 20 6.99609 18.6569 6.99609 17V15.5M6.99829 6.50003V15.5M17.9961 7.10616V14.8939C17.9961 16.9253 16.0195 18.3694 14.0842 17.752L5.08424 14.8805C3.84044 14.4837 2.99609 13.328 2.99609 12.0225V9.97759C2.99609 8.67203 3.84044 7.51636 5.08424 7.11953L14.0842 4.2481C16.0195 3.63065 17.9961 5.07476 17.9961 7.10616Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let microphone = #"<path d="M12.0013 19V21M12.0013 19C8.32307 19 6.14811 16.7451 5.01562 15M12.0013 19C15.6795 19 17.8545 16.7451 18.987 15M16.0013 7V11C16.0013 13.2091 14.2104 15 12.0013 15C9.79215 15 8.00129 13.2091 8.00129 11V7C8.00129 4.79086 9.79215 3 12.0013 3C14.2104 3 16.0013 4.79086 16.0013 7Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#

    static let stopCircle = #"<path d="M9.5 10.5C9.5 9.94772 9.94772 9.5 10.5 9.5H13.5C14.0523 9.5 14.5 9.94772 14.5 10.5V13.5C14.5 14.0523 14.0523 14.5 13.5 14.5H10.5C9.94772 14.5 9.5 14.0523 9.5 13.5V10.5Z" fill="currentColor"/><path d="M2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12Z" stroke="currentColor" stroke-width="2"/>"#

    static let send = #"<path d="M12.5916 20.8249C13.0032 22.2656 15.0401 22.279 15.4706 20.8438L19.9483 5.91824C20.2915 4.77403 19.2247 3.70722 18.0805 4.05048L3.15492 8.52816C1.7198 8.95869 1.7332 10.9956 3.17385 11.4072L9.69747 13.2711C10.1958 13.4135 10.5853 13.803 10.7277 14.3013L12.5916 20.8249Z" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>"#
}

/// Renders one of the fragments above. Parses the small subset of raw SVG
/// Central Icons actually emits — plain `<path>`/`<circle>` tags, absolute
/// path commands only (`M L H V C Z`) — rather than hand-transcribing curves
/// into `Path` builders by eye, since a couple of these (the trash can's
/// lid) have real bezier segments that are easy to get subtly wrong.
struct CentralIconView: View {
    let svg: String
    var color: Color = .primary

    /// Central Icons' own design grid for this style.
    private let gridSize: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / gridSize
            ZStack {
                ForEach(Array(Self.elements(from: svg).enumerated()), id: \.offset) { _, element in
                    if element.filled {
                        element.path.fill(color)
                    } else {
                        element.path.stroke(color, style: StrokeStyle(
                            lineWidth: 2, lineCap: element.lineCap,
                            lineJoin: element.lineCap == .round ? .round : .miter
                        ))
                    }
                }
            }
            .frame(width: gridSize, height: gridSize, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
        }
    }

    private struct Element {
        let path: Path
        let filled: Bool
        let lineCap: CGLineCap
    }

    private static func elements(from svg: String) -> [Element] {
        let full = svg as NSString
        guard let tagPattern = try? NSRegularExpression(pattern: "<(path|circle)([^/]*)/>") else { return [] }
        let matches = tagPattern.matches(in: svg, range: NSRange(location: 0, length: full.length))

        func attribute(_ name: String, in attrs: String) -> String? {
            guard let range = attrs.range(of: "\(name)=\"") else { return nil }
            let rest = attrs[range.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
        }

        return matches.compactMap { match in
            let tag = full.substring(with: match.range(at: 1))
            let attrs = full.substring(with: match.range(at: 2))
            let filled = (attribute("fill", in: attrs) ?? "none") != "none"
            let lineCap: CGLineCap = attribute("stroke-linecap", in: attrs) == "round" ? .round : .square

            let path: Path
            if tag == "path", let d = attribute("d", in: attrs) {
                path = parsePathData(d)
            } else if tag == "circle",
                      let cx = attribute("cx", in: attrs).flatMap(Double.init),
                      let cy = attribute("cy", in: attrs).flatMap(Double.init),
                      let r = attribute("r", in: attrs).flatMap(Double.init) {
                path = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            } else {
                return nil
            }
            return Element(path: path, filled: filled, lineCap: lineCap)
        }
    }

    /// SVG allows a coordinate pair to repeat the previous command letter
    /// implicitly (`"M8 9V10M16 9V10"` needs no repeated `V`/`M`) — handled
    /// here by only re-reading a command letter when one is actually next,
    /// otherwise reusing whatever command was last seen.
    private static func parsePathData(_ d: String) -> Path {
        var path = Path()
        let scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: ", ")
        let commandLetters = CharacterSet(charactersIn: "MLHVCZ")

        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCommand: Character = "M"

        while !scanner.isAtEnd {
            var command = lastCommand
            if let letters = scanner.scanCharacters(from: commandLetters), let last = letters.last {
                command = last
            }
            switch command {
            case "M":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { return path }
                current = CGPoint(x: x, y: y)
                subpathStart = current
                path.move(to: current)
                lastCommand = "L"
            case "L":
                guard let x = scanner.scanDouble(), let y = scanner.scanDouble() else { return path }
                current = CGPoint(x: x, y: y)
                path.addLine(to: current)
                lastCommand = "L"
            case "H":
                guard let x = scanner.scanDouble() else { return path }
                current = CGPoint(x: x, y: current.y)
                path.addLine(to: current)
                lastCommand = "H"
            case "V":
                guard let y = scanner.scanDouble() else { return path }
                current = CGPoint(x: current.x, y: y)
                path.addLine(to: current)
                lastCommand = "V"
            case "C":
                guard let x1 = scanner.scanDouble(), let y1 = scanner.scanDouble(),
                      let x2 = scanner.scanDouble(), let y2 = scanner.scanDouble(),
                      let x = scanner.scanDouble(), let y = scanner.scanDouble()
                else { return path }
                path.addCurve(to: CGPoint(x: x, y: y),
                               control1: CGPoint(x: x1, y: y1),
                               control2: CGPoint(x: x2, y: y2))
                current = CGPoint(x: x, y: y)
                lastCommand = "C"
            case "Z":
                path.closeSubpath()
                current = subpathStart
                lastCommand = "Z"
            default:
                return path
            }
        }
        return path
    }
}
