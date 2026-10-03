#!/usr/bin/env bash
# Build and test the Spring Boot 3 project (Maven or Gradle), using H2 for tests.
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Java version"
java -version 2>&1 | head -n 1

if [[ -f "mvnw" ]]; then
  chmod +x mvnw
  BUILD="./mvnw -B"
  TOOL=maven
elif [[ -f "pom.xml" ]]; then
  BUILD="mvn -B"
  TOOL=maven
elif [[ -f "gradlew" ]]; then
  chmod +x gradlew
  BUILD="./gradlew"
  TOOL=gradle
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  BUILD="gradle"
  TOOL=gradle
else
  echo "ERROR: no pom.xml or build.gradle found in $(pwd)" >&2
  exit 1
fi

echo "==> Using $TOOL"

if [[ "$TOOL" == "maven" ]]; then
  # Pass a single test class as the first argument, e.g. ./run.sh PersonServiceTest
  if [[ $# -gt 0 ]]; then
    $BUILD clean test -Dtest="$1"
  else
    $BUILD clean test
  fi
else
  if [[ $# -gt 0 ]]; then
    $BUILD clean test --tests "*$1"
  else
    $BUILD clean test
  fi
fi

echo "==> All tests passed"
