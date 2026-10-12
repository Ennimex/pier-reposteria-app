// Arranque de las pruebas de integration_test/ como prueba instrumentada de
// Android, para correrlas en Firebase Test Lab (#75). Ver tool/test_lab.md.
package com.example.pier_pasteleria;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  // Sin auto-lanzar: FlutterTestRunner abre la actividad por cada prueba.
  @Rule
  public ActivityTestRule<MainActivity> rule =
      new ActivityTestRule<>(MainActivity.class, true, false);
}
