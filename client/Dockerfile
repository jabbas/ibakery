# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG BASE_HREF=/

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,target=/root/.pub-cache \
    flutter pub get

COPY . .
RUN --mount=type=cache,target=/root/.pub-cache \
    --mount=type=cache,target=/app/.dart_tool \
    flutter build web --release --pwa-strategy none --base-href=${BASE_HREF}

# Production stage
FROM joseluisq/static-web-server:2

COPY --from=build /app/build/web /public

EXPOSE 8080

CMD ["-p", "8080", "-d", "/public", "--page-fallback", "/public/index.html"]
