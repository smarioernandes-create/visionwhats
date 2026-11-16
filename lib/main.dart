import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';

const sbUrl = 'https://vdeuqkakvwbdjmbwvaxj.supabase.co';
const sbKey = 'sb_publishable_MQuUMqoaQK8MuiqOu5as1Q_aUtagiY1';
const dlUrl = 'https://github.com/smarioernandes-create/visionwhats/releases';
const cPri = Color(0xFF1565C0);
const cBub = Color(0xFF1976D2);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: sbUrl, publishableKey: sbKey);
  runApp(const VisionWhatsApp());
}

String normPhone(String raw) {
  final t = raw.trim();
  var d = t.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  if (!t.startsWith('+') && (d.length == 10 || d.length == 11)) d = '55$d';
  return d;
}

String roomOf(String a, String b) => ([a, b]..sort()).join('_');

String initialsOf(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return p.length == 1 ? p.first[0].toUpperCase() : '${p.first[0]}${p.last[0]}'.toUpperCase();
}

class VisionWhatsApp extends StatelessWidget {
  const VisionWhatsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VisionWhats',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: cPri),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(backgroundColor: cPri, foregroundColor: Colors.white),
        ),
        home: const BootScreen(),
      );
}

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});
  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String? _phone, _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() { _phone = p.getString('vw_phone'); _name = p.getString('vw_name'); _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_phone == null || _phone!.isEmpty || _name == null || _name!.isEmpty) {
      return RegisterScreen(onDone: (ph, nm) => setState(() { _phone = ph; _name = nm; }));
    }
    return HomeScreen(
      myPhone: _phone!,
      myName: _name!,
      onLogout: () async {
        final p = await SharedPreferences.getInstance();
        await p.remove('vw_phone');
        await p.remove('vw_name');
        setState(() { _phone = null; _name = null; });
      },
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final void Function(String, String) onDone;
  const RegisterScreen({super.key, required this.onDone});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final nm = _name.text.trim(), ph = normPhone(_phone.text);
    if (nm.isEmpty || ph.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite seu nome e telefone com DDD!')));
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('vw_users').upsert({'phone': ph, 'name': nm});
      final p = await SharedPreferences.getInstance();
      await p.setString('vw_phone', ph);
      await p.setString('vw_name', nm);
      widget.onDone(ph, nm);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFE8EEF5),
        appBar: AppBar(title: const Text('VisionWhats - Cadastro')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.chat_bubble_rounded, size: 60, color: cPri),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Seu Nome', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone c/ DDD (ex: 11999998888)', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cPri, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Entrar', style: const TextStyle(fontSize: 16)),
            ),
          ]),
        ),
      );
}

class HomeScreen extends StatefulWidget {
  final String myPhone, myName;
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.myPhone, required this.myName, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sb = Supabase.instance.client;
  int _tab = 0;
  bool _searching = false;
  String _query = '';
  Map<String, String> _saved = {}, _online = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('vw_contacts');
    if (raw != null) _saved = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    try {
      final rows = await _sb.from('vw_users').select();
      _online = {for (final r in rows) r['phone'].toString(): r['name'].toString()};
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _openChat(String ph, String nm) async {
    _saved[ph] = nm;
    final p = await SharedPreferences.getInstance();
    await p.setString('vw_contacts', jsonEncode(_saved));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myPhone: widget.myPhone, peerPhone: ph, peerName: nm)));
    _load();
  }

  Future<void> _openContacts() async {
    await _load();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ContactsScreen(myPhone: widget.myPhone, online: _online, onPick: (ph, nm) { Navigator.pop(context); _openChat(ph, nm); })));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Buscar...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none), onChanged: (v) => setState(() => _query = v))
              : const Text('VisionWhats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          actions: [
            IconButton(icon: Icon(_searching ? Icons.close : Icons.search), onPressed: () => setState(() { _searching = !_searching; if (!_searching) _query = ''; })),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'share') {
                  Clipboard.setData(const ClipboardData(text: dlUrl));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado! Mande para seus amigos.')));
                } else if (v == 'logout') widget.onLogout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text('${widget.myName} (+${widget.myPhone})')),
                const PopupMenuItem(value: 'share', child: Text('Copiar link para amigos')),
                const PopupMenuItem(value: 'logout', child: Text('Trocar número')),
              ],
            ),
          ],
        ),
        body: _tab == 0
            ? StreamBuilder<List<Map<String, dynamic>>>(
                stream: _sb.from('vw_messages').stream(primaryKey: ['id']).order('created_at', ascending: false),
                builder: (_, snap) {
                  final last = <String, Map<String, dynamic>>{};
                  for (final m in (snap.data ?? [])) {
                    final s = m['sender_phone'].toString(), r = m['receiver_phone'].toString();
                    if (s == widget.myPhone || r == widget.myPhone) last.putIfAbsent(s == widget.myPhone ? r : s, () => m);
                  }
                  final peers = {..._saved.keys, ...last.keys}.where((ph) {
                    final nm = _saved[ph] ?? _online[ph] ?? '+$ph';
                    return nm.toLowerCase().contains(_query.toLowerCase()) || ph.contains(_query);
                  }).toList();
                  if (peers.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.contacts, size: 60, color: cBub),
                      const SizedBox(height: 12),
                      const Text('Nenhuma conversa ainda!'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(onPressed: _openContacts, icon: const Icon(Icons.person_add), label: const Text('Adicionar Contato')),
                    ]));
                  }
                  return ListView.separated(
                    itemCount: peers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final ph = peers[i], nm = _saved[ph] ?? _online[ph] ?? '+$ph', m = last[ph];
                      final dt = DateTime.tryParse(m?['created_at']?.toString() ?? '')?.toLocal();
                      final tm = dt == null ? '' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: CircleAvatar(radius: 25, backgroundColor: _online.containsKey(ph) ? cBub : Colors.blueGrey, child: Text(initialsOf(nm), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        title: Text(nm, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(m?['text']?.toString() ?? '+$ph', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Text(tm, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        onTap: () => _openChat(ph, nm),
                      );
                    },
                  );
                },
              )
            : Center(child: Text(_tab == 1 ? 'Atualizações em breve' : 'Chamadas em breve')),
        floatingActionButton: FloatingActionButton(backgroundColor: cBub, foregroundColor: Colors.white, onPressed: _openContacts, child: const Icon(Icons.person_add)),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          selectedItemColor: cPri,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Conversas'),
            BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Atualizações'),
            BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Chamadas'),
          ],
        ),
      );
}

class ContactsScreen extends StatefulWidget {
  final String myPhone;
  final Map<String, String> online;
  final void Function(String, String) onPick;
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
          if (n.length >= 10 && n != widget.myPhone && seen.add(n)) list.add({'name': c.displayName.isEmpty ? '+$n' : c.displayName, 'phone': n});
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
                  onPressed: () { final ph = normPhone(_phone.text); if (ph.length >= 10) widget.onPick(ph, _name.text.trim().isEmpty ? '+$ph' : _name.text.trim()); },
                  icon: const Icon(Icons.chat),
                  label: const Text('Conversar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _loading ? null : _import, icon: const Icon(Icons.contacts), label: Text(_loading ? 'Lendo...' : 'Agenda Celular'))),
            ]),
          ]),
        ),
        if (_book.isNotEmpty) Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Filtrar agenda...', isDense: true, border: OutlineInputBorder()), onChanged: (v) => setState(() => _filter = v))),
        Expanded(
          child: _book.isEmpty
              ? ListView(children: widget.online.entries.where((e) => e.key != widget.myPhone).map((e) => ListTile(
                  leading: CircleAvatar(backgroundColor: cBub, child: Text(initialsOf(e.value), style: const TextStyle(color: Colors.white))),
                  title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('+${e.key} • No VisionWhats'),
                  onTap: () => widget.onPick(e.key, e.value),
                )).toList())
              : ListView.builder(
                  itemCount: vis.length,
                  itemBuilder: (_, i) {
                    final c = vis[i], on = widget.online.containsKey(c['phone']);
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: on ? cBub : Colors.blueGrey, child: Text(initialsOf(c['name']!), style: const TextStyle(color: Colors.white))),
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

class ChatScreen extends StatefulWidget {
  final String myPhone, peerPhone, peerName;
  const ChatScreen({super.key, required this.myPhone, required this.peerPhone, required this.peerName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _sb = Supabase.instance.client, _ctrl = TextEditingController(), _scroll = ScrollController(), _tts = FlutterTts(), _tr = GoogleTranslator();
  late final String _room = roomOf(widget.myPhone, widget.peerPhone);
  final Map<String, String> _trans = {}, _langs = {};
  final Set<String> _busy = {}, _seen = {};
  bool _init = false, _autoV = false, _autoT = false;
  String? _spkId;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() { if (mounted) setState(() => _spkId = null); });
  }

  @override
  void dispose() {
    _tts.stop();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _speak(String id, String txt) async {
    if (_spkId == id) { await _tts.stop(); setState(() => _spkId = null); return; }
    await _tts.stop();
    final t = _trans[id], l = t != null ? 'pt-BR' : (_langs[id] == 'en' ? 'en-US' : _langs[id] == 'es' ? 'es-ES' : _langs[id] == 'fr' ? 'fr-FR' : 'pt-BR');
    setState(() => _spkId = id);
    try { await _tts.setLanguage(l); await _tts.speak(t ?? txt); } catch (_) { if (mounted) setState(() => _spkId = null); }
  }

  Future<void> _translate(String id, String txt, {bool toggle = true}) async {
    if (_trans.containsKey(id)) { if (toggle) setState(() => _trans.remove(id)); return; }
    setState(() => _busy.add(id));
    try {
      final res = await _tr.translate(txt, to: 'pt');
      if (mounted) setState(() { _trans[id] = res.text; _langs[id] = res.sourceLanguage.code; _busy.remove(id); });
    } catch (_) { if (mounted) setState(() => _busy.remove(id)); }
  }

  Future<void> _send() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    _ctrl.clear();
    await _sb.from('vw_messages').insert({'room_id': _room, 'sender_phone': widget.myPhone, 'receiver_phone': widget.peerPhone, 'text': txt});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFE8EEF5),
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.peerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('+${widget.peerPhone}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          actions: [
            IconButton(icon: Icon(_autoV ? Icons.record_voice_over : Icons.voice_over_off), onPressed: () => setState(() => _autoV = !_autoV)),
            IconButton(icon: Icon(Icons.translate, color: _autoT ? const Color(0xFF90CAF9) : Colors.white), onPressed: () => setState(() => _autoT = !_autoT)),
          ],
        ),
        body: Column(children: [
        
