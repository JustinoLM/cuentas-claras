//
//  CSVDocument.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import SwiftUI
import UniformTypeIdentifiers

// Solo existe para alimentar `.fileExporter`; la app nunca abre CSVs, por eso la lectura es mínima.
nonisolated struct CSVDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.commaSeparatedText]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
