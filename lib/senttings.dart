import 'package:flutter/material.dart';

class SenttingsPage extends StatefulWidget {
  const SenttingsPage({super.key});

  @override
  State<SenttingsPage> createState() => _SenttingsPageState();
}

class _SenttingsPageState extends State<SenttingsPage> {
  bool _notifications = true;
  bool _location = true;
  bool _autoCall = false;

  // Variables de Perfil
  String _nombres = "";
  String _apellidos = "";
  String _edad = "";
  List<String> _enfermedades = [];

  final List<String> enfermedadesCatastroficas = [
    'Cáncer',
    'Insuficiencia renal',
    'Cardiopatía grave',
    'Esclerosis múltiple',
    'Trasplante de órganos'
  ];

  // Funciones para cada Switch
  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notifications = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        value ? 'Notificaciones activadas' : 'Notificaciones desactivadas'
      )),
    );
    // Aquí integras la lógica real (Firebase Messaging, etc.)
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _location = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        value ? 'Compartiendo ubicación GPS' : 'Ubicación GPS desactivada'
      )),
    );
    // Aquí integras la lógica real (Geolocator, etc.)
  }

  Future<void> _toggleAutoCall(bool value) async {
    setState(() => _autoCall = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        value ? 'Llamada automática activada' : 'Llamada automática desactivada'
      )),
    );
    // Aquí integras la lógica real (url_launcher para llamadas)
  }

  // Cuadro de edición de perfil
  void _showEditProfileDialog() {
    String nombres = _nombres;
    String apellidos = _apellidos;
    String edad = _edad;
    List<String> enfermedadesSeleccionadas = List.from(_enfermedades);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar perfil'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Nombres'),
                      controller: TextEditingController(text: nombres),
                      onChanged: (v) => setDialogState(() => nombres = v),
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      controller: TextEditingController(text: apellidos),
                      onChanged: (v) => setDialogState(() => apellidos = v),
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Edad'),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: edad),
                      onChanged: (v) => setDialogState(() => edad = v),
                    ),
                    const SizedBox(height: 8),
                    const Text('Enfermedad(es) catastrófica:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...enfermedadesCatastroficas.map((enfermedad) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(enfermedad),
                        value: enfermedadesSeleccionadas.contains(enfermedad),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              enfermedadesSeleccionadas.add(enfermedad);
                            } else {
                              enfermedadesSeleccionadas.remove(enfermedad);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cerrar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Guardar'),
                  onPressed: () {
                    setState(() {
                      _nombres = nombres;
                      _apellidos = apellidos;
                      _edad = edad;
                      _enfermedades = enfermedadesSeleccionadas;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ajustes', style: TextStyle(color: Colors.black)),
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 6),
            const Text('Configura tu aplicación de emergencia', style: TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 12),

            // Perfil
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.pink.shade50,
                  child: const Icon(Icons.person, color: Colors.pink),
                ),
                title: const Text('Perfil personal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: Text(_nombres.isEmpty && _apellidos.isEmpty && _edad.isEmpty && _enfermedades.isEmpty
                  ? 'Editar información médica'
                  : 'Nombre: $_nombres\nApellido: $_apellidos\nEdad: $_edad\nEnfermedades: ${_enfermedades.join(", ")}',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: TextButton(
                  onPressed: _showEditProfileDialog,
                  child: const Text('Editar', style: TextStyle(color: Colors.red)),
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Alertas y Notificaciones', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: CircleAvatar(
                      backgroundColor: Colors.amber.shade50,
                      child: const Icon(Icons.notifications, color: Colors.amber),
                    ),
                    title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Alertas push activadas', style: TextStyle(fontSize: 13)),
                    value: _notifications,
                    onChanged: _toggleNotifications,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.location_on, color: Colors.blue),
                    ),
                    title: const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Compartir ubicación GPS', style: TextStyle(fontSize: 13)),
                    value: _location,
                    onChanged: _toggleLocation,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    secondary: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.call, color: Colors.green),
                    ),
                    title: const Text('Llamada automática', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Llamar al activar pánico', style: TextStyle(fontSize: 13)),
                    value: _autoCall,
                    onChanged: _toggleAutoCall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Contactos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.phone, color: Colors.blue),
                    ),
                    title: const Text('Contacto 1', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('+1 234 567 890', style: TextStyle(fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextButton(onPressed: () {}, child: const Text('Editar', style: TextStyle(color: Colors.red))),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.delete_outline), color: Colors.grey),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.phone, color: Colors.green),
                    ),
                    title: const Text('Contacto 2', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('+1 234 567 891', style: TextStyle(fontSize: 13)),
                    trailing: TextButton(onPressed: () {}, child: const Text('Editar', style: TextStyle(color: Colors.red))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [Icon(Icons.add), SizedBox(width: 8), Text('+ Agregar contacto')],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Seguridad y Privacidad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.lock, color: Colors.black54)),
                    title: const Text('Cambiar PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.shield, color: Colors.black54)),
                    title: const Text('Privacidad', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.phone_android, color: Colors.black54)),
                title: const Text('Versión de la app', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('1.0.0', style: TextStyle(fontSize: 13)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}


