import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const cPri = Color(0xFF1565C0);
const dlUrl = 'https://github.com/smarioernandes-create/visionwhats/releases';

String normPhone(String raw) {
  final t = raw.trim();
  var d = t.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  if (!t.startsWith('+') && (d.length == 10 || d.length == 11)) d = '55$d';
  return d;
}

String initialsOf(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return p.length == 1 ? p.first[0].toUpperCase() : '${p.first[0]}${p.last[0]}'.toUpperCase();
}

class ContactsScreen extends StatefulWidget {
  final String myPhone;
  final Map<String, String> online;
  final void Function(String phone, String name) onPick;
  const ContactsScreen({super.key, required this.myPhone, required this.online, required this.onPick});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  List<Map<String, String>> _book = [];
  bool _loading = false;
  String _filter = '';

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada. Digite o número acima!')));
        return;
      }
      final cts = await FlutterContacts.getContacts(withProperties: true);
      final seen = <String>{};
      final list = <Map<String, String>>[];
      for (final c in cts) {
        for (final p in c.phones) {
          final n = normPhone(p.number);
          if (n.length >= 10 && n != widget.myPhone && seen.add(n)) {
            list.add({'name': c.displayName.isEmpty ? '+$n' : c.displayName, 'phone': n});
          }
        }
      }
      list.sort((a, b) => (widget.online.containsKey(a['phone']) ? 0 : 1).compareTo(widget.online.containsKey(b['phone']) ? 0 : 1));
      if (mounted) setState(() => _book = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vis = _book.where((c) => c['name']!.toLowerCase().contains(_filter.toLowerCase()) || c['phone']!.contains(_filter)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Contatos')),
      body: Column(children: [
        Container(
          color: const Color(0xFFE8EEF5),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'Nome', isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Telefone c/ DDD', isDense: true, filled: true, fillColor: Colors.white, border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: cPri, foregroundColor: Colors.white),
                  onPressed: () {
                    final ph = normPhone(_phone.text);
                    if (ph.length < 10) return;
                    widget.onPick(ph, _name.text.trim().isEmpty ? '+$ph' : _name.text.trim());
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Conversar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _loading ? null : _import, icon: const Icon(Icons.contacts), label: Text(_loading ? 'Lendo...' : 'Agenda Celular'))),
            ]),
          ]),
        ),
        if (_book.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filtrar agenda...', isDense: true, border: OutlineInputBorder()), onChanged: (v) => setState(() => _filter = v)),
          ),
        Expanded(
          child: _book.isEmpty
              ? ListView(
                  children: widget.online.entries.where((e) => e.key != widget.myPhone).map((e) => ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFF1976D2), child: Text(initialsOf(e.value), style: const TextStyle(color: Colors.white))),
                    title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('+${e.key} • No VisionWhats'),
                    onTap: () => widget.onPick(e.key, e.value),
                  )).toList(),
                )
              : ListView.builder(
                  itemCount: vis.length,
                  itemBuilder: (_, i) {
                    final c = vis[i], on = widget.online.containsKey(c['phone']);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: on ? const Color(0xFF1976D2) : Colors.blueGrey, child: Text(initialsOf(c['name']!), style: const TextStyle(color: Colors.white))),
                      title: Text(c['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('+${c['phone']} ${on ? "• No VisionWhats" : ""}'),
                      onTap: () => widget.onPick(c['phone']!, c['name']!),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String myPhone, myName;
  final bool autoVoice, autoTrans;
  final double speechRate;
  final int bubbleColor;
  final VoidCallback onSaved;

  const SettingsScreen({
    super.key,
    required this.myPhone,
    required this.myName,
    required this.autoVoice,
    required this.autoTrans,
    required this.speechRate,
    required this.bubbleColor,
    required this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: widget.myName);
  late final _phone = TextEditingController(text: widget.myPhone);
  late bool _autoV = widget.autoVoice;
  late bool _autoT = widget.autoTrans;
  late double _rate = widget.speechRate;
  late int _color = widget.bubbleColor;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = await SharedPreferences.getInstance();
      final nm = _name.text.trim();
      final ph = normPhone(_phone.text);
      if (nm.isNotEmpty && ph.length >= 10) {
        await Supabase.instance.client.from('vw_users').upsert({'phone': ph, 'name': nm});
        await p.setString('vw_phone', ph);
        await p.setString('vw_name', nm);
      }
      await p.setBool('vw_auto_voice', _autoV);
      await p.setBool('vw_auto_trans', _autoT);
      await p.setDouble('vw_rate', _rate);
      await p.setInt('vw_color', _color);
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Meu Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cPri)),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Seu Nome', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Seu Telefone c/ DDD (ex: 47988111261)', border: OutlineInputBorder())),
        const Divider(height: 28),
        const Text('Voz e Tradução', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cPri)),
        SwitchListTile(title: const Text('Ler mensagens automaticamente por voz'), value: _autoV, onChanged: (v) => setState(() => _autoV = v)),
        SwitchListTile(title: const Text('Traduzir outros idiomas automaticamente'), value: _autoT, onChanged: (v) => setState(() => _autoT = v)),
        const SizedBox(height: 6),
        const Text('Velocidade da leitura por voz:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Lenta'), selected: _rate < 0.45, onSelected: (_) => setState(() => _rate = 0.38)),
          ChoiceChip(label: const Text('Normal'), selected: _rate >= 0.45 && _rate <= 0.55, onSelected: (_) => setState(() => _rate = 0.50)),
          ChoiceChip(label: const Text('Rápida'), selected: _rate > 0.55, onSelected: (_) => setState(() => _rate = 0.65)),
        ]),
        const Divider(height: 28),
        const Text('Cor dos meus balões:', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Azul Padrão'), selected: _color == 0xFF1976D2, onSelected: (_) => setState(() => _color = 0xFF1976D2)),
          ChoiceChip(label: const Text('Azul Escuro'), selected: _color == 0xFF0D47A1, onSelected: (_) => setState(() => _color = 0xFF0D47A1)),
          ChoiceChip(label: const Text('Verde'), selected: _color == 0xFF008069, onSelected: (_) => setState(() => _color = 0xFF008069)),
        ]),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: cPri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(_saving ? 'Salvando...' : 'Salvar Configurações'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: dlUrl));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado! Mande para seus amigos instalarem.')));
          },
          icon: const Icon(Icons.share),
          label: const Text('Convidar amigos (copiar link do app)'),
        ),
      ]),
    );
  }
}
