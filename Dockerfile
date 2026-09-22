# ---------------------------------------------------------------------------
# Multi-stage Dockerfile for a Java/Maven Spring Boot app
# Stage 1 → Build the .jar with Maven
# Stage 2 → Minimal runtime image (no Maven, no source code)
# ---------------------------------------------------------------------------

# ---- Stage 1: Build -------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# Copy pom.xml first — Docker layer cache means dependencies are only
# re-downloaded when pom.xml actually changes, not on every code change.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Now copy source and build
COPY src ./src
RUN mvn clean package -DskipTests

# ---- Stage 2: Runtime ------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Non-root user — good practice for production-like setups
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy only the built jar from the build stage
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
