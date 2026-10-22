import 'package:flutter/material.dart';

/// App 主題定稿（M7 UI 統整；PM 2026-10-21 簽核三決策：
/// 警示色維持 orange/red、無障礙最小合規、深色以 token 覆蓋＋PM 走查）。
///
/// 色板來源＝specs/plan/ui/*.html 雛型與 Demo 畫廊（lib/presentation/screens/
/// demo/demo_shared.dart）已驗證組合；正式頁一律經 [AppTokens] 取語意色，
/// 禁止新增 Colors.* 硬編碼（ad-hoc 樣式為 M7 前已知債——本檔落地後清零）。
class AppTokens extends ThemeExtension<AppTokens> {
  /// 品牌主色（teal；AppShell seed 與雛型 `01~09` 同源）。
  static const Color brandSeed = Color(0xFF0B7A75);

  const AppTokens({
    required this.danger,
    required this.warning,
    required this.success,
    required this.pending,
    required this.subText,
    required this.divider,
    required this.track,
    required this.cardBg,
    required this.bg,
  });

  /// 超支/逾期/錯誤。**定稿＝Colors.red 常數**（F05 N-1 契約 100% 紅——
  /// harness 斷言 Colors.red，值恆等相容）。
  final Color danger;

  /// 80% 警示/未繳。**定稿＝Colors.orange 常數**（F05 N-2 契約——同上恆等）。
  final Color warning;

  /// 已繳/達成（品牌 teal——雛型 b-paid/badge 語意）。
  final Color success;

  /// 預扣/分期承諾標籤（雛型 .tag 紫 #6D4FC4）。
  final Color pending;

  /// 次要文字（雛型 .muted）。
  final Color subText;

  /// 分隔線（雛型 --line）。
  final Color divider;

  /// 進度軌底色（雛型 --track）。
  final Color track;

  /// 卡片底（雛型 --card）。
  final Color cardBg;

  /// 頁面底（雛型 --bg）。
  final Color bg;

  static const Color _seed = brandSeed;

  /// 淺色組（DemoTheme.light 同源）。
  static const AppTokens light = AppTokens(
    danger: Colors.red,
    warning: Colors.orange,
    success: _seed,
    pending: Color(0xFF6D4FC4),
    subText: Color(0xFF7D8B8A),
    divider: Color(0xFFE3E7EA),
    track: Color(0xFFEDF1F2),
    cardBg: Colors.white,
    bg: Color(0xFFF5F7F8),
  );

  /// 深色組（DemoTheme.dark 同源）。
  static const AppTokens dark = AppTokens(
    danger: Colors.red,
    warning: Colors.orange,
    success: _seed,
    pending: Color(0xFF9B7FE8), // 深色提亮（#6D4FC4 於 #12191A 對比不足）
    subText: Color(0xFFA7B5B3),
    divider: Color(0xFF2B3637),
    track: Color(0xFF2B3637),
    cardBg: Color(0xFF1E2829),
    bg: Color(0xFF12191A),
  );

  /// 頁面取用（ThemeExtension 慣例）。
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? danger,
    Color? warning,
    Color? success,
    Color? pending,
    Color? subText,
    Color? divider,
    Color? track,
    Color? cardBg,
    Color? bg,
  }) =>
      AppTokens(
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        success: success ?? this.success,
        pending: pending ?? this.pending,
        subText: subText ?? this.subText,
        divider: divider ?? this.divider,
        track: track ?? this.track,
        cardBg: cardBg ?? this.cardBg,
        bg: bg ?? this.bg,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      subText: Color.lerp(subText, other.subText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      track: Color.lerp(track, other.track, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
    );
  }
}

/// 主題建構（AppShell 唯一入口——light/dark 同源）。
ThemeData buildAppTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppTokens._seed, brightness: brightness),
    scaffoldBackgroundColor: tokens.bg,
    extensions: [tokens],
  );
}
