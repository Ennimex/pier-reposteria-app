// test/helpers/montar_actividad.dart — monta «Actividad del equipo» (#139)
// con la sesión de gerencia sobre el backend falso y con el reloj fijo de
// las pruebas en sus dos pestañas (con montarComandas: pantalla alta y
// router con login), y un atajo a la lista de cada pestaña.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pier_reposteria/data/repositories/actividad_repository_remote.dart';
import 'package:pier_reposteria/ui/actividad/view_model/actividad_equipo_view_model.dart';
import 'package:pier_reposteria/ui/actividad/view_model/bitacora_view_model.dart';
import 'package:pier_reposteria/ui/actividad/widgets/actividad_equipo_screen.dart';

import '../fakes/actividad_json.dart';
import '../fakes/fake_api_client.dart';
import 'montar_comandas.dart';

Future<void> montarActividad(WidgetTester tester, FakeApiClient api) {
  final repo = ActividadRepositoryRemote(api: api);
  return montarComandas(
    tester,
    api,
    pantalla: ActividadEquipoScreen(
      equipo: ActividadEquipoViewModel(repo: repo, ahora: ahoraActividad),
      bitacora: BitacoraViewModel(repo: repo, ahora: ahoraActividad),
    ),
    rol: 'gerencia',
  );
}

/// La lista de la pestaña [clave]: 'equipo' o 'bitacora'.
Finder listaDe(String clave) => find.byKey(PageStorageKey<String>(clave));
