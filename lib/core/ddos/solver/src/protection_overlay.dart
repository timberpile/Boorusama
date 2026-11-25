// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

enum ProtectionOverlayNotice { blocked, checkingPublicJson, clearanceMissing }

class ProtectionOverlay extends StatefulWidget {
  const ProtectionOverlay({
    required this.url,
    required this.browser,
    required this.onCancel,
    required this.onSolved,
    required this.notice,
    this.browserReady,
    super.key,
  });
  final String url;
  final Widget browser;
  final VoidCallback onCancel;
  final VoidCallback onSolved;
  final ValueListenable<ProtectionOverlayNotice?> notice;
  final ValueListenable<bool>? browserReady;

  @override
  State<ProtectionOverlay> createState() => _ProtectionOverlayState();
}

class _ProtectionOverlayState extends State<ProtectionOverlay> {
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ValueListenableBuilder(
              valueListenable: widget.notice,
              builder: (_, notice, _) => LayoutBuilder(
                builder: (_, constraints) => Column(
                  children: [
                    _buildHeader(notice),
                    const SizedBox(height: 16),
                    if (notice != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight / 3,
                        ),
                        child: SingleChildScrollView(
                          child: _buildNotice(notice),
                        ),
                      ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Visibility(
                          visible: _showBrowser(notice),
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: widget.browser,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.browserReady case final browserReady?)
                      ValueListenableBuilder<bool>(
                        valueListenable: browserReady,
                        builder: (_, ready, _) => _buildButtons(ready, notice),
                      )
                    else
                      _buildButtons(true, notice),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _showBrowser(ProtectionOverlayNotice? notice) =>
      notice == null || notice == ProtectionOverlayNotice.blocked;

  Widget _buildHeader(ProtectionOverlayNotice? notice) {
    return Row(
      children: [
        const Icon(Icons.security, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _showBrowser(notice)
                ? context.t.captcha.title
                : context.t.captcha.verification_title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ),
      ],
    );
  }

  Widget _buildNotice(ProtectionOverlayNotice notice) {
    final (icon, message) = switch (notice) {
      ProtectionOverlayNotice.blocked => (
        Icons.block,
        context.t.captcha.blocked_by_site,
      ),
      ProtectionOverlayNotice.clearanceMissing => (
        Icons.info_outline,
        context.t.captcha.clearance_missing,
      ),
      ProtectionOverlayNotice.checkingPublicJson => (
        Icons.info_outline,
        context.t.captcha.checking_public_response,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(bool browserReady, ProtectionOverlayNotice? notice) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white),
            foregroundColor: Colors.white,
          ),
          child: Text(context.t.generic.action.cancel),
        ),
        if (_showBrowser(notice))
          FilledButton(
            onPressed: browserReady ? widget.onSolved : null,
            child: Text(context.t.captcha.i_have_solved_it),
          ),
      ],
    );
  }
}
