// ១. ការកំណត់ផ្លូវ Repositories សម្រាប់គម្រោងទាំងមូល
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ២. ការរៀបចំកំណត់ផ្លូវថត Build Directory ឡើងវិញ (ស្ដង់ដារ Flutter)
val newBuildDir: Directory = rootProject.layout.buildDirectory
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

// ៣. បញ្ជាសម្អាត (Clean Task)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}