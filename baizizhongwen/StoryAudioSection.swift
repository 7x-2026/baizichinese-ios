import SwiftUI
import Combine

/// 每个播放器保留自己的进度，开始另一条音频时先暂停上一条。
private final class StoryPlaybackCoordinator: ObservableObject {
    private weak var activePlayer: AudioPlayerManager?

    func toggle(_ player: AudioPlayerManager) {
        if activePlayer !== player {
            activePlayer?.pause()
            activePlayer = player
        }
        player.playPause()
    }

    func stop() {
        activePlayer?.stop()
        activePlayer = nil
    }
}

struct StoryAudioSection: View {
    let lineIndex: Int

    @StateObject private var playback = StoryPlaybackCoordinator()

    private var stories: [LineStory] {
        StoryAudioLibrary.shared.stories(forLineIndex: lineIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if stories.isEmpty {
                Text("暂无故事音频")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(stories) { story in
                    VStack(alignment: .leading, spacing: 14) {
                        NavigationLink {
                            StoryTextView(story: story)
                        } label: {
                            HStack(spacing: 12) {
                                Text(story.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(story.title)
                        .accessibilityHint("查看故事全文")

                        ForEach(story.tracks) { track in
                            StoryAudioRow(
                                storyTitle: story.title,
                                track: track,
                                playback: playback
                            )
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
            }
        }
        .onDisappear { playback.stop() }
    }
}

private struct StoryAudioRow: View {
    let storyTitle: String
    let track: StoryAudioTrack
    let playback: StoryPlaybackCoordinator

    @StateObject private var audioManager = AudioPlayerManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(track.language.title)
                    .font(.subheadline)
                    .frame(width: 58, alignment: .leading)

                Button {
                    playback.toggle(audioManager)
                } label: {
                    Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .disabled(audioManager.duration == 0)
                .accessibilityLabel(
                    "\(audioManager.isPlaying ? "暂停" : "播放")\(storyTitle)（\(track.language.title)）"
                )

                VStack(spacing: 0) {
                    Slider(
                        value: Binding(
                            get: { audioManager.currentTime },
                            set: { audioManager.seek(to: $0) }
                        ),
                        in: 0...max(audioManager.duration, 0.001)
                    )
                    .disabled(audioManager.duration == 0)
                    .accessibilityLabel("\(storyTitle)（\(track.language.title)）播放进度")

                    HStack {
                        Text(formatTime(audioManager.currentTime))
                        Spacer()
                        Text(formatTime(audioManager.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = audioManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear { audioManager.load(url: track.url) }
        .onDisappear { audioManager.stop() }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "00:00" }
        return String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
