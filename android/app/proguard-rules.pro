# Reglas propias de R8 para el release de Pier (#224).
#
# Ya se aplican sin escribirlas aquí: proguard-android-optimize.txt (Android),
# flutter_proguard_rules.pro (las agrega el plugin de Flutter) y las reglas
# que trae cada librería (Stripe, Sentry, Google Sign-In, etc.). Aquí va solo
# lo que la app necesita además.

# Números de línea en los errores de Java/Kotlin: con el mapping de R8
# (build/app/outputs/mapping/prodRelease/mapping.txt) las trazas se pueden
# leer, sin publicar el nombre de los archivos fuente.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
