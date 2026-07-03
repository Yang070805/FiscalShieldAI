allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // AGP 9.0 内置 Kotlin，但 file_picker 11.x 条件跳过了 Kotlin 插件
    // 在项目级强制对所有 Android 子项目应用 Kotlin 插件
    plugins.withId("com.android.library") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
    plugins.withId("com.android.application") {
        pluginManager.apply("org.jetbrains.kotlin.android")
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
