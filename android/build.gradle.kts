allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
  // ...

  // Add the dependency for the Google services Gradle plugin
  classpath 'com.google.gms:google-services:4.3.15' // versi terbaru


}


val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
