import 'package:equatable/equatable.dart';

import 'types.dart';

class CacheLimitOptions {
  const CacheLimitOptions._();

  static const minCustomGigabytes = 5;
  static const maxCustomGigabytes = 200;
  static const customStepGigabytes = 10;
  static const defaultCustomGigabytes = 50;

  static const presets = [
    CacheSize.oneHundredMegabytes,
    CacheSize.fiveHundredMegabytes,
    CacheSize.oneGigabyte,
    CacheSize.twoGigabytes,
    CacheSize.fiveGigabytes,
    CacheSize.tenGigabytes,
    CacheSize.zero,
  ];

  static List<CacheLimitOption> dropdownOptions() {
    return [
      ...presets.map(CacheLimitOption.size),
      CacheLimitOption.custom(),
    ];
  }

  static CacheLimitOption selectedOption(CacheSize currentValue) {
    return presets.contains(currentValue)
        ? CacheLimitOption.size(currentValue)
        : CacheLimitOption.custom();
  }

  static int initialCustomGigabytes(CacheSize currentValue) {
    if (currentValue.isZero) return defaultCustomGigabytes;

    return snapGigabytes(
      (currentValue.bytes / bytesPerGigabyte).round(),
    );
  }

  static CacheSize fromGigabytes(int gigabytes) {
    final clamped = snapGigabytes(gigabytes);

    return CacheSize.tryParse(clamped * bytesPerGigabyte)!;
  }

  static bool canDecrease(int gigabytes) => gigabytes > minCustomGigabytes;

  static bool canIncrease(int gigabytes) => gigabytes < maxCustomGigabytes;

  static int decrease(int gigabytes) {
    return snapGigabytes(gigabytes - customStepGigabytes);
  }

  static int increase(int gigabytes) {
    return snapGigabytes(gigabytes + customStepGigabytes);
  }

  static int snapGigabytes(int gigabytes) {
    final clamped = gigabytes.clamp(minCustomGigabytes, maxCustomGigabytes);

    return (clamped / customStepGigabytes).round() * customStepGigabytes;
  }

  static const bytesPerGigabyte = 1024 * 1024 * 1024;
}

class CacheLimitOption extends Equatable {
  const CacheLimitOption._({
    required this.cacheSize,
    required this.isCustom,
  });

  factory CacheLimitOption.size(CacheSize cacheSize) => CacheLimitOption._(
    cacheSize: cacheSize,
    isCustom: false,
  );

  factory CacheLimitOption.custom() => const CacheLimitOption._(
    cacheSize: null,
    isCustom: true,
  );

  final CacheSize? cacheSize;
  final bool isCustom;

  @override
  List<Object?> get props => [cacheSize, isCustom];
}
