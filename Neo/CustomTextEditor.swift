import SwiftUI

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var richContent: Data?
    var font: NSFont
    var textColor: NSColor
    var backgroundColor: NSColor
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerKnobStyle = .light
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: .init(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        
        let textView = RichTextView(frame: .zero, textContainer: textContainer)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.textContainer?.lineFragmentPadding = 0

        // Load initial content: prefer rich content if available (RTFD first, then RTF)
        if let richData = richContent, !richData.isEmpty {
            if let attributed = NSAttributedString(rtfd: richData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributed)
            } else if let attributed = NSAttributedString(rtf: richData, documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = text
            }
        } else {
            textView.string = text
        }

    // Ensure default typing is left-aligned
    let defaultParagraphStyle = NSMutableParagraphStyle()
    defaultParagraphStyle.alignment = .left
    textView.defaultParagraphStyle = defaultParagraphStyle
    textView.typingAttributes[.paragraphStyle] = defaultParagraphStyle
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Never overwrite content here; only update lightweight styling
        guard let textView = context.coordinator.textView else { return }
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        // Avoid resetting font here to preserve typingAttributes (bold/italic)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        weak var textView: RichTextView?
    var shouldLoadRichContent = false
    var shouldLoadPlainText = false
    var hasLoadedInitialContent = false
    var isProgrammaticLoad = false
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            if isProgrammaticLoad { isProgrammaticLoad = false; return }
            parent.text = textView.string

            // Always save RTFD so images/attachments persist reliably
            if let textStorage = textView.textStorage {
                let fullRange = NSRange(location: 0, length: textStorage.length)
                if let rtfdData = textStorage.rtfd(from: fullRange, documentAttributes: [:]) {
                    parent.richContent = rtfdData
                } else if let rtfData = textStorage.rtf(from: fullRange, documentAttributes: [:]) {
                    parent.richContent = rtfData
                }
            }
        }
        
        func loadDocumentContent() {
            shouldLoadRichContent = true
            shouldLoadPlainText = true
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
            case "k":
                insertHyperlink()
                return
            case "v":
                // Handle paste with image support
                paste(self)
                return
            default: 
                break
            }
        }
        super.keyDown(with: event)
    }
    
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        
        // Check for images first - try multiple methods
        var image: NSImage? = nil
        
        // Method 1: Check for direct NSImage
        if let pasteboardImage = NSImage(pasteboard: pasteboard) {
            image = pasteboardImage
        }
        // Method 2: Check for file URLs first (important for Finder)
        else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if isImageFile(url: url), let urlImage = NSImage(contentsOf: url) {
                    image = urlImage
                    break
                }
            }
        }
        // Method 3: Check for image data in various formats
        else if let imageData = pasteboard.data(forType: .tiff) ?? 
                                 pasteboard.data(forType: .png) ?? 
                                 pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) ??
                                 pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")) ??
                                 pasteboard.data(forType: NSPasteboard.PasteboardType("public.tiff")) ??
                                 pasteboard.data(forType: NSPasteboard.PasteboardType("com.adobe.pdf")) {
            image = NSImage(data: imageData)
        }
        // Method 4: Check for file promise (drag and drop compatibility)
        else if pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            // Handle file promises if needed
        }
        
        if let image = image {
            insertImageFromPasteboard(image: image)
            return
        }
        
        // If no image, use default paste behavior
        super.paste(sender)
    }
    
    private func insertImageFromPasteboard(image: NSImage) {
        // Create resizable image attachment with embedded data so it persists in RTF
        let attachment = NSTextAttachment()
        
        // Calculate size - max 300pt width, maintain aspect ratio
        let maxWidth: CGFloat = 300
        let originalSize = image.size
        let aspectRatio = originalSize.height / originalSize.width
        let newWidth = min(maxWidth, originalSize.width)
        let newHeight = newWidth * aspectRatio
        
        attachment.image = image
        // Embed image data into fileWrapper (prefer PNG for lossless)
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            attachment.fileWrapper = FileWrapper(regularFileWithContents: png)
            attachment.fileWrapper?.preferredFilename = "image.png"
        }
        attachment.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        
        // Create attributed string with the image
        let imageString = NSAttributedString(attachment: attachment)
        
        // Insert at current cursor position
        let selectedRange = self.selectedRange()
        
        // Create a new line before and after the image, with center alignment
        let mutableString = NSMutableAttributedString()
        
        // Add leading newline if not at start of line
        if selectedRange.location > 0 {
            let previousChar = (string as NSString).character(at: selectedRange.location - 1)
            if previousChar != unichar(NSString.init(string: "\n").character(at: 0)) {
                mutableString.append(NSAttributedString(string: "\n"))
            }
        }
        
        // Add the image with center alignment
        let centeredImageString = NSMutableAttributedString(attributedString: imageString)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.paragraphSpacingBefore = 10
        centeredImageString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: centeredImageString.length))
        
        // Make image container
        let imageContainer = NSMutableAttributedString()
        imageContainer.append(NSAttributedString(string: "\n"))
        imageContainer.append(centeredImageString)
        imageContainer.append(NSAttributedString(string: "\n"))
        
    // Apply paragraph style to the entire container
        let containerParagraphStyle = NSMutableParagraphStyle()
        containerParagraphStyle.alignment = .center
        imageContainer.addAttribute(.paragraphStyle, value: containerParagraphStyle, range: NSRange(location: 0, length: imageContainer.length))
        
    // Append image container and then a left-aligned newline to resume typing left
    mutableString.append(imageContainer)
    let trailing = NSMutableAttributedString(string: "\n")
    let leftStyle = NSMutableParagraphStyle()
    leftStyle.alignment = .left
    trailing.addAttribute(.paragraphStyle, value: leftStyle, range: NSRange(location: 0, length: trailing.length))
    mutableString.append(trailing)
        
        if shouldChangeText(in: selectedRange, replacementString: mutableString.string) {
            textStorage?.replaceCharacters(in: selectedRange, with: mutableString)
            didChangeText()
            
            // Move cursor after the image and trailing newline, and set typing attributes to left-aligned
            let newLocation = selectedRange.location + mutableString.length
            setSelectedRange(NSRange(location: newLocation, length: 0))
            typingAttributes[.paragraphStyle] = leftStyle
        }
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        
        // Add hyperlink option if text is selected
        let selectedRange = self.selectedRange()
        if selectedRange.length > 0 {
            let hyperlinkItem = NSMenuItem(title: "Add Hyperlink", action: #selector(addHyperlinkFromMenu), keyEquivalent: "")
            hyperlinkItem.target = self
            menu.insertItem(hyperlinkItem, at: 0)
            menu.insertItem(NSMenuItem.separator(), at: 1)
        }
        
        return menu
    }
    
    @objc private func addHyperlinkFromMenu() {
        insertHyperlink()
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return .copy
        }
        return []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if isImageFile(url: url) {
                    insertImage(at: url)
                }
            }
            return true
        }
        return false
    }
    
    private func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif", "svg", "ico", "pdf"]
        let pathExtension = url.pathExtension.lowercased()
        
        // Check file extension
        if imageExtensions.contains(pathExtension) {
            return true
        }
        
        // Check UTI (Uniform Type Identifier) for more reliable detection
        if let uti = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            return uti.hasPrefix("public.image") || uti == "com.adobe.pdf"
        }
        
        return false
    }
    
    private func insertImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        
        // Create resizable image attachment with embedded data so it persists in RTF
        let attachment = NSTextAttachment()
        
        // Calculate size - max 300pt width, maintain aspect ratio
        let maxWidth: CGFloat = 300
        let originalSize = image.size
        let aspectRatio = originalSize.height / originalSize.width
        let newWidth = min(maxWidth, originalSize.width)
        let newHeight = newWidth * aspectRatio
        
        attachment.image = image
        // Prefer embedding the original data when possible
        if let data = try? Data(contentsOf: url) {
            attachment.fileWrapper = FileWrapper(regularFileWithContents: data)
            attachment.fileWrapper?.preferredFilename = url.lastPathComponent
        } else if let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) {
            attachment.fileWrapper = FileWrapper(regularFileWithContents: png)
            attachment.fileWrapper?.preferredFilename = "image.png"
        }
        attachment.bounds = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        
        // Create attributed string with the image
        let imageString = NSAttributedString(attachment: attachment)
        
        // Insert at current cursor position
        let selectedRange = self.selectedRange()
        
        // Create a new line before and after the image, with center alignment
        let mutableString = NSMutableAttributedString()
        
        // Add leading newline if not at start of line
        if selectedRange.location > 0 {
            let previousChar = (string as NSString).character(at: selectedRange.location - 1)
            if previousChar != unichar(NSString.init(string: "\n").character(at: 0)) {
                mutableString.append(NSAttributedString(string: "\n"))
            }
        }
        
        // Add the image with center alignment
        let centeredImageString = NSMutableAttributedString(attributedString: imageString)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.paragraphSpacingBefore = 10
        centeredImageString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: centeredImageString.length))
        
        // Make image non-deletable by adding special character
        let imageContainer = NSMutableAttributedString()
        imageContainer.append(NSAttributedString(string: "\n"))
        imageContainer.append(centeredImageString)
        imageContainer.append(NSAttributedString(string: "\n"))
        
        // Apply paragraph style to the entire container
        let containerParagraphStyle = NSMutableParagraphStyle()
        containerParagraphStyle.alignment = .center
        imageContainer.addAttribute(.paragraphStyle, value: containerParagraphStyle, range: NSRange(location: 0, length: imageContainer.length))
        
        mutableString.append(imageContainer)
        
        if shouldChangeText(in: selectedRange, replacementString: mutableString.string) {
            textStorage?.replaceCharacters(in: selectedRange, with: mutableString)
            didChangeText()
            
            // Move cursor after the image
            let newLocation = selectedRange.location + mutableString.length
            setSelectedRange(NSRange(location: newLocation, length: 0))
        }
    }
    
    private func insertHyperlink() {
        let selectedRange = self.selectedRange()
        
        if selectedRange.length > 0 {
            // Text is selected - make it a hyperlink
            let selectedText = (string as NSString).substring(with: selectedRange)
            showHyperlinkDialog(selectedText: selectedText, range: selectedRange)
        } else {
            // No selection - insert new hyperlink
            showHyperlinkDialog(selectedText: "", range: selectedRange)
        }
    }
    
    private func showHyperlinkDialog(selectedText: String, range: NSRange) {
        let alert = NSAlert()
        alert.messageText = "Add Hyperlink"
        alert.informativeText = ""
        alert.alertStyle = .informational
        
        // Create container view with padding
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 120))
        
        // URL label
        let urlLabel = NSTextField(labelWithString: "URL:")
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        urlLabel.textColor = NSColor.labelColor
        urlLabel.frame = NSRect(x: 0, y: 90, width: 340, height: 18)
        containerView.addSubview(urlLabel)
        
        // URL field with modern styling
        let urlField = NSTextField(frame: NSRect(x: 0, y: 65, width: 340, height: 28))
        urlField.placeholderString = "https://example.com"
        urlField.bezelStyle = .roundedBezel
        urlField.font = NSFont.systemFont(ofSize: 13)
        urlField.focusRingType = .none
        containerView.addSubview(urlField)
        
        // Display text label
        let textLabel = NSTextField(labelWithString: "Display Text:")
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textLabel.textColor = NSColor.labelColor
        textLabel.frame = NSRect(x: 0, y: 35, width: 340, height: 18)
        containerView.addSubview(textLabel)
        
        // Display text field with modern styling
        let textField = NSTextField(frame: NSRect(x: 0, y: 10, width: 340, height: 28))
        textField.placeholderString = "Link text (optional)"
        textField.stringValue = selectedText
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.focusRingType = .none
        containerView.addSubview(textField)
        
        alert.accessoryView = containerView
        
        // Style the buttons
        let addButton = alert.addButton(withTitle: "Add Link")
        addButton.keyEquivalent = "\r" // Enter key
        let cancelButton = alert.addButton(withTitle: "Cancel")
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        
        // Focus on URL field initially
        DispatchQueue.main.async {
            urlField.becomeFirstResponder()
        }
        
        if alert.runModal() == .alertFirstButtonReturn {
            let urlString = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayText = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !urlString.isEmpty {
                let linkText = displayText.isEmpty ? urlString : displayText
                insertHyperlinkText(linkText, url: urlString, at: range)
            }
        }
    }
    
    private func insertHyperlinkText(_ text: String, url: String, at range: NSRange) {
        guard let validURL = URL(string: url) else { return }
        
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.link, value: validURL, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.count))
        
        if shouldChangeText(in: range, replacementString: text) {
            textStorage?.replaceCharacters(in: range, with: attributedString)
            didChangeText()
            
            // Move cursor after the link
            let newLocation = range.location + text.count
            setSelectedRange(NSRange(location: newLocation, length: 0))
        }
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
