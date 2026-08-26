# Firebase Auth / Google Sign-In (Fase 6, Bloque 5): las AAR de Firebase y
# Play Services ya traen sus propias reglas consumer-rules.pro empaquetadas,
# que R8 aplica automáticamente. Estas reglas cubren los casos donde eso no
# basta (clases de credenciales resueltas por reflection) y silencian
# warnings de clases opcionales que este proyecto no usa.
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
