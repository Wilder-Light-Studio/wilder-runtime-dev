# Dockerfile — Reproducible build environment for the Wilder Cosmos Runtime.
# Summary: Provides a deterministic, self-contained build environment using
#   the official Nim Docker image. No internet access required after build.
# Simile: Like sealing a recipe box — everything needed to compile and test
#   is locked inside this container.
# Memory note: build args pin the Nim version; change NIM_VERSION to target
#   a different toolchain for Tier 1 compatibility testing.
# Flow: base image -> install deps -> copy source -> compile -> test.

ARG NIM_VERSION=2.2.6
FROM nimlang/nim:${NIM_VERSION}-alpine AS builder

LABEL maintainer="teamwilder@wildercode.org"
LABEL description="Wilder Cosmos Runtime build environment"
LABEL license="Wilder Foundation License 1.0"

WORKDIR /app

# Copy dependency manifest first for layer caching.
COPY wilder_cosmos_runtime.nimble nimble.paths ./

# Install nimble dependencies.
RUN nimble refresh --accept && nimble install --depsOnly --accept

# Copy full source tree.
COPY . .

# Compile-check all tests (Application Control is not a concern inside Docker).
RUN nim c --hints:off --warnings:on tests/lifecycle_test.nim \
 && nim c --hints:off --warnings:on tests/console_status_test.nim \
 && nim c --hints:off --warnings:on tests/module_test.nim \
 && nim c --hints:off --warnings:on tests/portability_test.nim \
 && nim c --hints:off --warnings:on tests/security_bench_test.nim \
 && nim c --hints:off --warnings:on tests/doc_compliance_test.nim

# Run tests.
FROM builder AS test
RUN nim c -r tests/lifecycle_test.nim \
 && nim c -r tests/console_status_test.nim \
 && nim c -r tests/module_test.nim \
 && nim c -r tests/portability_test.nim \
 && nim c -r tests/security_bench_test.nim \
 && nim c -r tests/doc_compliance_test.nim

# Final verification image.
FROM builder AS verify
RUN nimble verify
