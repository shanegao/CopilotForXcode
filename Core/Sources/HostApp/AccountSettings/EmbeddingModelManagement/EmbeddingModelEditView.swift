import AIModel
import ComposableArchitecture
import Preferences
import SwiftUI

@MainActor
struct EmbeddingModelEditView: View {
    let store: StoreOf<EmbeddingModelEdit>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    nameTextField
                    formatPicker

                    WithViewStore(store, observe: { $0.format }) { viewStore in
                        switch viewStore.state {
                        case .openAI:
                            openAI
                        case .azureOpenAI:
                            azureOpenAI
                        case .openAICompatible:
                            openAICompatible
                        case .ollama:
                            ollama
                        }
                    }
                }
                .padding()

                Divider()

                HStack {
                    WithViewStore(store, observe: { $0.isTesting }) { viewStore in
                        HStack(spacing: 8) {
                            Button("Test") {
                                store.send(.testButtonClicked)
                            }
                            .disabled(viewStore.state)

                            if viewStore.state {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }

                    Spacer()

                    Button("Cancel") {
                        store.send(.cancelButtonClicked)
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(action: { store.send(.saveButtonClicked) }) {
                        Text("Save")
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding()
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            store.send(.appear)
        }
        .fixedSize(horizontal: false, vertical: true)
        .handleToast(namespace: "EmbeddingModelEdit")
    }

    var nameTextField: some View {
        WithViewStore(store, removeDuplicates: { $0.name == $1.name }) { viewStore in
            TextField("Name", text: viewStore.$name)
        }
    }

    var formatPicker: some View {
        WithViewStore(store, removeDuplicates: { $0.format == $1.format }) { viewStore in
            Picker(
                selection: viewStore.$format,
                content: {
                    ForEach(
                        EmbeddingModel.Format.allCases,
                        id: \.rawValue
                    ) { format in
                        switch format {
                        case .openAI:
                            Text("OpenAI").tag(format)
                        case .azureOpenAI:
                            Text("Azure OpenAI").tag(format)
                        case .openAICompatible:
                            Text("OpenAI Compatible").tag(format)
                        case .ollama:
                            Text("Ollama").tag(format)
                        }
                    }
                },
                label: { Text("Format") }
            )
            .pickerStyle(.segmented)
        }
    }

    func baseURLTextField<V: View>(
        title: String = "Base URL",
        prompt: Text?,
        @ViewBuilder trailingContent: @escaping () -> V
    ) -> some View {
        BaseURLPicker(
            title: title,
            prompt: prompt,
            store: store.scope(
                state: \.baseURLSelection,
                action: EmbeddingModelEdit.Action.baseURLSelection
            ),
            trailingContent: trailingContent
        )
    }

    func baseURLTextField(
        title: String = "Base URL",
        prompt: Text?
    ) -> some View {
        baseURLTextField(title: title, prompt: prompt, trailingContent: { EmptyView() })
    }

    struct MaxTokensTextField: Equatable {
        @BindingViewState var maxTokens: Int
        var suggestedMaxTokens: Int?
    }

    var maxTokensTextField: some View {
        WithViewStore(
            store,
            observe: {
                MaxTokensTextField(
                    maxTokens: $0.$maxTokens,
                    suggestedMaxTokens: $0.suggestedMaxTokens
                )
            }
        ) { viewStore in
            HStack {
                let textFieldBinding = Binding(
                    get: { String(viewStore.state.maxTokens) },
                    set: {
                        if let selectionMaxToken = Int($0) {
                            viewStore.$maxTokens.wrappedValue = selectionMaxToken
                        } else {
                            viewStore.$maxTokens.wrappedValue = 0
                        }
                    }
                )

                TextField(text: textFieldBinding) {
                    Text("Max Input Tokens")
                        .multilineTextAlignment(.trailing)
                }
                .overlay(alignment: .trailing) {
                    Stepper(
                        value: viewStore.$maxTokens,
                        in: 0...Int.max,
                        step: 100
                    ) {
                        EmptyView()
                    }
                }
                .foregroundColor({
                    guard let max = viewStore.state.suggestedMaxTokens else {
                        return .primary
                    }
                    if viewStore.state.maxTokens > max {
                        return .red
                    }
                    return .primary
                }() as Color)

                if let max = viewStore.state.suggestedMaxTokens {
                    Text("Max: \(max)")
                }
            }
        }
    }

    struct APIKeyState: Equatable {
        @BindingViewState var apiKeyName: String
        var availableAPIKeys: [String]
    }

    @ViewBuilder
    var apiKeyNamePicker: some View {
        APIKeyPicker(store: store.scope(
            state: \.apiKeySelection,
            action: EmbeddingModelEdit.Action.apiKeySelection
        ))
    }

    @ViewBuilder
    var openAI: some View {
        baseURLTextField(prompt: Text("https://api.openai.com")) {
            Text("/v1/embeddings")
        }
        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Model Name", text: viewStore.$modelName)
                .overlay(alignment: .trailing) {
                    Picker(
                        "",
                        selection: viewStore.$modelName,
                        content: {
                            if OpenAIEmbeddingModel(rawValue: viewStore.state.modelName) == nil {
                                Text("Custom Model").tag(viewStore.state.modelName)
                            }
                            ForEach(OpenAIEmbeddingModel.allCases, id: \.self) { model in
                                Text(model.rawValue).tag(model.rawValue)
                            }
                        }
                    )
                    .frame(width: 20)
                }
        }

        maxTokensTextField
        
        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " To get an API key, please visit [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)"
            )

            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " If you don't have access to GPT-4, you may need to visit [https://platform.openai.com/account/billing/overview](https://platform.openai.com/account/billing/overview) to buy some credits. A ChatGPT Plus subscription is not enough to access GPT-4 through API."
            )
        }
        .padding(.vertical)
    }

    @ViewBuilder
    var azureOpenAI: some View {
        baseURLTextField(prompt: Text("https://xxxx.openai.azure.com"))
        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Deployment Name", text: viewStore.$modelName)
        }

        maxTokensTextField
    }

    @ViewBuilder
    var openAICompatible: some View {
        WithViewStore(store.scope(
            state: \.baseURLSelection,
            action: EmbeddingModelEdit.Action.baseURLSelection
        ), removeDuplicates: { $0.isFullURL != $1.isFullURL }) { viewStore in
            Picker(
                selection: viewStore.$isFullURL,
                content: {
                    Text("Base URL").tag(false)
                    Text("Full URL").tag(true)
                },
                label: { Text("URL") }
            )
            .pickerStyle(.segmented)
        }

        WithViewStore(store, observe: \.isFullURL) { viewStore in
            baseURLTextField(
                title: "",
                prompt: viewStore.state
                    ? Text("https://api.openai.com/v1/embeddings")
                    : Text("https://api.openai.com")
            ) {
                if !viewStore.state {
                    Text("/v1/embeddings")
                }
            }
        }

        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Model Name", text: viewStore.$modelName)
        }

        maxTokensTextField
    }
    
    @ViewBuilder
    var ollama: some View {
        baseURLTextField(prompt: Text("http://127.0.0.1:11434")) {
            Text("/api/embeddings")
        }

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Model Name", text: viewStore.$modelName)
        }

        maxTokensTextField
        
        WithViewStore(
            store,
            removeDuplicates: { $0.ollamaKeepAlive == $1.ollamaKeepAlive }
        ) { viewStore in
            TextField(text: viewStore.$ollamaKeepAlive, prompt: Text("Default Value")) {
                Text("Keep Alive")
            }
        }
        
        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " For more details, please visit [https://ollama.com](https://ollama.com)."
            )
        }
        .padding(.vertical)
    }
}

class EmbeddingModelManagementView_Editing_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddingModelEditView(
            store: .init(
                initialState: .init(model: EmbeddingModel(
                    id: "3",
                    name: "Test Model 3",
                    format: .openAICompatible,
                    info: .init(
                        apiKeyName: "key",
                        baseURL: "apple.com",
                        maxTokens: 3000,
                        modelName: "gpt-3.5-turbo"
                    )
                )),
                reducer: EmbeddingModelEdit()
            )
        )
    }
}

