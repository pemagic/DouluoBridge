---
description: Automatically sync versions and trigger a cross-platform release
---

This workflow should be executed after any significant feature implementation or bug fix to ensure the iOS and Android versions remain in sync and the CI/CD pipeline is triggered.

1. **Verify Changes**: Ensure all code changes are verified and artifacts are updated.
2. **Update CHANGELOG.md**: Add a new version header `## [X.Y.Z] - TBD` with the summary of changes if not already present.
3. **Execute Release Script**:
// turbo
   Run `./scripts/release.sh [version]` to sync `project.pbxproj` and `build.gradle.kts`.
4. **Push to Remote**:
// turbo
   Run `git push origin main && git push origin v[version]` to trigger the GitHub Actions build.
5. **Verify CI**: Check the GitHub Actions tab (if possible) or wait for the release to appear.
