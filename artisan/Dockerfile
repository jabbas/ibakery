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
    flutter build web --release --base-href=${BASE_HREF}

# Production stage
FROM joseluisq/static-web-server:2

ARG BASE_HREF=/
ENV SERVER_FALLBACK_PAGE=/public${BASE_HREF}index.html

# Copy to subdirectory matching BASE_HREF
COPY --from=build /app/build/web /public${BASE_HREF}

EXPOSE 8080

ENTRYPOINT ["/static-web-server"]
CMD ["-p", "8080", "-d", "/public"]
