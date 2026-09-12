typedef AndroidApiLevel = int;

final class AndroidVersion {
  const AndroidVersion({
    required this.release,
    required this.apiLevel,
  });

  final String release;
  final AndroidApiLevel apiLevel;
}

abstract class AndroidVersions {
  static const android6 = AndroidVersion(release: '6', apiLevel: 23);
  static const android7_0 = AndroidVersion(release: '7.0', apiLevel: 24);
  static const android7_1 = AndroidVersion(release: '7.1', apiLevel: 25);
  static const android8_0 = AndroidVersion(release: '8.0', apiLevel: 26);
  static const android8_1 = AndroidVersion(release: '8.1', apiLevel: 27);
  static const android9 = AndroidVersion(release: '9', apiLevel: 28);
  static const android10 = AndroidVersion(release: '10', apiLevel: 29);
  static const android11 = AndroidVersion(release: '11', apiLevel: 30);
  static const android12 = AndroidVersion(release: '12', apiLevel: 31);
  static const android12L = AndroidVersion(release: '12L', apiLevel: 32);
  static const android13 = AndroidVersion(release: '13', apiLevel: 33);
  static const android14 = AndroidVersion(release: '14', apiLevel: 34);
  static const android15 = AndroidVersion(release: '15', apiLevel: 35);
}

bool? hasScopedStorage(AndroidApiLevel? apiLevel) {
  if (apiLevel == null) return null;

  return apiLevel >= AndroidVersions.android11.apiLevel;
}

bool? hasGranularMediaPermissions(AndroidApiLevel? apiLevel) {
  if (apiLevel == null) return null;

  return apiLevel >= AndroidVersions.android13.apiLevel;
}
