enum ImportAction {
  update,
  merge,
  replace,
  configureItems,
  skip,
  copy,
  mergeIntoTarget,
}

ImportAction importActionFromJson(Object? value) => switch (value) {
  final String name => ImportAction.values.firstWhere(
    (action) => action.name == name,
    orElse: () => throw const FormatException('Invalid import action'),
  ),
  _ => throw const FormatException('Invalid import action'),
};
