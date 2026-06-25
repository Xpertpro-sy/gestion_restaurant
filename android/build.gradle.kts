import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Plugins (e.g. printing) may ship with a low compileSdk; force a modern SDK
// so resource linking succeeds (android:attr/lStar requires API 31+).
subprojects {
    afterEvaluate {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
        }
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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
