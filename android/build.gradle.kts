buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Plugin do Android
        classpath("com.android.tools.build:gradle:7.3.0")
        // Plugin do Kotlin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
        // Plugin do Google Services (necessário para Firebase)
        classpath("com.google.gms:google-services:4.4.2")
        // Plugin do Firebase Performance (se usar)
        classpath("com.google.firebase:perf-plugin:1.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Diretórios de build (mantive seu ajuste aqui)
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
