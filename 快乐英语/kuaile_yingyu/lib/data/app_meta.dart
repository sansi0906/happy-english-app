/// 界面上展示的 App 版本号。
///
/// 必须与 `pubspec.yaml` 里的 `version:`（`+` 之前的部分）保持一致：
/// CI 的 asset-gate 与 `tool/check_assets.py` 会校验这一条，不一致直接构建失败。
/// 之所以不引第三方包（package_info_plus）读系统版本，是为了不再增加依赖与体积。
const String kAppVersion = '1.6.1';
