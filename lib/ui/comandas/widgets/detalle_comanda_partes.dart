// lib/ui/comandas/widgets/detalle_comanda_partes.dart
//
// Piezas del detalle de una comanda (#128): secciones, tarjeta de pastel con
// la leyenda resaltada, productos, caja de cambios, firmas de producción,
// barra y diálogo de «Enterado» y visor de fotos a pantalla completa.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pier_pasteleria/domain/models/comanda.dart';
import 'package:pier_pasteleria/ui/comandas/widgets/agenda_comandas_partes.dart';
import 'package:pier_pasteleria/ui/core/themes/app_colors.dart';

const _ambar = Color(0xFFB45309);

/// Sección con ícono y título.
class SeccionDetalle extends StatelessWidget {
  const SeccionDetalle({
    required this.titulo,
    required this.icono,
    required this.children,
    super.key,
  });

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: AppColors.pierVerde),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// Etiqueta pequeña y su valor («Sin especificar» si no se indicó).
class DatoComanda extends StatelessWidget {
  const DatoComanda(this.etiqueta, this.valor, {super.key});

  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        etiqueta,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      Text(
        valor ?? 'Sin especificar',
        style: TextStyle(
          fontWeight: valor == null ? FontWeight.normal : FontWeight.w600,
          color: valor == null
              ? AppColors.textSecondary
              : AppColors.textPrimary,
        ),
      ),
    ],
  );
}

/// Bloque de texto libre (descripción, insumos, indicaciones, notas).
class BloqueTexto extends StatelessWidget {
  const BloqueTexto(this.titulo, this.texto, {super.key});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: DatoComanda(titulo, texto),
  );
}

/// Pastel [numero] de la comanda: leyenda resaltada (se escribe tal cual) y
/// sus datos.
class TarjetaPastel extends StatelessWidget {
  const TarjetaPastel(this.pastel, this.numero, {super.key});

  final RenglonComanda pastel;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final p = pastel;
    final pisos = p.numPisos;
    final datos = <(String, String?)>[
      ('Sabor', p.sabor),
      ('Tamaño', p.tamano),
      ('Forma', p.forma),
      (
        'Pisos',
        pisos == null ? null : (pisos == 1 ? '1 piso' : '$pisos pisos'),
      ),
      ('Decoración', p.decoracion),
      ('Pared o fondo', p.colorFondo),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pierArena.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PASTEL $numero',
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      p.nombre,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '× ${p.cantidad}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (p.leyenda case final leyenda?)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.quote, size: 13, color: _ambar),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'LEYENDA · ESCRIBIR TAL CUAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _ambar,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leyenda,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              for (final (etiqueta, valor) in datos)
                SizedBox(width: 130, child: DatoComanda(etiqueta, valor)),
            ],
          ),
          if (p.descripcion case final d?) BloqueTexto('Descripción', d),
          if (p.insumos case final i?) BloqueTexto('Insumos', i),
        ],
      ),
    );
  }
}

/// Producto del catálogo: nombre, cantidad · tamaño e indicaciones.
class RenglonProducto extends StatelessWidget {
  const RenglonProducto(this.producto, {super.key});

  final RenglonComanda producto;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            [
              '× ${p.cantidad}',
              ?p.tamanoCatalogo,
            ].join(' · '),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (p.indicaciones case final i?)
            Text(i, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/// Caja ámbar con los cambios que hay que revisar antes de confirmar.
class CajaCambios extends StatelessWidget {
  const CajaCambios({
    required this.titulo,
    required this.texto,
    required this.cambios,
    this.alCerrar,
    super.key,
  });

  final String titulo;
  final String texto;
  final List<CambioCampo> cambios;
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFCD34D)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.rotateCw, size: 18, color: _ambar),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _ambar,
                ),
              ),
            ),
            if (alCerrar != null)
              IconButton(
                tooltip: 'Ocultar cambios',
                visualDensity: VisualDensity.compact,
                onPressed: alCerrar,
                icon: const Icon(LucideIcons.x, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(texto, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        ListaCambios(cambios),
      ],
    ),
  );
}

/// Cada cambio en su renglón: «Campo: antes → después».
class ListaCambios extends StatelessWidget {
  const ListaCambios(this.cambios, {super.key});

  final List<CambioCampo> cambios;

  @override
  Widget build(BuildContext context) => cambios.isEmpty
      ? const Text(
          'No hay detalle de los cambios.',
          style: TextStyle(color: AppColors.textSecondary),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in cambios)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  c.texto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
}

/// Firma de un área: estado y quién confirmó qué versión.
class FirmaProduccion extends StatelessWidget {
  const FirmaProduccion({required this.area, required this.firma, super.key});

  final AreaProduccion area;
  final FirmaArea firma;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipFirma(area: area, firma: firma),
        if (firma.usuarioNombre case final nombre?)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Wrap(
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  ' · versión ${firma.version}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Barra inferior con el botón «Enterado» del color de mi área.
class BarraEnterado extends StatelessWidget {
  const BarraEnterado({
    required this.area,
    required this.refirma,
    required this.corriendo,
    required this.alTocar,
    super.key,
  });

  final AreaProduccion area;
  final bool refirma;
  final bool corriendo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                refirma
                    ? 'Cambió: revisa los cambios y vuelve a confirmar'
                    : 'Al terminar de leerla, confirma',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: corriendo ? null : alTocar,
              style: FilledButton.styleFrom(
                backgroundColor: area.color,
                minimumSize: const Size(0, 48),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (corriendo)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(LucideIcons.circleCheck, size: 18),
                  const SizedBox(width: 8),
                  const Text('Enterado'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Diálogo irreversible del «Enterado». El foco empieza en «Volver»:
/// confirmar debe ser una decisión. Devuelve true si confirmó.
Future<bool> confirmarEnterado(
  BuildContext context, {
  required int folio,
  required int version,
  required List<CambioCampo> cambios,
}) async {
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Confirmas de enterado?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Confirmo que leí la comanda #$folio '
                        '(versión $version). ',
                  ),
                  const TextSpan(
                    text: 'Esta acción no se puede deshacer.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            if (cambios.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                cambios.length == 1
                    ? 'Confirmas también este cambio:'
                    : 'Confirmas también estos ${cambios.length} cambios:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _ambar,
                ),
              ),
              const SizedBox(height: 6),
              ListaCambios(cambios),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sí, enterado'),
        ),
      ],
    ),
  );
  return si ?? false;
}

/// Miniaturas de las imágenes de referencia; tocar una la abre completa.
class GaleriaComanda extends StatelessWidget {
  const GaleriaComanda(this.urls, {super.key});

  final List<String> urls;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    children: [
      for (final (i, url) in urls.indexed)
        GestureDetector(
          key: ValueKey('foto-$i'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => VisorImagenes(urls: urls, inicial: i),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _Imagen(url, ajuste: BoxFit.cover),
          ),
        ),
    ],
  );
}

/// Fotos a pantalla completa, deslizables y con zoom.
class VisorImagenes extends StatefulWidget {
  const VisorImagenes({required this.urls, this.inicial = 0, super.key});

  final List<String> urls;
  final int inicial;

  @override
  State<VisorImagenes> createState() => _VisorImagenesState();
}

class _VisorImagenesState extends State<VisorImagenes> {
  late int _actual = widget.inicial;
  late final _paginas = PageController(initialPage: widget.inicial);

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Cerrar',
        icon: const Icon(LucideIcons.x),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('${_actual + 1} de ${widget.urls.length}'),
    ),
    body: PageView(
      controller: _paginas,
      onPageChanged: (i) => setState(() => _actual = i),
      children: [
        for (final url in widget.urls)
          InteractiveViewer(
            maxScale: 5,
            child: Center(child: _Imagen(url, ajuste: BoxFit.contain)),
          ),
      ],
    ),
  );
}

class _Imagen extends StatelessWidget {
  const _Imagen(this.url, {required this.ajuste});

  final String url;
  final BoxFit ajuste;

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: ajuste,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFE5E7EB),
      child: Center(
        child: Icon(LucideIcons.imageOff, color: AppColors.textSecondary),
      ),
    ),
  );
}
