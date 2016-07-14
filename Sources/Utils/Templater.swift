
//basic templater, where {{ NAME }} gets replaced by the value of NAME in the context
//like Stencil: https://github.com/kylef/Stencil , just super simple and does only
//find and replace, that's it

import Foundation

public func fillTemplate(template: String, context: [String: String]) throws -> String {
    
    let result = try _run(template: template, context: context)
    return result
}

typealias CharacterTriplet = (Character, Character, Character)

struct BufferOfThree {
    var storage: CharacterTriplet = (Character(" "), Character(" "), Character(" "))
    mutating func push(_ char: Character) {
        storage.0 = storage.1
        storage.1 = storage.2
        storage.2 = char
    }
    
    func contains(chars: CharacterTriplet) -> Bool {
        return chars.0 == storage.0 && chars.1 == storage.1 && chars.2 == storage.2
    }
}

enum TemplateError: ErrorProtocol {
    case malformedTemplate(String)
    case valuesNotFoundInContext([String])
    case variablesNotFoundInTemplate([String])
}

private func _run(template: String, context: [String: String]) throws -> String {
    
    var chars = template.characters
    var curr = chars.startIndex
    
    let charsStart: CharacterTriplet = (Character("{"), Character("{"), Character(" "))
    let charsEnd: CharacterTriplet = (Character(" "), Character("}"), Character("}"))
    
    var buffer = BufferOfThree()
    var isOpen = false
    var varName: [Character] = []
    var openIndex: String.Index? = nil
    
    while curr < chars.endIndex {
        if isOpen {
            //expect close, otherwise read insides
            if buffer.contains(chars: charsEnd) {
                //found a new var
                guard let openIdx = openIndex else { throw TemplateError.malformedTemplate(template) }
                let range = Range(uncheckedBounds: (openIdx, curr))
                let actualVarName = varName.dropLast(3)
                let name = String(actualVarName)
                
                guard let value = context[name] else {
                    throw TemplateError.valuesNotFoundInContext([name])
                }
                chars.replaceSubrange(range, with: value.characters)
                
                //FIXME: be smarter and continue at the offset index instead of starting over (simpler)
                curr = chars.startIndex
                
                isOpen = false
                openIndex = nil
                varName = []
            } else {
                varName.append(chars[curr])
            }
        } else {
            //expect open, otherwise skip
            if buffer.contains(chars: charsStart) {
                openIndex = chars.index(curr, offsetBy: -3)
                isOpen = true
                varName.append(chars[curr])
            }
        }
        buffer.push(chars[curr])
        chars.formIndex(after: &curr)
    }
    
    return String(chars)
}