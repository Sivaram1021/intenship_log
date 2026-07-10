plugins {
    // Add the dependency for the Google services Gradle plugin
    id("com.google.gms.google-services") version "4.5.0" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    // Declares that subprojects depend on :app being evaluated first
    project.evaluationDependsOn(":app")

    // Define the lambda configuration to force SDK 36 compilation targets
    val configureAndroid: Project.() -> Unit = {
        if (plugins.hasPlugin("com.android.application") ||
            plugins.hasPlugin("com.android.library")
        ) {
            try {
                extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                    compileSdkVersion(36)
                }
            } catch (e: Exception) {
                // Safely falls back if the configuration block cannot resolve BaseExtension
                logger.warn("Could not force compileSdkVersion on project ${project.name}: ${e.message}")
            }
        }
    }

    // SAFE EXECUTION CHECK: If the project was already evaluated via evaluationDependsOn,
    // execute configuration immediately. Otherwise, register afterEvaluate.
    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}