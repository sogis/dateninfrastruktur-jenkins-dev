# syntax=docker/dockerfile:1
ARG JENKINS_IMAGE=jenkins/jenkins:2.555.2-lts-jdk21@sha256:01c992ffef29dcf41c7164e8c16285c657c2368c4943dda8d68c93fdf54447d5
FROM gradle:9.5.1-jdk25 AS gretl_dist
WORKDIR /build
COPY gretl-dist.gradle build.gradle
RUN --mount=type=cache,target=/home/gradle/.gradle \
    gradle --no-daemon --refresh-dependencies installGretl && \
    mv build/gretl/gretl-runtime-* /opt/gretl && \
    chmod 0755 /opt/gretl/bin/gretl && /opt/gretl/bin/gretl --version

FROM eclipse-temurin:25-jre AS gretl_java
FROM ${JENKINS_IMAGE}
ARG IMAGE_VERSION=local
LABEL org.opencontainers.image.title="dateninfrastruktur-jenkins" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      io.dateninfrastruktur.gretl.version="6.0.0-SNAPSHOT"
USER root
ENV TZ=Europe/Zurich \
    GRETL_JAVA_HOME=/opt/java/gretl \
    JENKINS_JAVA_OPTS=-Djenkins.install.runSetupWizard=false
COPY --from=gretl_java /opt/java/openjdk /opt/java/gretl
COPY --from=gretl_dist /opt/gretl /opt/gretl
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY oidc-plugin.sha256 /opt/dateninfrastruktur/oidc-plugin.sha256
USER jenkins
RUN jenkins-plugin-cli --latest=false --plugin-file /usr/share/jenkins/ref/plugins.txt && cd /usr/share/jenkins/ref/plugins && sha256sum -c /opt/dateninfrastruktur/oidc-plugin.sha256 && mv oic-auth.jpi oic-auth.jpi.override
USER root
COPY --chown=root:root jobs/csv-delivery /opt/dateninfrastruktur/csv-delivery
COPY --chown=root:root jenkins.yaml /usr/share/jenkins/ref/casc_configs/jenkins.yaml
COPY --chown=root:root --chmod=0755 docker-entrypoint.sh /usr/local/bin/di-jenkins-entrypoint.sh
COPY --chown=jenkins:jenkins delivery.jpi /usr/share/jenkins/ref/plugins/jenkins-gretl-dateninfrastruktur-plugin.jpi.override
USER jenkins
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc_configs/jenkins.yaml
ENTRYPOINT ["/usr/local/bin/di-jenkins-entrypoint.sh"]
