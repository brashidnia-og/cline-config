---
paths:
  - "**/*.kt"
  - "**/*.kts"
  - "**/*.java"
  - "**/build.gradle"
  - "**/build.gradle.kts"
  - "**/settings.gradle"
  - "**/settings.gradle.kts"
  - "**/gradle.properties"
  - "**/gradle/**"
---

# Gradle command policy

Prefer the repository wrapper `./gradlew` over a global Gradle installation.

Before unfamiliar tasks inspect `settings.gradle(.kts)`, `build.gradle(.kts)`, `gradle.properties`, version catalogs, `buildSrc/`, and custom build logic. Task names do not prove safety.

## Generally safe inspection
```bash
./gradlew help
./gradlew tasks
./gradlew projects
./gradlew properties
./gradlew dependencies
./gradlew dependencyInsight
./gradlew buildEnvironment
./gradlew :module:dependencies --configuration <name>
```
Scope to the relevant module/configuration when possible.

## Generally safe local validation after inspection
```bash
./gradlew :module:compileKotlin
./gradlew :module:compileJava
./gradlew :module:testClasses
./gradlew :module:test --tests 'com.example.MyTest'
./gradlew :module:test --tests 'com.example.MyTest.someBehavior'
./gradlew :module:test --tests 'com.example.MyTest' --info
./gradlew :module:check
```

Broader `./gradlew test` or `./gradlew check` is appropriate when risk/scope warrants it.

## Integration/custom tasks
Inspect `integrationTest`, `functionalTest`, `e2eTest`, or custom tasks before execution. Determine whether they start containers, run migrations, contact external services, use persistent databases, or require cloud credentials.

Disposable repository-owned Testcontainers are generally acceptable as part of approved tests.

## Not auto-approved
Do not automatically run tasks suggesting deploy/publish/release/upload/push/prod/migrate/seed/reset/drop/destroy/cloud/dockerPush or repository publishing. Do not add/update dependencies or plugin versions merely to make a build pass unless that change is part of the task.
