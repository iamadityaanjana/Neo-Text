import SwiftUI
import Combine

// A custom NSViewRepresentable wrapping NSTextView to enable line centering + focus visuals.
struct FocusTextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var currentLine: Int
    var isDark: Bool
    var centerLine: Bool
    var fontSize: CGFloat = 18
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = false // hide scrollbar per request
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
    scrollView.scrollerStyle = .overlay
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
    let textView = CenteringTextView(frame: .zero, textContainer: textContainer)
    textView.backgroundColor = .clear
    // Modest top padding; we'll scroll to center instead of dynamic inset growth.
    textView.textContainerInset = NSSize(width: 0, height: 120)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
    textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = isDark ? .white : .black
        textView.insertionPointColor = isDark ? .white : .black
    textView.string = text
    textView.textContainer?.lineFragmentPadding = 0
        textView.focusDelegate = context.coordinator
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
    if textView.string != text { textView.string = text }
    textView.textColor = isDark ? .white : .black
    textView.insertionPointColor = isDark ? .white : .black
    if let f = textView.font, abs(f.pointSize - fontSize) > 0.5 { textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate, FocusLineDelegate {
        var parent: FocusTextEditorRepresentable
        weak var textView: CenteringTextView?
        weak var scrollView: NSScrollView?
        private var cancellables = Set<AnyCancellable>()
        
        init(_ parent: FocusTextEditorRepresentable) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            parent.text = tv.string
            updateCurrentLine()
            if parent.centerLine { centerCurrentLine(animated: true) }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateCurrentLine()
            if parent.centerLine { centerCurrentLine(animated: true) }
        }
        
        func updateCurrentLine() {
            guard let tv = textView else { return }
            let caret = tv.selectedRange().location
            let ns = tv.string as NSString
            var foundLine = 0
            var currentIndex = 0
            ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byLines) { _, lineRange, _, stop in
                if caret < lineRange.location { stop.pointee = true; return }
                if NSLocationInRange(caret, lineRange) {
                    foundLine = currentIndex
                    stop.pointee = true
                    return
                }
                currentIndex += 1
            }
            parent.currentLine = foundLine
            tv.focusedLineIndex = foundLine
        }
        
        func centerCurrentLine(animated: Bool) {
            guard let tv = textView, let sv = scrollView else { return }
            guard let layoutManager = tv.layoutManager, let textContainer = tv.textContainer else { return }
            var sel = tv.selectedRange()
            if sel.length == 0 {
                if sel.location == 0 && tv.string.isEmpty { return }
                if sel.location > 0 { sel = NSRange(location: sel.location - 1, length: 1) }
            }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: sel, actualCharacterRange: nil)
            let caretRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            // Convert to textView coordinates
            let caretMidY = caretRect.midY + tv.textContainerOrigin.y
            let visibleHeight = sv.contentView.bounds.height
            let desiredOriginY = caretMidY - (visibleHeight / 2)
            let maxOriginY = max(0, tv.bounds.height - visibleHeight)
            let clamped = max(0, min(desiredOriginY, maxOriginY))
            if abs(Double(sv.contentView.bounds.origin.y - clamped)) < 0.5 { return }
            let apply = {
                sv.contentView.setBoundsOrigin(CGPoint(x: 0, y: clamped))
                sv.reflectScrolledClipView(sv.contentView)
            }
            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.allowsImplicitAnimation = true
                    ctx.duration = 0.16
                    sv.contentView.animator().setBoundsOrigin(CGPoint(x: 0, y: clamped))
                } completionHandler: {
                    sv.reflectScrolledClipView(sv.contentView)
                }
            } else { apply() }
        }
    }
}

protocol FocusLineDelegate: AnyObject {
    func updateCurrentLine()
}

class CenteringTextView: NSTextView {
    weak var focusDelegate: FocusLineDelegate?
    var focusedLineIndex: Int = 0
    
    override func doCommand(by selector: Selector) {
        // Intercept Command+B and Command+I before they reach the system
        switch selector {
        case #selector(NSResponder.selectAll(_:)):
            super.doCommand(by: selector)
        default:
            super.doCommand(by: selector)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() {
            switch chars {
            case "b": 
                toggleBold()
                return
            case "i": 
                toggleItalic()
                return
            default: 
                break
            }
        }
        super.keyDown(with: event)
    }
    
    private func toggleBold() {
        let selectedRange = self.selectedRange()
        
        if selectedRange.length == 0 {
            // No selection - update typing attributes
            var attrs = typingAttributes
            if let currentFont = attrs[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont: NSFont
                if fontManager.traits(of: currentFont).contains(.boldFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
                }
                attrs[.font] = newFont
                typingAttributes = attrs
            }
            return
        }
        
        textStorage?.beginEditing()
        
        textStorage?.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont: NSFont
                if fontManager.traits(of: font).contains(.boldFontMask) {
                    newFont = fontManager.convert(font, toNotHaveTrait: .boldFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .boldFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: range)
            }
        }
        
        textStorage?.endEditing()
        focusDelegate?.updateCurrentLine()
    }
    
    private func toggleItalic() {
        let selectedRange = self.selectedRange()
        
        if selectedRange.length == 0 {
            // No selection - update typing attributes
            var attrs = typingAttributes
            if let currentFont = attrs[.font] as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont: NSFont
                if fontManager.traits(of: currentFont).contains(.italicFontMask) {
                    newFont = fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
                }
                attrs[.font] = newFont
                typingAttributes = attrs
            }
            return
        }
        
        textStorage?.beginEditing()
        
        textStorage?.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                let fontManager = NSFontManager.shared
                let newFont: NSFont
                if fontManager.traits(of: font).contains(.italicFontMask) {
                    newFont = fontManager.convert(font, toNotHaveTrait: .italicFontMask)
                } else {
                    newFont = fontManager.convert(font, toHaveTrait: .italicFontMask)
                }
                textStorage?.addAttribute(.font, value: newFont, range: range)
            }
        }
        
        textStorage?.endEditing()
        focusDelegate?.updateCurrentLine()
    }
}
