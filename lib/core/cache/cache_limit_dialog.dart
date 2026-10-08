// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../foundation/caching/types.dart';
import '../../foundation/caching/cache_limit_options.dart';

Future<CacheSize?> showCacheLimitDialog(
  BuildContext context, {
  required CacheSize currentValue,
}) {
  return showDialog<CacheSize>(
    context: context,
    builder: (context) => CacheLimitDialog(currentValue: currentValue),
  );
}

class CacheLimitDialog extends StatefulWidget {
  const CacheLimitDialog({
    required this.currentValue,
    super.key,
  });

  final CacheSize currentValue;

  @override
  State<CacheLimitDialog> createState() => _CacheLimitDialogState();
}

class _CacheLimitDialogState extends State<CacheLimitDialog> {
  late var _sliderGigabytes = CacheLimitOptions.initialCustomGigabytes(
    widget.currentValue,
  ).toDouble();

  int get _selectedGigabytes {
    return CacheLimitOptions.snapGigabytes(_sliderGigabytes.round());
  }

  CacheSize get _selectedSize {
    return CacheLimitOptions.fromGigabytes(_selectedGigabytes);
  }

  @override
  Widget build(BuildContext context) {
    final selectedSize = _selectedSize;

    return KurumiDialog(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              selectedSize.displayString(withSpace: true),
              style: Kurumi.themeOf(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: CacheLimitOptions.canDecrease(_selectedGigabytes)
                    ? _decrement
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: KurumiSlider(
                  min: CacheLimitOptions.minCustomGigabytes.toDouble(),
                  max: CacheLimitOptions.maxCustomGigabytes.toDouble(),
                  value: _sliderGigabytes,
                  onChanged: _updateFromSlider,
                ),
              ),
              IconButton(
                onPressed: CacheLimitOptions.canIncrease(_selectedGigabytes)
                    ? _increment
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedSize),
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _decrement() {
    setState(() {
      _sliderGigabytes = CacheLimitOptions.decrease(
        _selectedGigabytes,
      ).toDouble();
    });
  }

  void _increment() {
    setState(() {
      _sliderGigabytes = CacheLimitOptions.increase(
        _selectedGigabytes,
      ).toDouble();
    });
  }

  void _updateFromSlider(double value) {
    setState(() {
      _sliderGigabytes = value;
    });
  }
}
