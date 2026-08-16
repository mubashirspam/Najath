import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "com.najath.erp.dev"
            resValue(type = "string", name = "app_name", value = "Najath Dev")
        }
        create("staging") {
            dimension = "flavor-type"
            applicationId = "com.najath.erp.stg"
            resValue(type = "string", name = "app_name", value = "Najath Stg")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.najath.erp"
            resValue(type = "string", name = "app_name", value = "Najath")
        }
    }

    buildFeatures.resValues = true
}