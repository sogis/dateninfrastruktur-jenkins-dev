# syntax=docker/dockerfile:1
ARG JENKINS_IMAGE=jenkins/jenkins:2.555.2-lts-jdk21@sha256:01c992ffef29dcf41c7164e8c16285c657c2368c4943dda8d68c93fdf54447d5
FROM gradle:7.6.4-jdk17@sha256:0aa0a8521188366a1426ee5f3f13df5bac48184b5f6e7a21ddbfa495efb4e611 AS gretl_toolchain
ARG GRETL_VERSION
ARG GRETL_SHA256
ENV DUCKDB_EXTENSION_DIRECTORY=/bundle/duckdb-extensions
WORKDIR /build
COPY gretl-bundle.gradle build.gradle
RUN --mount=type=cache,target=/home/gradle/.gradle \
    set -eu; \
    gradle --no-daemon -PgretlVersion="$GRETL_VERSION" bundle; \
    cd /bundle/jars; \
    jar="$(find . -maxdepth 1 -name 'gretl-core-*.jar')"; \
    test -f "$jar"; \
    printf '%s  %s\n' "$GRETL_SHA256" "$jar" | sha256sum -c -; \
    LC_ALL=C sha256sum ./*.jar > /bundle/toolchain-jars.sha256; \
    java -cp '/bundle/jars/*' ch.so.agi.gretl.internal.duckdb.DuckDbExtensionInstaller postgres spatial excel httpfs; \
    cd /bundle/duckdb-extensions; \
    find . -type f -name '*.duckdb_extension' | LC_ALL=C sort | xargs sha256sum > /bundle/duckdb-extensions.sha256; \
    for extension in postgres_scanner spatial excel httpfs; do \
        grep -q "/$extension.duckdb_extension$" /bundle/duckdb-extensions.sha256 || { cat /bundle/duckdb-extensions.sha256; exit 1; }; \
    done
FROM rclone/rclone:1.75.2@sha256:2687085f718d3c628f7fdfb77c52a1d344332aed543110bb88088f2c70d43eb5 AS rclone_binary
FROM ${JENKINS_IMAGE}
ARG IMAGE_VERSION=local
ARG PLUGIN_VERSION=0.2.0-SNAPSHOT
ARG GRETL_VERSION=5.0.0-SNAPSHOT
ARG THEMEN_REPO_REVISION
ARG PLUGIN_REPO_REVISION
ARG PLUGIN_HPI_SHA256
LABEL org.opencontainers.image.title="dateninfrastruktur-jenkins" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      io.dateninfrastruktur.delivery.provenance="1" \
      io.dateninfrastruktur.plugin.version="${PLUGIN_VERSION}" \
      io.dateninfrastruktur.plugin.sha256="${PLUGIN_HPI_SHA256}" \
      io.dateninfrastruktur.gretl.version="${GRETL_VERSION}" \
      io.dateninfrastruktur.themenrepo.revision="${THEMEN_REPO_REVISION}" \
      io.dateninfrastruktur.plugin.revision="${PLUGIN_REPO_REVISION}"
USER root
ENV TZ=Europe/Zurich \
    DUCKDB_EXTENSION_DIRECTORY=/opt/dateninfrastruktur/duckdb-extensions \
    DI_CSV_BUNDLE_ROOT=/opt/dateninfrastruktur/runner-bundle \
    DATENINFRASTRUKTUR_OFFLINE_JARS_DIR=/opt/dateninfrastruktur/offline-bundle/jars \
    GRADLE_JAVA_HOME_17=/opt/java/openjdk17 \
    JENKINS_JAVA_OPTS=-Djenkins.install.runSetupWizard=false
# Copy only the verified tools. No legacy Jenkins home, plugin, script or JCasC is inherited.
COPY --from=gretl_toolchain /opt/java/openjdk /opt/java/openjdk17
COPY --from=rclone_binary /usr/local/bin/rclone /usr/local/bin/di-rclone
COPY --from=gretl_toolchain /opt/gradle /opt/dateninfrastruktur/gradle
COPY --from=gretl_toolchain /bundle/jars /opt/dateninfrastruktur/offline-bundle/jars
COPY --from=gretl_toolchain /bundle/duckdb-extensions /opt/dateninfrastruktur/duckdb-extensions
COPY --from=gretl_toolchain /bundle/*.sha256 /opt/dateninfrastruktur/
RUN cd /opt/dateninfrastruktur/offline-bundle/jars && sha256sum -c /opt/dateninfrastruktur/toolchain-jars.sha256 && \
    cd /opt/dateninfrastruktur/duckdb-extensions && sha256sum -c /opt/dateninfrastruktur/duckdb-extensions.sha256 && \
    /opt/java/openjdk17/bin/java -version && \
    chown -R root:root /opt/dateninfrastruktur && chmod -R a+rX,a-w /opt/dateninfrastruktur
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
COPY oidc-plugin.sha256 /opt/dateninfrastruktur/oidc-plugin.sha256
USER jenkins
RUN jenkins-plugin-cli --latest=false --plugin-file /usr/share/jenkins/ref/plugins.txt && cd /usr/share/jenkins/ref/plugins && sha256sum -c /opt/dateninfrastruktur/oidc-plugin.sha256 && mv oic-auth.jpi oic-auth.jpi.override
USER root
COPY --chown=root:root --chmod=0444 runner-provenance.json /opt/dateninfrastruktur/runner-provenance.json
COPY --chown=root:root runner-bundle/ /opt/dateninfrastruktur/runner-bundle/
COPY --chown=root:root jenkins.yaml /usr/share/jenkins/ref/casc_configs/jenkins.yaml
COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/di-jenkins-entrypoint.sh
COPY --chown=jenkins:jenkins delivery.jpi /usr/share/jenkins/ref/plugins/jenkins-gretl-dateninfrastruktur-plugin.jpi.override
RUN chmod 0755 /usr/local/bin/di-jenkins-entrypoint.sh && chmod -R a+rX,a-w /opt/dateninfrastruktur/runner-bundle && \
    printf '%s  %s\n' "$PLUGIN_HPI_SHA256" /usr/share/jenkins/ref/plugins/jenkins-gretl-dateninfrastruktur-plugin.jpi.override | sha256sum -c -
USER jenkins
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/ref/casc_configs/jenkins.yaml
ENTRYPOINT ["/usr/local/bin/di-jenkins-entrypoint.sh"]
