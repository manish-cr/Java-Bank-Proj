# ============================================================================
# NexusBank Engine - Dockerfile
# Multi-stage build for a slim production image.
# ============================================================================

# ---- Stage 1: Build ----
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

RUN mvn clean package -DskipTests -q

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Create non-root user
RUN addgroup --system app && adduser --system --ingroup app app

# Copy the JAR from builder stage
COPY --from=builder /app/target/*.jar app.jar

# Use non-root user
USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/api/v1/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
