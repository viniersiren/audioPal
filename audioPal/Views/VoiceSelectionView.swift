//import SwiftUI
//
//struct VoiceSelectionView: View {
//    @ObservedObject var viewModel: ChatViewModel
//    @State private var showVoiceMenu: Bool = false
//    
//    var body: some View {
//        Menu {
//            ForEach(viewModel.availableVoices, id: \.identifier) { voice in
//                Button(action: {
//                    viewModel.setVoice(voice)
//                }) {
//                    HStack {
//                        Text(voice.name)
//                        if voice.identifier == viewModel.selectedVoice?.identifier {
//                            Image(systemName: "checkmark")
//                        }
//                    }
//                }
//            }
//        } label: {
//            HStack(spacing: 4) {
//                Image(systemName: "speaker.wave.2.fill")
//                if let selectedVoice = viewModel.selectedVoice {
//                    Text(selectedVoice.name)
//                        .font(.caption)
//                        .lineLimit(1)
//                }
//            }
//            .foregroundColor(.blue)
//        }
//    }
//} 
