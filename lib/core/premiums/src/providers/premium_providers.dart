// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Plus is unconditional in this fork: no entitlement is checked, so every
// installation gets the full feature set and the upsell entry points that
// guard on `!kForcePremium` stay hidden.
const kForcePremium = true;

final hasPremiumProvider = Provider<bool>((ref) => true);

final showPremiumFeatsProvider = Provider<bool>((ref) => true);
