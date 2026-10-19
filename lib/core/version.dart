/// App 版本（編譯期注入；tag-on-main.yml 以 --dart-define=APP_VERSION 傳入，
/// 本機開發顯示 dev）——視窗標題（main.dart）與總覽頁尾（overview_page.dart）。
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
