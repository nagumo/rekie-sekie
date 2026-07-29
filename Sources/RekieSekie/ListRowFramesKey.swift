import SwiftUI

/// リスト各行の表示位置（List座標系でのframe）を集約するPreferenceKey。
/// スクロール中に「どの行が見えているか」を親ビューへ伝え、
/// 選択行が可視範囲から外れたときに選択を追従させるために使う。
struct ListRowFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
