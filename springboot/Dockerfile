# ---------- Build Stage ----------
FROM eclipse-temurin:25-jdk-jammy AS build
WORKDIR /workspace
ENV GRADLE_USER_HOME=/workspace/.gradle

# wrapper/설정 먼저 복사(핵심)
COPY gradlew ./
COPY gradle/wrapper/ ./gradle/wrapper/
COPY settings.gradle* build.gradle* gradle/ ./
RUN chmod +x gradlew

# 의존성 캐시(소스 없이)
RUN ./gradlew --no-daemon build -x test || true

# 실제 소스
COPY src ./src
RUN ./gradlew --no-daemon clean bootJar

# ---------- Runtime Stage ----------
FROM eclipse-temurin:25-jre-jammy
WORKDIR /app
COPY --from=build /workspace/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
