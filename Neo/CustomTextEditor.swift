import SwiftUI

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .init(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = RichTextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.string = text
        textView.textContainer?.lineFragmentPadding = 0
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // Only update if the plain text content actually changed
        if textView.string != text { 
            // Preserve formatting when updating from external changes
            let currentSelection = textView.selectedRange()
            textView.string = text
            // Restore selection if possible
            let newLength = text.count
            if currentSelection.location <= newLength {
                let newSelection = NSRange(location: min(currentSelection.location, newLength), length: 0)
                textView.setSelectedRange(newSelection)
            }
        }
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.font = font
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        weak var textView: RichTextView?
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
        }
    }
}

class RichTextView: NSTextView {
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
    }
}
