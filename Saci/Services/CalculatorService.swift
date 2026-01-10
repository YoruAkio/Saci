//
//  CalculatorService.swift
//  Saci
//

import Foundation

// @note result types for calculator
enum CalculatorResultType {
    case number      // basic arithmetic (+, -, *, /)
    case percentage  // percentage calculations
    case date        // date calculations
    case time        // timezone conversions
    case unit        // unit conversions
    case power       // power/exponent expressions
    case squareRoot  // square root, cube root
}

// @note calculator result model
struct CalculatorResult {
    let type: CalculatorResultType
    let expression: String
    let result: String
    let subtitle: String
    let icon: String
    
    // @note formatted result for clipboard
    var copyValue: String {
        result
    }
}

// @note service to evaluate math expressions, unit conversions, and date calculations
class CalculatorService {
    static let shared = CalculatorService()
    
    private init() {}
    
    // @note try to evaluate input as calculator expression
    // @param input user input string
    // @return CalculatorResult if valid expression, nil otherwise
    func evaluate(_ input: String) -> CalculatorResult? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        // @note try each parser in order of specificity
        if let result = tryPercentageOf(trimmed) { return result }
        if let result = tryUnitConversion(trimmed) { return result }
        if let result = tryDateCalculation(trimmed) { return result }
        if let result = tryTimeConversion(trimmed) { return result }
        if let result = tryMathExpression(trimmed) { return result }
        
        return nil
    }
    
    // MARK: - Math Expression Parser
    
    // @note evaluate basic math expression
    // @param input expression like "23 + 456", "2^10", "sqrt(144)"
    private func tryMathExpression(_ input: String) -> CalculatorResult? {
        var expr = input
        
        // @note handle sqrt() function
        expr = expr.replacingOccurrences(of: "sqrt(", with: "√(")
        if let result = evaluateSqrt(expr) {
            return result
        }
        
        // @note handle power expressions (2^10, 4^3)
        if expr.contains("^") {
            if let result = evaluatePower(expr) {
                return result
            }
        }
        
        // @note try NSExpression for basic arithmetic
        // @note replace × and ÷ and x with * and /
        expr = input
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .replacingOccurrences(of: " ", with: "")
        
        // @note validate expression contains operators
        let hasOperator = expr.contains("+") || expr.contains("-") || 
                          expr.contains("*") || expr.contains("/") ||
                          expr.contains("^")
        
        // @note check if it looks like a math expression
        guard hasOperator || expr.contains("(") else { return nil }
        
        // @note handle power before NSExpression
        if expr.contains("^") {
            if let result = evaluatePower(input) {
                return result
            }
        }
        
        // @note try to evaluate with NSExpression safely
        // @note validate characters first
        let validChars = CharacterSet(charactersIn: "0123456789.+-*/() ")
        guard expr.unicodeScalars.allSatisfy({ validChars.contains($0) }) else {
            return nil
        }
        
        // @note ensure balanced parentheses
        var parenCount = 0
        for char in expr {
            if char == "(" { parenCount += 1 }
            if char == ")" { parenCount -= 1 }
            if parenCount < 0 { return nil }
        }
        guard parenCount == 0 else { return nil }
        
        // @note evaluate expression
        guard let value = evaluateSimpleExpression(expr) else {
            return nil
        }
        
        let formatted = formatNumber(value)
        
        return CalculatorResult(
            type: .number,
            expression: input,
            result: formatted,
            subtitle: "Basic arithmetic",
            icon: "equal.circle.fill"
        )
    }
    
    // @note simple expression evaluator for basic arithmetic
    // @param expr expression like "2*2", "10+5", "100/4"
    private func evaluateSimpleExpression(_ expr: String) -> Double? {
        // @note check if expression ends with operator (incomplete)
        let lastChar = expr.last
        if lastChar == "+" || lastChar == "-" || lastChar == "*" || lastChar == "/" {
            return nil
        }
        
        // @note check if expression starts with operator (invalid)
        let firstChar = expr.first
        if firstChar == "+" || firstChar == "*" || firstChar == "/" {
            return nil
        }
        
        // @note try to parse and evaluate using Decimal for better precision
        if let result = evaluateWithDecimal(expr) {
            return (result as NSDecimalNumber).doubleValue
        }
        
        // @note fallback to NSExpression for complex expressions
        let nsExpr = NSExpression(format: expr)
        if let value = nsExpr.expressionValue(with: nil, context: nil) as? NSNumber {
            return value.doubleValue
        }
        return nil
    }
    
    // @note evaluate expression using Decimal for better precision
    // @param expr expression string
    private func evaluateWithDecimal(_ expr: String) -> Decimal? {
        // @note simple tokenizer for basic operations
        var tokens: [String] = []
        var currentNumber = ""
        
        for char in expr {
            if char.isNumber || char == "." {
                currentNumber.append(char)
            } else if "+-*/".contains(char) {
                if !currentNumber.isEmpty {
                    tokens.append(currentNumber)
                    currentNumber = ""
                }
                tokens.append(String(char))
            }
        }
        if !currentNumber.isEmpty {
            tokens.append(currentNumber)
        }
        
        // @note need at least one number
        guard !tokens.isEmpty else { return nil }
        
        // @note handle multiplication and division first
        var i = 0
        while i < tokens.count {
            if tokens[i] == "*" || tokens[i] == "/" {
                guard i > 0, i < tokens.count - 1,
                      let left = Decimal(string: tokens[i-1]),
                      let right = Decimal(string: tokens[i+1]) else {
                    return nil
                }
                
                let result: Decimal
                if tokens[i] == "*" {
                    result = left * right
                } else {
                    if right == 0 { return nil }
                    result = left / right
                }
                
                tokens[i-1] = "\(result)"
                tokens.remove(at: i)
                tokens.remove(at: i)
                i = max(0, i - 1)
            } else {
                i += 1
            }
        }
        
        // @note handle addition and subtraction
        i = 0
        while i < tokens.count {
            if tokens[i] == "+" || tokens[i] == "-" {
                guard i > 0, i < tokens.count - 1,
                      let left = Decimal(string: tokens[i-1]),
                      let right = Decimal(string: tokens[i+1]) else {
                    return nil
                }
                
                let result: Decimal
                if tokens[i] == "+" {
                    result = left + right
                } else {
                    result = left - right
                }
                
                tokens[i-1] = "\(result)"
                tokens.remove(at: i)
                tokens.remove(at: i)
                i = max(0, i - 1)
            } else {
                i += 1
            }
        }
        
        // @note should have single result
        guard tokens.count == 1, let result = Decimal(string: tokens[0]) else {
            return nil
        }
        
        return result
    }
    
    // @note evaluate sqrt expressions
    // @param input expression containing √ or sqrt
    private func evaluateSqrt(_ input: String) -> CalculatorResult? {
        // @note match sqrt(number) or √(number) or √number
        let patterns = [
            "√\\(([\\d.]+)\\)",
            "√([\\d.]+)",
            "sqrt\\(([\\d.]+)\\)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
               let numberRange = Range(match.range(at: 1), in: input),
               let number = Double(String(input[numberRange])) {
                
                let result = sqrt(number)
                let formatted = formatNumber(result)
                
                return CalculatorResult(
                    type: .squareRoot,
                    expression: input,
                    result: formatted,
                    subtitle: "Square root of \(formatNumber(number))",
                    icon: "x.squareroot"
                )
            }
        }
        
        return nil
    }
    
    // @note evaluate power expressions
    // @param input expression like "2^10" or "625^(1/2)"
    private func evaluatePower(_ input: String) -> CalculatorResult? {
        let expr = input.replacingOccurrences(of: " ", with: "")
        
        // @note match base^exponent patterns
        // @note handle fractional exponents like 625^(1/2)
        if let regex = try? NSRegularExpression(pattern: "^([\\d.]+)\\^\\(?(\\d+)(?:/(\\d+))?\\)?$"),
           let match = regex.firstMatch(in: expr, range: NSRange(expr.startIndex..., in: expr)),
           let baseRange = Range(match.range(at: 1), in: expr),
           let expNumRange = Range(match.range(at: 2), in: expr),
           let base = Double(String(expr[baseRange])),
           let expNum = Double(String(expr[expNumRange])) {
            
            var exponent = expNum
            
            // @note check for fractional exponent
            if match.range(at: 3).location != NSNotFound,
               let expDenRange = Range(match.range(at: 3), in: expr),
               let expDen = Double(String(expr[expDenRange])), expDen != 0 {
                exponent = expNum / expDen
            }
            
            let result = pow(base, exponent)
            let formatted = formatNumber(result)
            
            var subtitle = "\(formatNumber(base)) to the power of \(formatNumber(exponent))"
            var resultType: CalculatorResultType = .power
            
            if exponent == 0.5 {
                subtitle = "Square root of \(formatNumber(base))"
                resultType = .squareRoot
            } else if exponent == 1.0/3.0 {
                subtitle = "Cube root of \(formatNumber(base))"
                resultType = .squareRoot
            }
            
            return CalculatorResult(
                type: resultType,
                expression: input,
                result: formatted,
                subtitle: subtitle,
                icon: "chevron.up.2"
            )
        }
        
        return nil
    }
    
    // MARK: - Percentage Parser
    
    // @note evaluate percentage expressions
    // @param input expression like "15% of 200" or "100 * 1.08"
    private func tryPercentageOf(_ input: String) -> CalculatorResult? {
        let lowercased = input.lowercased()
        
        // @note match "X% of Y" pattern
        if let regex = try? NSRegularExpression(pattern: "([\\d.]+)\\s*%\\s*of\\s*([\\d.]+)", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let percentRange = Range(match.range(at: 1), in: lowercased),
           let valueRange = Range(match.range(at: 2), in: lowercased),
           let percent = Double(String(lowercased[percentRange])),
           let value = Double(String(lowercased[valueRange])) {
            
            let result = (percent / 100.0) * value
            let formatted = formatNumber(result)
            
            return CalculatorResult(
                type: .percentage,
                expression: input,
                result: formatted,
                subtitle: "\(formatNumber(percent))% of \(formatNumber(value))",
                icon: "percent"
            )
        }
        
        // @note match "X + Y%" or "X - Y%" (percentage increase/decrease)
        if let regex = try? NSRegularExpression(pattern: "([\\d.]+)\\s*([+-])\\s*([\\d.]+)\\s*%", options: .caseInsensitive),
           let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           let valueRange = Range(match.range(at: 1), in: input),
           let opRange = Range(match.range(at: 2), in: input),
           let percentRange = Range(match.range(at: 3), in: input),
           let value = Double(String(input[valueRange])),
           let percent = Double(String(input[percentRange])) {
            
            let op = String(input[opRange])
            let percentValue = (percent / 100.0) * value
            let result = op == "+" ? value + percentValue : value - percentValue
            let formatted = formatNumber(result)
            
            let subtitle = op == "+" 
                ? "\(formatNumber(value)) plus \(formatNumber(percent))%"
                : "\(formatNumber(value)) minus \(formatNumber(percent))%"
            
            return CalculatorResult(
                type: .percentage,
                expression: input,
                result: formatted,
                subtitle: subtitle,
                icon: "percent"
            )
        }
        
        return nil
    }
    
    // MARK: - Unit Conversion Parser
    
    // @note unit conversion definitions
    private let unitConversions: [(pattern: String, convert: (Double) -> Double, fromUnit: String, toUnit: String, icon: String)] = [
        // @note weight
        ("([\\d.]+)\\s*kg\\s*(?:to|in)\\s*(?:lbs?|pounds?)", { $0 * 2.20462 }, "kg", "lbs", "scalemass.fill"),
        ("([\\d.]+)\\s*(?:lbs?|pounds?)\\s*(?:to|in)\\s*kg", { $0 / 2.20462 }, "lbs", "kg", "scalemass.fill"),
        ("([\\d.]+)\\s*kg\\s*(?:to|in)\\s*(?:g|gr|grams?)", { $0 * 1000 }, "kg", "g", "scalemass.fill"),
        ("([\\d.]+)\\s*(?:g|gr|grams?)\\s*(?:to|in)\\s*kg", { $0 / 1000 }, "g", "kg", "scalemass.fill"),
        ("([\\d.]+)\\s*g\\s*(?:to|in)\\s*oz", { $0 * 0.035274 }, "g", "oz", "scalemass.fill"),
        ("([\\d.]+)\\s*oz\\s*(?:to|in)\\s*g", { $0 / 0.035274 }, "oz", "g", "scalemass.fill"),
        ("([\\d.]+)\\s*(?:lbs?|pounds?)\\s*(?:to|in)\\s*oz", { $0 * 16 }, "lbs", "oz", "scalemass.fill"),
        ("([\\d.]+)\\s*oz\\s*(?:to|in)\\s*(?:lbs?|pounds?)", { $0 / 16 }, "oz", "lbs", "scalemass.fill"),
        
        // @note temperature
        ("([\\d.]+)\\s*°?c\\s*(?:to|in)\\s*°?f", { ($0 * 9/5) + 32 }, "°C", "°F", "thermometer.medium"),
        ("([\\d.]+)\\s*°?f\\s*(?:to|in)\\s*°?c", { ($0 - 32) * 5/9 }, "°F", "°C", "thermometer.medium"),
        
        // @note length
        ("([\\d.]+)\\s*(?:ft|feet|foot)\\s*(?:to|in)\\s*m(?:eters?)?", { $0 * 0.3048 }, "ft", "m", "ruler.fill"),
        ("([\\d.]+)\\s*m(?:eters?)?\\s*(?:to|in)\\s*(?:ft|feet)", { $0 / 0.3048 }, "m", "ft", "ruler.fill"),
        ("([\\d.]+)\\s*(?:in|inch(?:es)?)\\s*(?:to|in)\\s*cm", { $0 * 2.54 }, "in", "cm", "ruler.fill"),
        ("([\\d.]+)\\s*cm\\s*(?:to|in)\\s*(?:in|inch(?:es)?)", { $0 / 2.54 }, "cm", "in", "ruler.fill"),
        ("([\\d.]+)\\s*(?:mi|miles?)\\s*(?:to|in)\\s*km", { $0 * 1.60934 }, "mi", "km", "ruler.fill"),
        ("([\\d.]+)\\s*km\\s*(?:to|in)\\s*(?:mi|miles?)", { $0 / 1.60934 }, "km", "mi", "ruler.fill"),
        
        // @note speed
        ("([\\d.]+)\\s*mph\\s*(?:to|in)\\s*(?:kmh|km/h|kph)", { $0 * 1.60934 }, "mph", "km/h", "speedometer"),
        ("([\\d.]+)\\s*(?:kmh|km/h|kph)\\s*(?:to|in)\\s*mph", { $0 / 1.60934 }, "km/h", "mph", "speedometer"),
        
        // @note volume
        ("([\\d.]+)\\s*(?:gal|gallons?)\\s*(?:to|in)\\s*(?:l|liters?|litres?)", { $0 * 3.78541 }, "gal", "L", "drop.fill"),
        ("([\\d.]+)\\s*(?:l|liters?|litres?)\\s*(?:to|in)\\s*(?:gal|gallons?)", { $0 / 3.78541 }, "L", "gal", "drop.fill"),
        
        // @note data
        ("([\\d.]+)\\s*(?:gb)\\s*(?:to|in)\\s*(?:mb)", { $0 * 1024 }, "GB", "MB", "externaldrive.fill"),
        ("([\\d.]+)\\s*(?:mb)\\s*(?:to|in)\\s*(?:gb)", { $0 / 1024 }, "MB", "GB", "externaldrive.fill"),
        ("([\\d.]+)\\s*(?:tb)\\s*(?:to|in)\\s*(?:gb)", { $0 * 1024 }, "TB", "GB", "externaldrive.fill"),
        ("([\\d.]+)\\s*(?:gb)\\s*(?:to|in)\\s*(?:tb)", { $0 / 1024 }, "GB", "TB", "externaldrive.fill"),
    ]
    
    // @note try unit conversion
    // @param input expression like "5kg to lbs"
    private func tryUnitConversion(_ input: String) -> CalculatorResult? {
        let lowercased = input.lowercased()
        
        for conversion in unitConversions {
            if let regex = try? NSRegularExpression(pattern: conversion.pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let valueRange = Range(match.range(at: 1), in: lowercased),
               let value = Double(String(lowercased[valueRange])) {
                
                let result = conversion.convert(value)
                let formatted = formatNumber(result)
                
                return CalculatorResult(
                    type: .unit,
                    expression: input,
                    result: "\(formatted) \(conversion.toUnit)",
                    subtitle: "\(formatNumber(value)) \(conversion.fromUnit) = \(formatted) \(conversion.toUnit)",
                    icon: conversion.icon
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Date/Time Parser
    
    // @note timezone abbreviation mappings
    private let timezoneMap: [String: String] = [
        "jkt": "Asia/Jakarta",
        "jakarta": "Asia/Jakarta",
        "nyc": "America/New_York",
        "new york": "America/New_York",
        "la": "America/Los_Angeles",
        "los angeles": "America/Los_Angeles",
        "sf": "America/Los_Angeles",
        "london": "Europe/London",
        "ldn": "Europe/London",
        "tokyo": "Asia/Tokyo",
        "tyo": "Asia/Tokyo",
        "paris": "Europe/Paris",
        "berlin": "Europe/Berlin",
        "sydney": "Australia/Sydney",
        "singapore": "Asia/Singapore",
        "sg": "Asia/Singapore",
        "hk": "Asia/Hong_Kong",
        "hong kong": "Asia/Hong_Kong",
        "dubai": "Asia/Dubai",
        "mumbai": "Asia/Kolkata",
        "delhi": "Asia/Kolkata",
        "seoul": "Asia/Seoul",
        "beijing": "Asia/Shanghai",
        "shanghai": "Asia/Shanghai",
        "utc": "UTC",
        "gmt": "GMT",
        "pst": "America/Los_Angeles",
        "pdt": "America/Los_Angeles",
        "est": "America/New_York",
        "edt": "America/New_York",
        "cst": "America/Chicago",
        "cdt": "America/Chicago",
        "mst": "America/Denver",
        "mdt": "America/Denver",
        "wib": "Asia/Jakarta",
        "wit": "Asia/Jayapura",
        "wita": "Asia/Makassar",
    ]
    
    // @note try date calculation
    // @param input expression like "monday in 3 weeks" or "days until 1/20"
    private func tryDateCalculation(_ input: String) -> CalculatorResult? {
        let lowercased = input.lowercased()
        
        // @note match "days until M/D" or "days until M/D/Y"
        if let regex = try? NSRegularExpression(pattern: "days?\\s+until\\s+(\\d{1,2})/(\\d{1,2})(?:/(\\d{2,4}))?", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let monthRange = Range(match.range(at: 1), in: lowercased),
           let dayRange = Range(match.range(at: 2), in: lowercased),
           let month = Int(String(lowercased[monthRange])),
           let day = Int(String(lowercased[dayRange])) {
            
            var year = Calendar.current.component(.year, from: Date())
            
            // @note check if year was provided
            if match.range(at: 3).location != NSNotFound,
               let yearRange = Range(match.range(at: 3), in: lowercased),
               let providedYear = Int(String(lowercased[yearRange])) {
                year = providedYear < 100 ? 2000 + providedYear : providedYear
            }
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            
            if let targetDate = Calendar.current.date(from: components) {
                var finalDate = targetDate
                
                // @note if date is in the past, use next year
                if finalDate < Date() && match.range(at: 3).location == NSNotFound {
                    components.year = year + 1
                    if let nextYearDate = Calendar.current.date(from: components) {
                        finalDate = nextYearDate
                    }
                }
                
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: finalDate).day ?? 0
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                
                return CalculatorResult(
                    type: .date,
                    expression: input,
                    result: "\(days) days",
                    subtitle: "Until \(formatter.string(from: finalDate))",
                    icon: "calendar"
                )
            }
        }
        
        // @note match "weekday in X weeks/days"
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        
        if let regex = try? NSRegularExpression(pattern: "(\\w+)\\s+in\\s+(\\d+)\\s+(weeks?|days?)", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
           let dayNameRange = Range(match.range(at: 1), in: lowercased),
           let numberRange = Range(match.range(at: 2), in: lowercased),
           let unitRange = Range(match.range(at: 3), in: lowercased) {
            
            let dayName = String(lowercased[dayNameRange])
            let number = Int(String(lowercased[numberRange])) ?? 0
            let unit = String(lowercased[unitRange])
            
            if let targetWeekday = weekdays.firstIndex(of: dayName) {
                let calendar = Calendar.current
                var dateComponent = DateComponents()
                
                if unit.starts(with: "week") {
                    dateComponent.weekOfYear = number
                } else {
                    dateComponent.day = number
                }
                
                if let futureDate = calendar.date(byAdding: dateComponent, to: Date()) {
                    // @note find the next occurrence of the target weekday
                    let currentWeekday = calendar.component(.weekday, from: futureDate)
                    let targetWeekdayNum = targetWeekday + 1 // Calendar weekday is 1-based
                    
                    var daysToAdd = targetWeekdayNum - currentWeekday
                    if daysToAdd < 0 { daysToAdd += 7 }
                    if daysToAdd == 0 && unit.starts(with: "week") { daysToAdd = 0 }
                    
                    if let finalDate = calendar.date(byAdding: .day, value: daysToAdd, to: futureDate) {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "EEEE, MMMM d, yyyy"
                        
                        return CalculatorResult(
                            type: .date,
                            expression: input,
                            result: formatter.string(from: finalDate),
                            subtitle: "\(dayName.capitalized) in \(number) \(unit)",
                            icon: "calendar"
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    // @note try time zone conversion
    // @param input expression like "5pm jkt in nyc"
    private func tryTimeConversion(_ input: String) -> CalculatorResult? {
        let lowercased = input.lowercased()
        
        // @note match "Xam/pm ZONE in ZONE" or "X:XX am/pm ZONE in ZONE"
        let pattern = "(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?\\s+(\\w+(?:\\s+\\w+)?)\\s+(?:in|to)\\s+(\\w+(?:\\s+\\w+)?)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) else {
            return nil
        }
        
        guard let hourRange = Range(match.range(at: 1), in: lowercased),
              var hour = Int(String(lowercased[hourRange])) else {
            return nil
        }
        
        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: lowercased),
           let min = Int(String(lowercased[minuteRange])) {
            minute = min
        }
        
        // @note handle am/pm
        if match.range(at: 3).location != NSNotFound,
           let ampmRange = Range(match.range(at: 3), in: lowercased) {
            let ampm = String(lowercased[ampmRange])
            if ampm == "pm" && hour != 12 {
                hour += 12
            } else if ampm == "am" && hour == 12 {
                hour = 0
            }
        }
        
        guard let fromZoneRange = Range(match.range(at: 4), in: lowercased),
              let toZoneRange = Range(match.range(at: 5), in: lowercased) else {
            return nil
        }
        
        let fromZoneKey = String(lowercased[fromZoneRange]).trimmingCharacters(in: .whitespaces)
        let toZoneKey = String(lowercased[toZoneRange]).trimmingCharacters(in: .whitespaces)
        
        guard let fromZoneId = timezoneMap[fromZoneKey],
              let toZoneId = timezoneMap[toZoneKey],
              let fromZone = TimeZone(identifier: fromZoneId),
              let toZone = TimeZone(identifier: toZoneId) else {
            return nil
        }
        
        // @note create date in source timezone
        var calendar = Calendar.current
        calendar.timeZone = fromZone
        
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        
        guard let sourceDate = calendar.date(from: components) else {
            return nil
        }
        
        // @note format in target timezone
        let formatter = DateFormatter()
        formatter.timeZone = toZone
        formatter.dateFormat = "h:mm a"
        
        let resultTime = formatter.string(from: sourceDate)
        
        // @note format source time for subtitle
        let sourceFormatter = DateFormatter()
        sourceFormatter.timeZone = fromZone
        sourceFormatter.dateFormat = "h:mm a"
        let sourceTime = sourceFormatter.string(from: sourceDate)
        
        return CalculatorResult(
            type: .time,
            expression: input,
            result: resultTime,
            subtitle: "\(sourceTime) \(fromZoneKey.uppercased()) → \(toZoneKey.uppercased())",
            icon: "clock.fill"
        )
    }
    
    // MARK: - Helpers
    
    // @note format number for display
    // @param value number to format
    private func formatNumber(_ value: Double) -> String {
        // @note handle infinity and NaN
        if value.isNaN {
            return "Error"
        }
        if value.isInfinite {
            return value > 0 ? "∞" : "-∞"
        }
        
        let absValue = abs(value)
        
        // @note use scientific notation for very large or very small numbers
        if absValue >= 1e15 || (absValue < 1e-10 && absValue > 0) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 10
            formatter.exponentSymbol = "E"
            if let formatted = formatter.string(from: NSNumber(value: value)) {
                return formatted
            }
        }
        
        // @note check if it's a whole number (within reasonable range)
        if value.truncatingRemainder(dividingBy: 1) == 0 && absValue < 1e15 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if let formatted = formatter.string(from: NSNumber(value: value)) {
                return formatted
            }
            return String(format: "%.0f", value)
        }
        
        // @note use decimal format with thousand separators
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        
        if let formatted = formatter.string(from: NSNumber(value: value)) {
            return formatted
        }
        
        return String(value)
    }
}
