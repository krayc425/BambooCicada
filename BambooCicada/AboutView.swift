import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("totalCompletedRotations") private var totalCompletedRotations = 0
    @State private var isShowingResetConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 76))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(accent, Color.white.opacity(0.16))
                            .accessibilityHidden(true)

                        VStack(spacing: 10) {
                            Text("竹蝉")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .tracking(4)

                            Text("转一缕风，听一声蝉鸣")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            Text("会鸣叫的传统玩具")
                                .font(.title2.bold())

                            Text("竹蝉，也叫叫蝉、竹知了，是一种模仿蝉鸣的传统民间玩具。它通常由竹筒、薄膜、细绳和小竹片组成，造型朴素，却能发出响亮而有趣的声音。")

                            Divider()
                                .overlay(.white.opacity(0.18))

                            aboutSection(
                                icon: "waveform",
                                title: "为什么会叫？",
                                text: "挥动玩具时，竹片带着绳子绕圈旋转。绳子的振动传到竹筒一端的薄膜上，再由中空的竹筒放大，于是形成近似知了的嗡鸣声。"
                            )

                            aboutSection(
                                icon: "hand.draw",
                                title: "怎么玩？",
                                text: "握住竹筒或手柄，让竹片在空中连续绕圈。转得越快，振动越强，声音通常也越响。玩耍时要留出空间，并注意不要碰到身边的人。"
                            )

                            aboutSection(
                                icon: "sun.max",
                                title: "一声夏日记忆",
                                text: "竹蝉把简单的竹、绳与薄膜变成了声音，是民间巧思与童年趣味的缩影。轻轻转动，仿佛就把夏天的蝉鸣带到了耳边。"
                            )

                            Divider()
                                .overlay(.white.opacity(0.18))

                            Link(destination: wikipediaURL) {
                                HStack {
                                    Text("维基百科")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .accessibilityHint("在浏览器中打开叫蝉的维基百科词条")
                        }
                        .font(.body)
                        .lineSpacing(6)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(22)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(spacing: 0) {
                            Button {
                                isShowingResetConfirmation = true
                            } label: {
                                HStack {
                                    Text("清零圈数")
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .accessibilityHint("将累计转动圈数重置为零")
                            .frame(maxWidth: .infinity, minHeight: 52)

                            Divider()
                                .overlay(.white.opacity(0.18))

                            HStack {
                                Text("版本号")
                                Spacer()
                                Text(appVersion)
                                    .monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("版本号 \(appVersion)")
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .font(.body)
                        .padding(.horizontal, 20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 36)
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
            .navigationTitle("关于")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("确定要清零累计圈数吗？", isPresented: $isShowingResetConfirmation) {
            Button("清零圈数", role: .destructive) {
                totalCompletedRotations = 0
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。")
        }
    }

    private var accent: Color {
        Color(red: 0.95, green: 0.82, blue: 0.45)
    }

    private func aboutSection(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.10, blue: 0.075),
                Color(red: 0.11, green: 0.20, blue: 0.12),
                Color(red: 0.035, green: 0.065, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var wikipediaURL: URL {
        URL(string: "https://zh.wikipedia.org/wiki/%E5%8F%AB%E8%9D%89")!
    }
}

#Preview {
    AboutView()
}
