import HotKey

public let minus = "minus"
public let equal = "equal"

public let q = "q"
public let w = "w"
public let e = "e"
public let r = "r"
public let t = "t"
public let y = "y"
public let u = "u"
public let i = "i"
public let o = "o"
public let p = "p"
public let leftSquareBracket = "leftSquareBracket"
public let rightSquareBracket = "rightSquareBracket"
public let backslash = "backslash"
public let sectionSign = "sectionSign"

public let a = "a"
public let s = "s"
public let d = "d"
public let f = "f"
public let g = "g"
public let h = "h"
public let j = "j"
public let k = "k"
public let l = "l"
public let semicolon = "semicolon"
public let quote = "quote"

public let z = "z"
public let x = "x"
public let c = "c"
public let v = "v"
public let b = "b"
public let n = "n"
public let m = "m"
public let comma = "comma"
public let period = "period"
public let slash = "slash"

public func getKeysPreset(_ layout: KeyMapping.Preset) -> [String: Key] {
    return switch layout {
        case .qwerty: keyNotationToKeyCode
        case .dvorak: dvorakMap
        case .colemak: colemakMap
    }
}

extension Key: @unchecked @retroactive Sendable {}

public let keyNotationToKeyCode: [String: Key] = {
    var result = standardKeyMap
    result = result + keypadKeyMap
    result = result + navigationKeyMap
    result = result + functionKeyMap
    result = result + specialKeyMap
    return result
}()

private let standardKeyMap: [String: Key] = [
    sectionSign: .section,
    "0": .zero,
    "1": .one,
    "2": .two,
    "3": .three,
    "4": .four,
    "5": .five,
    "6": .six,
    "7": .seven,
    "8": .eight,
    "9": .nine,
    minus: .minus,
    equal: .equal,

    q: .q,
    w: .w,
    e: .e,
    r: .r,
    t: .t,
    y: .y,
    u: .u,
    i: .i,
    o: .o,
    p: .p,
    leftSquareBracket: .leftBracket,
    rightSquareBracket: .rightBracket,
    backslash: .backslash,

    a: .a,
    s: .s,
    d: .d,
    f: .f,
    g: .g,
    h: .h,
    j: .j,
    k: .k,
    l: .l,
    semicolon: .semicolon,
    quote: .quote,

    z: .z,
    x: .x,
    c: .c,
    v: .v,
    b: .b,
    n: .n,
    m: .m,
    comma: .comma,
    period: .period,
    slash: .slash,
]

private let keypadKeyMap: [String: Key] = [
    "keypad0": .keypad0,
    "keypad1": .keypad1,
    "keypad2": .keypad2,
    "keypad3": .keypad3,
    "keypad4": .keypad4,
    "keypad5": .keypad5,
    "keypad6": .keypad6,
    "keypad7": .keypad7,
    "keypad8": .keypad8,
    "keypad9": .keypad9,
    "keypadClear": .keypadClear,
    "keypadDecimalMark": .keypadDecimal,
    "keypadDivide": .keypadDivide,
    "keypadEnter": .keypadEnter,
    "keypadEqual": .keypadEquals,
    "keypadMinus": .keypadMinus,
    "keypadMultiply": .keypadMultiply,
    "keypadPlus": .keypadPlus,
]

private let navigationKeyMap: [String: Key] = [
    "pageUp": .pageUp,
    "pageDown": .pageDown,
    "home": .home,
    "end": .end,
    "forwardDelete": .forwardDelete,
    "left": .leftArrow,
    "down": .downArrow,
    "up": .upArrow,
    "right": .rightArrow,
]

private let functionKeyMap: [String: Key] = [
    "f1": .f1,
    "f2": .f2,
    "f3": .f3,
    "f4": .f4,
    "f5": .f5,
    "f6": .f6,
    "f7": .f7,
    "f8": .f8,
    "f9": .f9,
    "f10": .f10,
    "f11": .f11,
    "f12": .f12,
    "f13": .f13,
    "f14": .f14,
    "f15": .f15,
    "f16": .f16,
    "f17": .f17,
    "f18": .f18,
    "f19": .f19,
    "f20": .f20,
]

private let specialKeyMap: [String: Key] = [
    "backtick": .grave,
    "space": .space,
    "enter": .return,
    "esc": .escape,
    "backspace": .delete,
    "tab": .tab,
]
