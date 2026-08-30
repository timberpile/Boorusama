## 1. Removal result

- [x] 1.1 Add a dedicated bulk-removal result type containing the number of removed memberships and the number of bookmarks now in No Group.
- [x] 1.2 Update the bulk group-removal provider operation to calculate the No Group count from the pre-removal memberships and return the structured result.
- [x] 1.3 Update all bulk-removal callers and existing tests to use the structured result while preserving membership-only removal semantics.

## 2. User feedback

- [x] 2.1 Add localized success-message variants for removal with and without bookmarks now in No Group.
- [x] 2.2 Update the multi-selection bookmark menu to select the appropriate localized message from the provider result and omit the No Group clause when its count is zero.
- [x] 2.3 Regenerate localization output and verify the displayed messages for named groups with mixed memberships.

## 3. Verification

- [x] 3.1 Add provider coverage for final-membership removal, remaining memberships, and selections containing posts that are not in the chosen group.
- [x] 3.2 Add widget coverage for both success-message variants and the conditional No Group clause.
- [x] 3.3 Run formatting, targeted analysis, focused bookmark tests, and strict OpenSpec validation.
