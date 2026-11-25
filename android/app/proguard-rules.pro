# google_mlkit_text_recognition references the optional Chinese, Devanagari,
# Japanese and Korean recognisers. The app bundles only the Latin one, so R8
# must not fail on the missing classes (receipt scan uses Latin script).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
