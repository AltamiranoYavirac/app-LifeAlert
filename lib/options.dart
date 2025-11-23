import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'symptoms.dart';
import 'documents.dart';

class OptionsPage extends StatefulWidget {
  const OptionsPage({super.key});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  String? _conditionDiagnosis;
  String? _conditionSince;
  String? _insuranceCompany;
  String? _policyNumber;
  String? _insurancePhone;
  // Historial de alertas (se mantiene en memoria durante la sesión)
  // Cada alerta tiene: id, datetime, location (opcional), description, status
  final List<Map<String, dynamic>> _alerts = [
    {
      'id': 1,
      'datetime': DateTime.now().subtract(const Duration(days: 1, hours: 3)),
        'location': 'Casa',
        'latitude': null,
        'longitude': null,
      'description': 'Dolor en el pecho y mareo',
      'status': 'Resuelto',
    },
    {
      'id': 2,
      'datetime': DateTime.now().subtract(const Duration(days: 3, hours: 5)),
        'location': 'Trabajo',
        'latitude': null,
        'longitude': null,
      'description': 'Caída leve, sin heridas aparentes',
      'status': 'Falsa alarma',
    },
  ];

  int _nextAlertId = 3;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _loadInsurance();
  }

  // Método público para añadir una alerta (útil para que `main.dart` llame cuando se pulse el botón rojo)
  Future<void> addAlert({required DateTime datetime, String? location, required String description, String status = 'Alerta'}) async {
    String finalLocation = location ?? '';
    double? finalLat;
    double? finalLon;
    // If no location provided, request permission and capture coordinates (best-effort)
    if (finalLocation.isEmpty) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          // Location services disabled
          await _showPermissionDeniedDialog();
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
            // Permission denied by system
            await _showPermissionDeniedDialog();
          } else {
            Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
            finalLocation = 'Lat:${pos.latitude.toStringAsFixed(5)}, Lon:${pos.longitude.toStringAsFixed(5)}';
            finalLat = pos.latitude;
            finalLon = pos.longitude;
          }
        }
      } catch (e) {
        // Ignore errors and continue without location
      }
    }

    setState(() {
      _alerts.insert(0, {
        'id': _nextAlertId++,
        'datetime': datetime,
        'location': finalLocation,
        'latitude': finalLat,
        'longitude': finalLon,
        'description': description,
        'status': status,
      });
    });

    await _saveAlerts();
  }

  

  // Si el permiso del sistema fue denegado, mostrar diálogo con opción de abrir ajustes
  Future<void> _showPermissionDeniedDialog() async {
    final bool? open = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Permiso denegado'),
          content: const Text('El permiso para acceder a la ubicación fue denegado. Puedes abrir los ajustes de la aplicación para habilitarlo.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Continuar sin ubicación')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Abrir ajustes')),
          ],
        );
      },
    );

    if (open == true) {
      try {
        await Geolocator.openAppSettings();
      } catch (e) {
        // ignore errors opening settings
      }
      // Inform the user to try again after enabling permission
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abriendo ajustes. Vuelve a intentar la alerta después de habilitar el permiso.')));
    }
  }

  // Persistir alertas en SharedPreferences
  Future<void> _saveAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serializable = _alerts.map((a) => {
            'id': a['id'],
            'datetime': (a['datetime'] as DateTime).toIso8601String(),
            'location': a['location'],
            'latitude': a['latitude'],
            'longitude': a['longitude'],
            'description': a['description'],
            'status': a['status'],
          }).toList();
      await prefs.setString('alerts', jsonEncode(serializable));
      await prefs.setInt('nextAlertId', _nextAlertId);
    } catch (e) {
      // ignore errors silently (best-effort persistence)
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('alerts');
      final int? savedNext = prefs.getInt('nextAlertId');
      if (data != null) {
        final List<dynamic> list = jsonDecode(data);
        setState(() {
          _alerts.clear();
          for (var item in list) {
            _alerts.add({
              'id': item['id'] as int,
              'datetime': DateTime.parse(item['datetime'] as String),
              'location': item['location'] as String,
              'latitude': (item['latitude'] as num?)?.toDouble(),
              'longitude': (item['longitude'] as num?)?.toDouble(),
              'description': item['description'] as String,
              'status': item['status'] as String,
            });
          }
          if (savedNext != null) {
            _nextAlertId = savedNext;
          } else {
            _nextAlertId = _alerts.isEmpty ? 1 : (_alerts.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
          }
        });
      } else {
        if (savedNext != null) _nextAlertId = savedNext;
      }
    } catch (e) {
      // ignore
    }
  }

  // Cargar información de seguro desde SharedPreferences
  Future<void> _loadInsurance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _insuranceCompany = prefs.getString('insuranceCompany');
        _policyNumber = prefs.getString('insurancePolicy');
        _insurancePhone = prefs.getString('insurancePhone');
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveInsurance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_insuranceCompany != null) await prefs.setString('insuranceCompany', _insuranceCompany!);
      if (_policyNumber != null) await prefs.setString('insurancePolicy', _policyNumber!);
      if (_insurancePhone != null) await prefs.setString('insurancePhone', _insurancePhone!);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _clearInsurance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('insuranceCompany');
      await prefs.remove('insurancePolicy');
      await prefs.remove('insurancePhone');
    } catch (e) {
      // ignore
    }
    setState(() {
      _insuranceCompany = null;
      _policyNumber = null;
      _insurancePhone = null;
    });
  }

  void _openDetail(BuildContext context, String title) async {
    // Show custom dialogs for the first three medical info cards
    if (title == 'Condición médica') {
      final result = await _showConditionDialog(context, initialDiagnosis: _conditionDiagnosis, initialSince: _conditionSince);
      if (result != null) {
        setState(() {
          _conditionDiagnosis = result['diagnosis'];
          _conditionSince = result['since'];
        });
      }
      return;
    }
    if (title == 'Medicamentos') {
      _showMedicationsDialog(context);
      return;
    }
    if (title == 'Citas médicas') {
      _showAppointmentsDialog(context);
      return;
    }
    if (title == 'Historial de alertas') {
      _showAlertHistoryDialog(context);
      return;
    }
    if (title == 'Alergias') {
      _showAllergiesDialog(context);
      return;
    }

    if (title == 'Información de seguro') {
      await _showInsuranceDialog(context);
      return;
    }

    if (title == 'Documentos médicos') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DocumentsPage()));
      return;
    }

    if (title == 'Registro de síntomas') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SymptomsPage()));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailPage(title: title)),
    );
  }

  Future<Map<String, String>?> _showConditionDialog(BuildContext context, {String? initialDiagnosis, String? initialSince}) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final TextEditingController diagnosisController = TextEditingController(text: initialDiagnosis ?? '');
        final TextEditingController sinceController = TextEditingController(text: initialSince ?? '');
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Condición Médica'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Describe tu condición médica principal', style: TextStyle(color: Theme.of(ctx).textTheme.bodySmall?.color)),
                const SizedBox(height: 16),
                TextField(
                  controller: diagnosisController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe tu condición médica...',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Desde', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: sinceController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'dd/mm/aaaa',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      sinceController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                    }
                  },
                ),
              ],
            ),
          ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () {
                // Here you would save the data, use controllers
                // Return the entered values to the caller (could be persisted)
                Navigator.of(ctx).pop({
                  'diagnosis': diagnosisController.text.trim(),
                  'since': sinceController.text.trim(),
                });
              }, child: const Text('Guardar')),
            ],
        );
      },
    );
  }

  void _showMedicationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<String> meds = ['Aspirina 100mg - Cada 12 horas', 'Losartán 50mg - Una vez al día'];
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Medicamentos Actuales'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Gestiona tu lista de medicamentos', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < meds.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        title: Text(meds[i]),
                        trailing: TextButton(
                          onPressed: () => setState(() => meds.removeAt(i)),
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      // Show dialog to create a new alert
                      final result = await showDialog<Map<String, dynamic>>(
                        context: context,
                        builder: (dctx) {
                          final TextEditingController descCtrl = TextEditingController();
                          final TextEditingController placeCtrl = TextEditingController();
                          DateTime selected = DateTime.now();
                          final TextEditingController dateCtrl = TextEditingController(text: _formatDateTime(selected));
                          String status = 'Alerta';
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Agregar alerta'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(controller: descCtrl, maxLines: 3),
                                  const SizedBox(height: 12),
                                  const Text('Fecha y hora', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: dateCtrl,
                                    readOnly: true,
                                    onTap: () async {
                                      final DateTime? pickedDate = await showDatePicker(
                                        context: dctx,
                                        initialDate: selected,
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2100),
                                      );
                                      if (pickedDate != null) {
                                        final TimeOfDay? pickedTime = await showTimePicker(context: dctx, initialTime: TimeOfDay.fromDateTime(selected));
                                        if (pickedTime != null) {
                                          selected = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
                                        } else {
                                          selected = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, selected.hour, selected.minute);
                                        }
                                        dateCtrl.text = _formatDateTime(selected);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('Lugar', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  TextField(controller: placeCtrl, decoration: const InputDecoration(hintText: 'Ej: Casa')), 
                                  const SizedBox(height: 12),
                                  const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  DropdownButton<String>(
                                    value: status,
                                    items: const [
                                      DropdownMenuItem(value: 'Alerta', child: Text('Alerta')),
                                      DropdownMenuItem(value: 'Resuelto', child: Text('Resuelto')),
                                      DropdownMenuItem(value: 'Falsa alarma', child: Text('Falsa alarma')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) status = v;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
                              ElevatedButton(
                                onPressed: () {
                                  final desc = descCtrl.text.trim();
                                  if (desc.isEmpty) return; // require description
                                  Navigator.of(dctx).pop({
                                    'datetime': selected,
                                    'location': placeCtrl.text.trim(),
                                    'description': desc,
                                    'status': status,
                                  });
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          );
                        },
                      );
                      if (result != null) {
                        setState(() {
                          _alerts.insert(0, {
                            'id': _nextAlertId++,
                            'datetime': result['datetime'] as DateTime,
                            'location': result['location'] as String,
                            'latitude': null,
                            'longitude': null,
                            'description': result['description'] as String,
                            'status': result['status'] as String,
                          });
                        });
                        await _saveAlerts();
                      }
                    },
                    child: const Text('+ Agregar alerta'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final result = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (dctx) {
                          final TextEditingController nameCtrl = TextEditingController();
                          final TextEditingController qtyCtrl = TextEditingController();
                          final TextEditingController freqCtrl = TextEditingController();
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Agregar medicamento'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: InputDecoration(labelText: 'Medicamento', hintText: 'Nombre del medicamento'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: qtyCtrl,
                                    decoration: InputDecoration(labelText: 'Cantidad', hintText: '100mg, 1 pastilla...'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: freqCtrl,
                                    decoration: InputDecoration(labelText: 'Frecuencia', hintText: 'Cada 12 horas / 1 vez al día'),
                                  ),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
                              ElevatedButton(
                                onPressed: () {
                                  final name = nameCtrl.text.trim();
                                  final qty = qtyCtrl.text.trim();
                                  final freq = freqCtrl.text.trim();
                                  if (name.isEmpty) return; // simple guard
                                  Navigator.of(dctx).pop({'name': name, 'qty': qty, 'freq': freq});
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          );
                        },
                      );

                      if (result != null) {
                        final name = result['name'] ?? '';
                        final qty = result['qty'] ?? '';
                        final freq = result['freq'] ?? '';
                        final entry = qty.isNotEmpty ? '$name $qty - $freq' : '$name - $freq';
                        setState(() => meds.add(entry));
                      }
                    },
                    child: const Text('+ Agregar medicamento'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
            ],
          );
        });
      },
    );
  }

  void _showAppointmentsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<Map<String, String>> appts = [
          {'name': 'Dr. García', 'specialty': 'Cardiología', 'date': '15/11/2025'},
          {'name': 'Dra. Martínez', 'specialty': 'Medicina General', 'date': '22/11/2025'},
        ];
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Próximas Citas Médicas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Tus consultas programadas', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < appts.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(appts[i]['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(appts[i]['specialty'] ?? ''),
                            const SizedBox(height: 6),
                            Text(appts[i]['date'] ?? '', style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            // open edit modal prefilled
                            final result = await showDialog<Map<String, String>>(
                              context: context,
                              builder: (dctx) {
                                final TextEditingController nameCtrl = TextEditingController(text: appts[i]['name']);
                                final TextEditingController specCtrl = TextEditingController(text: appts[i]['specialty']);
                                final TextEditingController dateCtrl = TextEditingController(text: appts[i]['date']);
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Text('Editar cita'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                                        const SizedBox(height: 8),
                                        TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Especialidad')),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: dateCtrl,
                                          readOnly: true,
                                          decoration: const InputDecoration(labelText: 'Fecha'),
                                          onTap: () async {
                                            final DateTime? picked = await showDatePicker(
                                              context: dctx,
                                              initialDate: DateTime.now(),
                                              firstDate: DateTime(1900),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(dctx).pop({
                                          'name': nameCtrl.text.trim(),
                                          'specialty': specCtrl.text.trim(),
                                          'date': dateCtrl.text.trim(),
                                        });
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (result != null) {
                              setState(() {
                                appts[i] = result;
                              });
                            }
                          },
                          child: const Text('Editar'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final result = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (dctx) {
                          final TextEditingController nameCtrl = TextEditingController();
                          final TextEditingController specCtrl = TextEditingController();
                          final TextEditingController dateCtrl = TextEditingController();
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Agregar cita'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                                  const SizedBox(height: 8),
                                  TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Especialidad')),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: dateCtrl,
                                    readOnly: true,
                                    decoration: const InputDecoration(labelText: 'Fecha'),
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(
                                        context: dctx,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(dctx).pop({
                                    'name': nameCtrl.text.trim(),
                                    'specialty': specCtrl.text.trim(),
                                    'date': dateCtrl.text.trim(),
                                  });
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          );
                        },
                      );
                      if (result != null) setState(() => appts.add(result));
                    },
                    child: const Text('+ Agregar cita'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
            ],
          );
        });
      },
    );
  }

  void _showAlertHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Historial de Alertas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Registro de emergencias activadas', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  if (_alerts.isEmpty) const Text('No hay alertas registradas.'),
                  for (int i = 0; i < _alerts.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(_formatDateTime(_alerts[i]['datetime'] as DateTime)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if ((_alerts[i]['location'] as String).isNotEmpty) Text(_alerts[i]['location'] as String),
                            const SizedBox(height: 8),
                            Text(_alerts[i]['description'] as String),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                _statusChip(_alerts[i]['status'] as String),
                                TextButton(
                                  onPressed: () async {
                                      final result = await _showAlertDetailDialog(context, _alerts[i]);
                                      if (result != null) {
                                        setState(() => _alerts[i] = result);
                                        await _saveAlerts();
                                      }
                                    },
                                  child: const Text('Ver detalles'),
                                ),
                              ],
                            ),
                          ],
                        ),
                          trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            setState(() => _alerts.removeAt(i));
                            await _saveAlerts();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
            ],
          );
        });
      },
    );
  }

  // Mostrar diálogo con detalles de una alerta (editar descripción, lugar y estado)
  Future<Map<String, dynamic>?> _showAlertDetailDialog(BuildContext context, Map<String, dynamic> alert) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dctx) {
        final TextEditingController descCtrl = TextEditingController(text: alert['description'] as String);
        final TextEditingController placeCtrl = TextEditingController(text: alert['location'] as String);
        String status = alert['status'] as String;
        final TextEditingController dateCtrl = TextEditingController(text: _formatDateTime(alert['datetime'] as DateTime));
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Detalle de alerta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, maxLines: 3),
                const SizedBox(height: 12),
                const Text('Hora', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: dctx,
                      initialDate: alert['datetime'] as DateTime,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      dateCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year} ${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('Lugar', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(controller: placeCtrl),
                const SizedBox(height: 12),
                const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'Alerta', child: Text('Alerta')),
                    DropdownMenuItem(value: 'Resuelto', child: Text('Resuelto')),
                    DropdownMenuItem(value: 'Falsa alarma', child: Text('Falsa alarma')),
                  ],
                  onChanged: (v) {
                    if (v != null) status = v;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final updated = Map<String, dynamic>.from(alert);
                updated['description'] = descCtrl.text.trim();
                updated['location'] = placeCtrl.text.trim();
                updated['status'] = status;
                Navigator.of(dctx).pop(updated);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status == 'Resuelto') color = Colors.green;
    if (status == 'Falsa alarma') color = Colors.orange;
    if (status == 'Alerta') color = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDateTime(DateTime dt) {
    final d = dt;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  void _showAllergiesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<String> items = ['Penicilina', 'Maní'];
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Alergias Conocidas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Lista de alergias y reacciones adversas', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  for (int i = 0; i < items.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                        title: Text(items[i]),
                        trailing: TextButton(
                          onPressed: () => setState(() => items.removeAt(i)),
                          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (dctx) {
                          final TextEditingController allergyCtrl = TextEditingController();
                          return AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Agregar alergia'),
                            content: TextField(
                              controller: allergyCtrl,
                              decoration: InputDecoration(hintText: 'Ej: Penicilina'),
                            ),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancelar')),
                              ElevatedButton(
                                onPressed: () {
                                  final text = allergyCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  Navigator.of(dctx).pop(text);
                                },
                                child: const Text('Agregar'),
                              ),
                            ],
                          );
                        },
                      );
                      if (result != null && result.isNotEmpty) setState(() => items.add(result));
                    },
                    child: const Text('+ Agregar alergia'),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
            ],
          );
        });
      },
    );
  }

  Future<void> _showInsuranceDialog(BuildContext context) async {
    final TextEditingController companyCtrl = TextEditingController(text: _insuranceCompany ?? '');
    final TextEditingController policyCtrl = TextEditingController(text: _policyNumber ?? '');
    final TextEditingController phoneCtrl = TextEditingController(text: _insurancePhone ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Información de Seguro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Datos de tu seguro médico', style: TextStyle(color: Theme.of(ctx).textTheme.bodySmall?.color)),
                const SizedBox(height: 12),
                const Text('Compañía de seguros', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: companyCtrl, decoration: InputDecoration(hintText: 'Nombre de la aseguradora', filled: true, fillColor: Theme.of(ctx).inputDecorationTheme.fillColor ?? Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                const Text('Número de póliza', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: policyCtrl, decoration: InputDecoration(hintText: '123456789', filled: true, fillColor: Theme.of(ctx).inputDecorationTheme.fillColor ?? Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                const Text('Teléfono de emergencias', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: phoneCtrl, decoration: InputDecoration(hintText: '+1 800 123 4567', filled: true, fillColor: Theme.of(ctx).inputDecorationTheme.fillColor ?? Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _insuranceCompany = companyCtrl.text.trim();
        _policyNumber = policyCtrl.text.trim();
        _insurancePhone = phoneCtrl.text.trim();
      });
      await _saveInsurance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opciones', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Información médica y recursos', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: ListView(
          children: <Widget>[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Información Médica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _buildCard(context, 'Condición médica', _conditionDiagnosis ?? 'Detalles de enfermedad', icon: Icons.favorite, color: Colors.red),
            // Si hay una condición guardada, mostrar un panel con los detalles y acciones
            if (_conditionDiagnosis != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text('Condición guardada', style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextButton(
                                onPressed: () async {
                                  final result = await _showConditionDialog(context, initialDiagnosis: _conditionDiagnosis, initialSince: _conditionSince);
                                  if (result != null) {
                                    setState(() {
                                      _conditionDiagnosis = result['diagnosis'];
                                      _conditionSince = result['since'];
                                    });
                                  }
                                },
                                child: const Text('Editar', style: TextStyle(color: Colors.red)),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _conditionDiagnosis = null;
                                    _conditionSince = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_conditionDiagnosis ?? '', style: const TextStyle(fontSize: 14)),
                      if (_conditionSince != null) ...[
                        const SizedBox(height: 10),
                        Text('Desde: ${"" /* placeholder replaced below */}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                      ],
                      if (_conditionSince != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(_conditionSince ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                        ),
                    ],
                  ),
                ),
              ),
            _buildCard(context, 'Medicamentos', 'Lista de medicinas actuales', icon: Icons.medication, color: Colors.purple),
            // Mostrar resumen de seguro si existe
            // (Insurance summary moved down near Documents section)
            _buildCard(context, 'Alergias', 'Alergias y reacciones', icon: Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('Historial y Seguimiento', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildCard(context, 'Citas médicas', 'Próximas consultas', icon: Icons.calendar_month, color: Colors.blue),
            _buildCard(context, 'Historial de alertas', 'Emergencias registradas', icon: Icons.history, color: Colors.green),
            _buildCard(context, 'Registro de síntomas', 'Diario de salud', icon: Icons.article, color: Colors.teal),
            const SizedBox(height: 12),
            const Text('Documentos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Mostrar resumen de seguro si existe (moved here)
            if (_insuranceCompany != null || _policyNumber != null || _insurancePhone != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(child: Text('Información de seguro', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color))),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextButton(onPressed: () async { await _showInsuranceDialog(context); }, child: const Text('Editar')),
                              IconButton(onPressed: () async { await _clearInsurance(); }, icon: const Icon(Icons.delete_outline), color: Theme.of(context).iconTheme.color),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_insuranceCompany != null) Text(_insuranceCompany!, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      if (_policyNumber != null) Padding(padding: const EdgeInsets.only(top: 6.0), child: Text('Póliza: ${_policyNumber!}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                      if (_insurancePhone != null) Padding(padding: const EdgeInsets.only(top: 6.0), child: Text('Tel: ${_insurancePhone!}', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color))),
                    ],
                  ),
                ),
              ),
            _buildCard(context, 'Documentos médicos', 'Estudios y recetas', icon: Icons.description, color: Colors.deepPurple),
            _buildCard(context, 'Información de seguro', 'Pólizas y cobertura', icon: Icons.shield, color: Colors.pink),
            const SizedBox(height: 20),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: const <Widget>[
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(child: Text('Información importante\nMantén tu información médica actualizada para que los servicios de emergencia puedan asistirte mejor.')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String subtitle, {required IconData icon, required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openDetail(context, title),
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  final String title;
  const DetailPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Detalle: $title')),
    );
  }
}
