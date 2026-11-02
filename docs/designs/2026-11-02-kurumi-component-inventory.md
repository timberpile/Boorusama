# Kurumi component-family index

Date: 2026-11-02
Source: `develop` @ `74cdf43a5bd5205baa8f7cefb164986fe2656dd1`
Scope: all **73** direct implementation files under `packages/kurumi/lib/src/components/`, inspected using the connected GitHub source. This is an inventory of declaration families, **not** proof that every name is a public UI widget or is used in the app. For exact call sites, run `python3 scripts/audit_ui_components.py` in a local checkout.

All items with the `Kurumi...` prefix are **not necessarily custom widgets**: some are controllers, action types, helpers, enums, data holders, or `typedef` aliases to Flutter Material controls. In addition, helper functions are exposed through `Kurumi.*` static methods. The authoritative public export list is `packages/kurumi/lib/kurumi.dart`, which can differ from file-local declarations. The list below deliberately does not imply that every declaration is public.

| Component file | Declared types / helpers of interest |
| --- | --- |
| [`action_animation_overlay.dart`](../../packages/kurumi/lib/src/components/action_animation_overlay.dart) | KurumiActionAnimationOverlay |
| [`adaptive_button_row.dart`](../../packages/kurumi/lib/src/components/adaptive_button_row.dart) | KurumiOverflowStrategy, KurumiButtonPlacement, KurumiButtonData, KurumiAdaptiveButtonRow |
| [`adaptive_sheet.dart`](../../packages/kurumi/lib/src/components/adaptive_sheet.dart) | Adaptive sheet/side-sheet helper functions (no Kurumi-prefixed class) |
| [`anchor.dart`](../../packages/kurumi/lib/src/components/anchor.dart) | KurumiAnchor |
| [`animated_cross_fade.dart`](../../packages/kurumi/lib/src/components/animated_cross_fade.dart) | KurumiAnimatedCrossFade |
| [`app_bar.dart`](../../packages/kurumi/lib/src/components/app_bar.dart) | KurumiAppBar, KurumiSliverAppBar |
| [`back_handler.dart`](../../packages/kurumi/lib/src/components/back_handler.dart) | KurumiBackHandler, KurumiDismissible |
| [`bottom_sheet.dart`](../../packages/kurumi/lib/src/components/bottom_sheet.dart) | KurumiBottomSheet |
| [`bottom_sheet_actions.dart`](../../packages/kurumi/lib/src/components/bottom_sheet_actions.dart) | KurumiBottomSheetActionButtons |
| [`bottom_sheet_header.dart`](../../packages/kurumi/lib/src/components/bottom_sheet_header.dart) | KurumiBottomSheetHeader |
| [`button.dart`](../../packages/kurumi/lib/src/components/button.dart) | KurumiButton |
| [`chip.dart`](../../packages/kurumi/lib/src/components/chip.dart) | KurumiChipColors, KurumiChip |
| [`circular_icon_button.dart`](../../packages/kurumi/lib/src/components/circular_icon_button.dart) | KurumiCircularIconButton |
| [`compact_chip.dart`](../../packages/kurumi/lib/src/components/compact_chip.dart) | KurumiCompactChip, KurumiRawCompactChip |
| [`context_menu.dart`](../../packages/kurumi/lib/src/components/context_menu.dart) | KurumiContextMenu, KurumiContextMenuTile, KurumiContextMenuDivider, KurumiContextMenuController, KurumiContextMenuPageController, KurumiContextMenuPolicy, KurumiAdaptiveContextMenuGestureTrigger |
| [`cross_scope_focus.dart`](../../packages/kurumi/lib/src/components/cross_scope_focus.dart) | KurumiDirectionalFocusAction, KurumiLeaveSingleLineFieldAction, KurumiNextFocusAction, KurumiPreviousFocusAction |
| [`desktop_window.dart`](../../packages/kurumi/lib/src/components/desktop_window.dart) | KurumiDesktopWindowFrame, KurumiMacosCaption |
| [`dialog.dart`](../../packages/kurumi/lib/src/components/dialog.dart) | KurumiDialog |
| [`dialog_content.dart`](../../packages/kurumi/lib/src/components/dialog_content.dart) | KurumiDialogContent |
| [`dismissible_info_container.dart`](../../packages/kurumi/lib/src/components/dismissible_info_container.dart) | KurumiDismissibleInfoContainer |
| [`dotted_border.dart`](../../packages/kurumi/lib/src/components/dotted_border.dart) | KurumiDottedBorder, KurumiDottedBorderButton, KurumiBorderType, KurumiDashedPainter |
| [`drag_line.dart`](../../packages/kurumi/lib/src/components/drag_line.dart) | KurumiDragLine |
| [`fitted_text.dart`](../../packages/kurumi/lib/src/components/fitted_text.dart) | KurumiFittedText, KurumiToolbarTitleScope |
| [`focus_pane.dart`](../../packages/kurumi/lib/src/components/focus_pane.dart) | KurumiFocusPane |
| [`focus_ring.dart`](../../packages/kurumi/lib/src/components/focus_ring.dart) | KurumiFocusRing, KurumiFocusHighlight |
| [`grayed_out.dart`](../../packages/kurumi/lib/src/components/grayed_out.dart) | KurumiGrayedOut |
| [`hero.dart`](../../packages/kurumi/lib/src/components/hero.dart) | KurumiHero, KurumiLinearRectTween |
| [`hover_aware_container.dart`](../../packages/kurumi/lib/src/components/hover_aware_container.dart) | KurumiHoverAwareContainer |
| [`image_error_placeholder.dart`](../../packages/kurumi/lib/src/components/image_error_placeholder.dart) | KurumiImageErrorPlaceholder |
| [`image_placeholder.dart`](../../packages/kurumi/lib/src/components/image_placeholder.dart) | KurumiImagePlaceholder |
| [`info_circle.dart`](../../packages/kurumi/lib/src/components/info_circle.dart) | KurumiInfoCircleStyle, KurumiInfoCircleIcon, KurumiInfoCirclePainter |
| [`info_container.dart`](../../packages/kurumi/lib/src/components/info_container.dart) | KurumiInfoContainer, KurumiWarningContainer, KurumiTemplateContainer |
| [`interactive_viewer.dart`](../../packages/kurumi/lib/src/components/interactive_viewer.dart) | KurumiTransformationDetails, KurumiInteractiveViewer, KurumiRawInteractiveViewer |
| [`like_button.dart`](../../packages/kurumi/lib/src/components/like_button.dart) | KurumiLikeButton |
| [`linear_progress_indicator.dart`](../../packages/kurumi/lib/src/components/linear_progress_indicator.dart) | KurumiLinearProgressIndicator |
| [`listbox.dart`](../../packages/kurumi/lib/src/components/listbox.dart) | KurumiListbox, KurumiListboxItem, KurumiListboxController, KurumiListboxKeys |
| [`material_chips.dart`](../../packages/kurumi/lib/src/components/material_chips.dart) | Material typedefs: KurumiMaterialChip, KurumiMaterialRawChip, KurumiMaterialChoiceChip, KurumiMaterialFilterChip, KurumiMaterialActionChip |
| [`material_controls.dart`](../../packages/kurumi/lib/src/components/material_controls.dart) | Material typedefs: KurumiMaterialSegmentedButton, KurumiMaterialButtonSegment |
| [`media_query.dart`](../../packages/kurumi/lib/src/components/media_query.dart) | KurumiRemoveLeftPaddingOnLargeScreen, KurumiOverlayInsetsScope, KurumiOverlayMediaQuery |
| [`navigation_tile.dart`](../../packages/kurumi/lib/src/components/navigation_tile.dart) | KurumiNavigationTile |
| [`no_data.dart`](../../packages/kurumi/lib/src/components/no_data.dart) | KurumiGenericNoDataBox |
| [`option_dropdown.dart`](../../packages/kurumi/lib/src/components/option_dropdown.dart) | KurumiOptionDropDownButton, KurumiOptionDropDownMenuHeader |
| [`option_searchable_sheet.dart`](../../packages/kurumi/lib/src/components/option_searchable_sheet.dart) | KurumiOptionSearchableSheet, KurumiOptionSingleSearchableField |
| [`page_indicator.dart`](../../packages/kurumi/lib/src/components/page_indicator.dart) | KurumiPageIndicator |
| [`popup_menu.dart`](../../packages/kurumi/lib/src/components/popup_menu.dart) | KurumiPopupMenuButton, KurumiPopupMenuItem |
| [`pulse_indicator.dart`](../../packages/kurumi/lib/src/components/pulse_indicator.dart) | KurumiPulseIndicator |
| [`radio_group.dart`](../../packages/kurumi/lib/src/components/radio_group.dart) | KurumiRadioGroup |
| [`refresh_indicator.dart`](../../packages/kurumi/lib/src/components/refresh_indicator.dart) | KurumiRefreshIndicator |
| [`route_transition.dart`](../../packages/kurumi/lib/src/components/route_transition.dart) | Route-transition helper functions (no Kurumi-prefixed class) |
| [`scroll_button.dart`](../../packages/kurumi/lib/src/components/scroll_button.dart) | KurumiScrollToTopButton, KurumiScrollToBottomButton |
| [`scroll_visibility.dart`](../../packages/kurumi/lib/src/components/scroll_visibility.dart) | KurumiScrollToTop, KurumiScrollToBottom |
| [`search_bar.dart`](../../packages/kurumi/lib/src/components/search_bar.dart) | KurumiSearchBar |
| [`segmented_button.dart`](../../packages/kurumi/lib/src/components/segmented_button.dart) | KurumiSegmentedButton, KurumiSlidingSegmentedControl, KurumiMeasureSize, KurumiSegmentCache, KurumiSegmentAnimationPanel |
| [`selectable_chip.dart`](../../packages/kurumi/lib/src/components/selectable_chip.dart) | KurumiSelectableChip |
| [`selectable_item.dart`](../../packages/kurumi/lib/src/components/selectable_item.dart) | KurumiSelectableItem |
| [`selection_tile.dart`](../../packages/kurumi/lib/src/components/selection_tile.dart) | KurumiDesktopSelectionTile |
| [`settings_card.dart`](../../packages/kurumi/lib/src/components/settings_card.dart) | KurumiSettingsCard, KurumiSettingsCardTitle, KurumiSettingsCardSurface |
| [`settings_header.dart`](../../packages/kurumi/lib/src/components/settings_header.dart) | KurumiSettingsHeader |
| [`settings_navigation_tile.dart`](../../packages/kurumi/lib/src/components/settings_navigation_tile.dart) | KurumiSettingsEntryTile |
| [`settings_radio_card.dart`](../../packages/kurumi/lib/src/components/settings_radio_card.dart) | KurumiSettingsRadioCard, KurumiSettingsRadioCardEntry |
| [`settings_slider_tile.dart`](../../packages/kurumi/lib/src/components/settings_slider_tile.dart) | KurumiSettingsSliderTile |
| [`settings_tile.dart`](../../packages/kurumi/lib/src/components/settings_tile.dart) | KurumiSettingsTile |
| [`shadow_gradient_overlay.dart`](../../packages/kurumi/lib/src/components/shadow_gradient_overlay.dart) | KurumiShadowGradientOverlay |
| [`side_menu_tile.dart`](../../packages/kurumi/lib/src/components/side_menu_tile.dart) | KurumiSideMenuTile |
| [`slider.dart`](../../packages/kurumi/lib/src/components/slider.dart) | KurumiSlider |
| [`sliver_divider.dart`](../../packages/kurumi/lib/src/components/sliver_divider.dart) | KurumiSliverDivider |
| [`square_chip.dart`](../../packages/kurumi/lib/src/components/square_chip.dart) | KurumiSquareChip |
| [`status_box.dart`](../../packages/kurumi/lib/src/components/status_box.dart) | KurumiErrorBox, KurumiNoDataBox |
| [`switch_list_tile.dart`](../../packages/kurumi/lib/src/components/switch_list_tile.dart) | KurumiSwitchListTile |
| [`text_field.dart`](../../packages/kurumi/lib/src/components/text_field.dart) | KurumiTextField |
| [`text_form_field.dart`](../../packages/kurumi/lib/src/components/text_form_field.dart) | KurumiTextFormField |
| [`toast.dart`](../../packages/kurumi/lib/src/components/toast.dart) | Toast helper functions (no Kurumi-prefixed class) |
| [`tooltip.dart`](../../packages/kurumi/lib/src/components/tooltip.dart) | KurumiTooltip |

## App-level reusable widgets are separate

`lib/core/widgets` contains **36 Dart files**, including application wrappers, feature-adjacent helpers, and one export barrel. Representative names include `NoDataBox`, `OptionSearchableSheet`, `AdaptiveButtonRow`, `SettingsSelector`, `MultiSelectButton`, `MultiSelectionActionBar`, `BooruChip`, and `TagChipInput`. Unlike Kurumi, these may depend on localization, app configuration, booru metadata, assets, and navigation policy. Do not move them into the Kurumi package without checking dependency boundaries.

## What this inventory does and does not prove

- **Verified:** the listed component files and declaration families exist in the inspected source version.
- **Verified:** `KurumiMaterialChip` and its relatives are aliases to Material chips; `KurumiMaterialSegmentedButton` and `KurumiMaterialButtonSegment` are also Material aliases.
- **Not yet established:** complete app-wide usage counts or rendered equivalence of native Material and Kurumi variants. The local static scanner and screenshots provide the next evidence step.
- **Not a bug list:** helpers, direct Material construction, and domain-specific wrappers are not automatically duplication or inconsistency.
