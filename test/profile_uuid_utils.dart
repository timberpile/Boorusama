String profileUuid(int seed) =>
    '00000000-0000-4000-8000-${seed.toRadixString(16).padLeft(12, '0')}';
