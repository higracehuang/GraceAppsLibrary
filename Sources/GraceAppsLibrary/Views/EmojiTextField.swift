//
//  EmojiTextField.swift
//  GraceAppsLibrary
//
//  Created by Antigravity on 4/8/26.
//

import SwiftUI
import UIKit

/// A specialized UITextField that forces the emoji keyboard.
public class UIEmojiTextField: UITextField {
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public func setEmoji() {
        _ = self.textInputMode
    }
    
    public override var textInputContextIdentifier: String? {
           return ""
    }
    
    public override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" {
                self.keyboardType = .default
                return mode
            }
        }
        return nil
    }

    public func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.doneButtonAction))

        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.sizeToFit()

        self.inputAccessoryView = doneToolbar
    }

    @objc func doneButtonAction() {
        self.resignFirstResponder()
    }
}

/// A SwiftUI wrapper for `UIEmojiTextField` that enforces single emoji/character input.
public struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    private var placeholder: String
    private var font: UIFont?
    private var textAlignment: NSTextAlignment
    
    public init(text: Binding<String>, placeholder: String = "", font: UIFont? = nil, textAlignment: NSTextAlignment = .left) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textAlignment = textAlignment
    }
    
    public func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.placeholder = placeholder
        emojiTextField.text = text
        emojiTextField.delegate = context.coordinator
        emojiTextField.textAlignment = textAlignment
        if let font = font {
            emojiTextField.font = font
        }
        emojiTextField.addDoneButtonOnKeyboard()
        return emojiTextField
    }
    
    public func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        uiView.text = text
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        
        init(parent: EmojiTextField) {
            self.parent = parent
        }
        
        public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            // If deleting, allow it
            if string.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.text = ""
                }
                return true
            }
            
            // Replace the entire content with the new emoji
            if !string.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.text = string
                }
            }
            
            // Always return false to prevent default behavior
            return false
        }
        
        public func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = textField.text ?? ""
            }
        }
    }
}
