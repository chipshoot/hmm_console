package com.pivotpointsol.hmm_console

import io.flutter.embedding.android.FlutterFragmentActivity

// The health plugin needs a ComponentActivity (it registers an activity
// result launcher); FlutterActivity is not one and crashes it at launch.
class MainActivity : FlutterFragmentActivity()
