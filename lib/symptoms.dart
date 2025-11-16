import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key});

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _symptomsCtrl = TextEditingController();
  double _severity = 5.0;

  List<Map<String, dynamic>> _entries = [];
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('symptoms');
      final int? next = prefs.getInt('symptomsNextId');
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        setState(() {
          _entries = list.map((e) => Map<String, dynamic>.from(e)).toList();
          if (next != null) _nextId = next;
        });
      } else {
        if (next != null) _nextId = next;
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('symptoms', jsonEncode(_entries));
      await prefs.setInt('symptomsNextId', _nextId);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addEntry() async {
    final text = _symptomsCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe los síntomas antes de guardar.')));
      return;
    }
    final entry = {
      'id': _nextId++,
      'date': _selectedDate.toIso8601String(),
      'symptoms': text,
      'severity': _severity.round(),
    };
    setState(() {
      _entries.insert(0, entry);
      _symptomsCtrl.clear();
      _selectedDate = DateTime.now();
      _severity = 5.0;
    });
    await _saveEntries();
  }

  void _deleteEntry(int index) async {
    setState(() => _entries.removeAt(index));
    await _saveEntries();
  }

  @override
  void dispose() {
    _symptomsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Síntomas')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Añade una nueva entrada a tu diario de salud', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 12),
                    const Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'dd/mm/aaaa',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                        child: Text('${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Síntomas', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _symptomsCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe los síntomas que experimentaste...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Severidad (1-10)', style: TextStyle(fontWeight: FontWeight.w600)),
                    Slider(
                      value: _severity,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _severity.round().toString(),
                      onChanged: (v) => setState(() => _severity = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(onPressed: () {
                          _symptomsCtrl.clear();
                          setState(() { _selectedDate = DateTime.now(); _severity = 5.0; });
                        }, child: const Text('Cancelar')),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: _addEntry, child: const Text('Guardar')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _entries.isEmpty
                ? const Center(child: Text('No hay entradas todavía.'))
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final dt = DateTime.parse(e['date'] as String);
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text('${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} - Severidad: ${e['severity']}'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(e['symptoms'] as String),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteEntry(i),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
