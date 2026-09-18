---
name: ship-harps-release
description: Package a new signed/notarized Harps.app release, ship the DMG to the harps-website repo with a changelog entry, and commit+push both repos. Use whenever the user asks to "package this up into a DMG", "ship a release", "cut a new version", or similar for the Harps app — this is the standing, repeatable version of that whole flow so it never has to be re-specified.
---

# Ship a Harps release

Harps lives in two separate git repos that both need updating for a real
release:

- `~/sites/personal-projects/voice-capture/app` — the Xcode project.
  `scripts/release.sh` does the actual build → sign → notarize → staple →
  DMG work. This skill does not replace that script; it wraps it with the
  version bump before and the shipping steps after.
- `~/sites/personal-projects/harps-website` — the marketing site.
  `downloads/Harps.dmg` is the one stable download link both `index.html`
  CTAs point at (do not rename it — that would break those links).
  `changelog.json` is a flat array the `changelog.html` page renders
  directly; each entry is `{ version, date, highlights: [...] }`, newest
  first.

## Steps

1. **Decide the version.** Look at the current `MARKETING_VERSION` in
   `app/project.yml` and at the most recent entry in
   `harps-website/changelog.json` (they should already agree — if they
   don't, something went wrong in a prior run; reconcile before continuing).
   Bump per semver-ish judgment based on what actually shipped since last
   time: a new user-facing feature → bump the minor (0.2 → 0.3); pure bug
   fixes/polish → bump the patch if you're using three-part versions, or
   still the minor if the project has stayed at two-part so far (check
   what's already there and stay consistent with it rather than switching
   schemes mid-project). Ask the user only if the right bump is genuinely
   ambiguous (e.g. it's unclear whether something was a fix or a feature).

2. **Bump the version** in `app/project.yml`:
   `MARKETING_VERSION` (e.g. `"0.2"`) and `CURRENT_PROJECT_VERSION` (a plain
   incrementing build number, e.g. `"2"`). `Harps/Info.plist` reads these
   via `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)` — never hardcode
   a version string directly into the plist again; that's the bug that
   originally motivated writing this skill (the plist silently held a
   stale `"0.1"` while `project.yml` said something else).

3. **Run the release script**: `cd app && ./scripts/release.sh`. This
   builds Release, re-signs with a secure timestamp (retrying on Apple's
   occasionally-flaky timestamp server — already handled inside the
   script), notarizes, staples, and produces `app/build/Harps.dmg` with its
   *mounted volume name* set to `Harps <version>` (e.g. "Harps 0.2") —
   pulled straight from the built `Info.plist`, so it can't drift from step
   2. The DMG's filename on disk stays plain `Harps.dmg`; only the volume
   label carries the version. Takes several minutes (notarization is a
   real network round-trip to Apple) — this is a foreground wait, not
   something to background and poll.

4. **Sanity-check before shipping** (the script prints these commands,
   but actually run them):
   ```
   spctl -a -vv --type execute "app/build/Harps.app"
   spctl -a -vv --type open --context context:primary-signature "app/build/Harps.dmg"
   ```
   Both should say `accepted`. Don't ship a DMG that fails either check.

5. **Copy the DMG into the website repo**, overwriting the stable path:
   ```
   cp app/build/Harps.dmg ../harps-website/downloads/Harps.dmg
   ```

6. **Add a changelog entry** to `harps-website/changelog.json` — prepend
   (newest-first) an object with the version from step 2, today's date
   (`YYYY-MM-DD`), and 3-6 `highlights` written for an end user, not a
   commit log: plain language, no file names or internal component names,
   one sentence per shipped user-facing thing. Skip pure refactors/internal
   fixes that changed nothing the user would notice — the changelog is a
   marketing surface, not a commit history. Look at what actually shipped
   since the last version (recent conversation context, or `git log` in
   `app/` since the last version-bump commit, is the source of truth for
   this — don't guess).

7. **Commit and push the app repo**:
   ```
   cd app
   git add project.yml Harps/Info.plist scripts/release.sh   # plus any feature files from this session, if not already committed
   git commit -m "Bump to v<version>: <one-line summary of what shipped>"
   git push
   ```
   If there's other uncommitted feature work from the same session that
   this release is packaging up, it belongs in this commit (or its own
   preceding commit) — don't ship a DMG built from code that was never
   committed.

8. **Commit and push the website repo**:
   ```
   cd ../harps-website
   git add downloads/Harps.dmg changelog.json
   git commit -m "Ship Harps v<version>"
   git push
   ```
   Pushing this repo triggers its normal Vercel deploy — nothing extra to
   do for that.

9. **Confirm to the user** what shipped: the version, a one-line summary of
   the changelog highlights, and that both repos are pushed (link to the
   live changelog page if you know the deployed URL).

## Things that have gone wrong before, worth checking

- The static `Info.plist` used to hardcode `CFBundleShortVersionString`
  directly, completely ignoring `project.yml`'s `MARKETING_VERSION` build
  setting (since `GENERATE_INFOPLIST_FILE` is `NO`, Xcode uses the plist
  file verbatim rather than synthesizing one from build settings). If a
  built DMG's volume name ever doesn't match the version you just set in
  `project.yml`, check that the plist still uses `$(MARKETING_VERSION)`
  and hasn't regressed to a literal string.
- `codesign --timestamp` against Apple's timestamp-authority server fails
  intermittently (observed multiple times in a single session) — the
  script already retries this automatically for both the app and the DMG.
  If it still fails after 5 attempts, it's a real problem (network down,
  Apple's service actually down), not something to work around further —
  tell the user rather than looping longer.
- `create-dmg` sometimes exits non-zero even when it actually produced a
  correct DMG (a Finder-scripting quirk) — the script already checks for
  the output file's existence rather than trusting the exit code, so don't
  treat a non-zero `create-dmg` exit alone as a failure.
