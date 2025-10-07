import de.undercouch.gradle.tasks.download.Download
import org.gradle.jvm.toolchain.JavaLanguageVersion

plugins {
    java
    base
    id("de.undercouch.download") version "5.5.0"
}

val javaVersion = (project.findProperty("javaVersion") as String?)?.toInt() ?: 17

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(javaVersion))
    }
}

val dockerContext = layout.projectDirectory.dir("docker")
val downloadsDir = dockerContext.dir("artifacts")

val otelAgentUrl: String by project
val keytabGeneratorUrl: String by project
val connectorArtifactUrls: List<String> =
    (project.findProperty("connectorArtifactUrls") as String?)
        ?.split(",")
        ?.map { it.trim() }
        ?.filter { it.isNotEmpty() }
        ?: emptyList()

fun registerDownloadTask(name: String, urlProvider: () -> String, outputName: String) =
    tasks.register<Download>(name) {
        src(urlProvider())
        dest(downloadsDir.file(outputName))
        onlyIfModified(true)
    }

val downloadOtelAgent = registerDownloadTask("downloadOtelAgent", { otelAgentUrl }, "opentelemetry-javaagent.jar")
val downloadKeytabGenerator = registerDownloadTask("downloadKeytabGenerator", { keytabGeneratorUrl }, "keytab-generator.jar")

val downloadConnectorArtifacts = connectorArtifactUrls.mapIndexed { index, url ->
    tasks.register<Download>("downloadConnectorArtifact${index + 1}") {
        src(url)
        val fileName = url.substringAfterLast('/')
        dest(downloadsDir.file(fileName))
        onlyIfModified(true)
    }
}

tasks.register("prepareDockerArtifacts") {
    group = "distribution"
    description = "Downloads the agent, keytab generator, and connector JARs into the docker context."
    outputs.dir(downloadsDir)

    dependsOn(downloadOtelAgent)
    dependsOn(downloadKeytabGenerator)
    downloadConnectorArtifacts.forEach { dependsOn(it) }

    doFirst {
        downloadsDir.asFile.mkdirs()
    }
}

artifacts.add("default", downloadsDir.asFile)
