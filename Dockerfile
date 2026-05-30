FROM amazoncorretto:17-alpine-jdk

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /usr/app

COPY --chown=appuser:appgroup ./target/java-maven-app-*.jar /app.jar

USER appuser

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]