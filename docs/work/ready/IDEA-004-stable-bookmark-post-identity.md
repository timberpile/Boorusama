# Identify bookmarks by site and upstream post

Priority: High
Affected feature: Bookmarks, profile-independent lookup, backup/import

## Problem

Bookmark equality must represent an upstream post across profiles without colliding with another installation or changing when a media URL changes. The current identity does not reliably provide that portable post identity.

## Expected behavior

The same post on the same booru installation appears as one bookmark through any profile. Different installations may use the same engine and numeric post ID without sharing a bookmark. Two posts stay distinct even when they point to the same image or video.

## Decisions and edge cases

- Canonical identity is `(normalized site namespace, stable upstream post key)`. Lowercase the host, retain non-default port and installation path, and ignore scheme, credentials, query, fragment, and trailing slash.
- Every supported engine supplies a stable post key: upstream post ID or a documented compound key such as work plus page. Never substitute media URL, Hive row key, clock value, or generated UUID.
- Engine and profile ID are interpretation/resolution metadata, not equality components. CDN URL change, profile rename/deletion/recreation, and HTTP-to-HTTPS change do not affect membership. A genuinely moved installation is a new namespace until a separate alias design exists.
- A breaking bookmark schema change is permitted. Old bookmarks need not load. Normal reads have no legacy URL fallback. If preserving old data becomes necessary, define a separate explicit converter task.
- Local integer bookmark row keys stay internal. New backup/import records carry site namespace and post key.

## Acceptance criteria

- Two profiles on one normalized site/post resolve to one bookmark; the same engine/post ID on two installations resolves to two.
- Two posts using one media URL remain separate; changing only engine metadata does not change bookmark membership.
- Profile rename, deletion/recreation, HTTP-to-HTTPS change, and media URL change do not orphan the bookmark.
- New backup/import round-trips site namespace and stable post key without relying on local row keys or media URLs.
- Stable-key tests cover supported engines, including compound keys where needed. Normal loading includes no legacy URL fallback or converter.

## Context and dependencies

Required before IDEA-010's cross-profile Favorites fetch; IDEA-015 must preserve it. Independent of IDEA-002 profile UUIDs. A legacy converter is deliberately out of scope.

- [Bookmark architecture](../../bookmark_groups.md)
