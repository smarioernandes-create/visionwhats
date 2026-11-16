import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';
import 'extra_screens.dart';

const sbUrl = 'https://vdeuqkakvwbdjmbwvaxj.supabase.co';
const sbKey = 'sb_publishable_MQuUMqoaQK8MuiqOu5as1Q_aUtagiY1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: sbUrl, publishableKey: sbKey);
  runApp(const VisionWhatsApp());
}

String roomOf(String a, String b) => ([a, b]..sort()).join('_');

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
        home: const HomeScreen(),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sb = Supabase.instance.client;
  int _tab = 0, _filterIdx = 0;
  bool _searching = false, _autoVoice = false, _autoTrans = false;
  double _speechRate = 0.50;
  int _bubbleColor = 0xFF1976D2;
  String _myPhone = '', _myName = '', _query = '';
  Map<String, String> _saved = {}, _online = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    _myPhone = p.getString('vw_phone') ?? '';
    _myName = p.getString('vw_name') ?? '';
    _autoVoice = p.getBool('vw_auto_voice') ?? false;
    _autoTrans = p.getBool('vw_auto_trans') ?? false;
    _speechRate = p.getDouble('vw_rate') ?? 0.50;
    _bubbleColor = p.getInt('vw_color') ?? 0xFF1976D2;
    final raw = p.getString('vw_contacts');
    if (raw != null) _saved = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    try {
      final rows = await _sb.from('vw_users').select();
      _online = {for (final r in rows) r['phone'].toString(): r['name'].toString()};
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          myPhone: _myPhone,
          myName: _myName,
          autoVoice: _autoVoice,
          autoTrans: _autoTrans,
          speechRate: _speechRate,
          bubbleColor: _bubbleColor,
          onSaved: _loadAll,
        ),
      ),
    );
  }

  Future<void> _openChat(String ph, String nm) async {
    if (_myPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coloque seu número nas Configurações primeiro para enviar mensagens!')));
      await _openSettings();
      if (_myPhone.isEmpty) return;
    }
    _saved[ph] = nm;
    final p = await SharedPreferences.getInstance();
    await p.setString('vw_contacts', jsonEncode(_saved));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          myPhone: _myPhone,
          peerPhone: ph,
          peerName: nm,
          defaultVoice: _autoVoice,
          defaultTrans: _autoTrans,
          speechRate: _speechRate,
          bubbleColor: Color(_bubbleColor),
        ),
      ),
    );
    _loadAll();
  }

  Future<void> _openContacts() async {
    await _loadAll();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          myPhone: _myPhone,
          online: _online,
          onPick: (ph, nm) {
            Navigator.pop(context);
            _openChat(ph, nm);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Pesquisar conversa...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('VisionWhats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: () => setState(() => _tab = 1)),
          IconButton(icon: Icon(_searching ? Icons.close : Icons.search), onPressed: () => setState(() { _searching = !_searching; if (!_searching) _query = ''; })),
          IconButton(tooltip: 'Configurações', icon: const Icon(Icons.settings), onPressed: _openSettings),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'contacts') _openContacts();
              if (v == 'settings') _openSettings();
              if (v == 'refresh') _loadAll();
              if (v == 'share') {
                Clipboard.setData(const ClipboardData(text: dlUrl));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado!')));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'contacts', child: Text('Novo contato / Agenda')),
              const PopupMenuItem(value: 'settings', child: Text('Configurações')),
              const PopupMenuItem(value: 'refresh', child: Text('Atualizar conversas')),
              const PopupMenuItem(value: 'share', child: Text('Convidar amigos')),
            ],
          ),
        ],
      ),
      body: _tab == 0
          ? Column(children: [
              if (_myPhone.isEmpty)
                MaterialBanner(
                  backgroundColor: const Color(0xFFE3F2FD),
                  content: const Text('Cadastre seu número em Configurações para enviar mensagens reais.', style: TextStyle(color: Color(0xFF0D47A1))),
                  actions: [TextButton(onPressed: _openSettings, child: const Text('CONFIGURAR'))],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  ChoiceChip(label: const Text('Todas'), selected: _filterIdx == 0, onSelected: (_) => setState(() => _filterIdx = 0)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('No VisionWhats'), selected: _filterIdx == 1, onSelected: (_) => setState(() => _filterIdx = 1)),
                ]),
              ),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _sb.from('vw_messages').stream(primaryKey: ['id']).order('created_at', ascending: false),
                  builder: (_, snap) {
                    final last = <String, Map<String, dynamic>>{};
                    for (final m in (snap.data ?? [])) {
                      if (_myPhone.isEmpty) break;
                      final s = m['sender_phone'].toString(), r = m['receiver_phone'].toString();
                      if (s == _myPhone || r == _myPhone) last.putIfAbsent(s == _myPhone ? r : s, () => m);
                    }
                    final all = {..._saved.keys, ...last.keys, ..._online.keys.where((k) => k != _myPhone)};
                    final peers = all.where((ph) {
                      if (_filterIdx == 1 && !_online.containsKey(ph)) return false;
                      final nm = _saved[ph] ?? _online[ph] ?? '+$ph';
                      return nm.toLowerCase().contains(_query.toLowerCase()) || ph.contains(_query);
                    }).toList();
                    if (peers.isEmpty) {
                      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat_bubble_outline, size: 58, color: Color(0xFF1976D2)),
                        const SizedBox(height: 10),
                        const Text('Toque no botão abaixo para abrir sua agenda ou adicionar um número.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(onPressed: _openContacts, icon: const Icon(Icons.person_add), label: const Text('Abrir Contatos')),
                      ]));
                    }
                    return ListView.separated(
                      itemCount: peers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (_, i) {
                        final ph = peers[i], nm = _saved[ph] ?? _online[ph] ?? '+$ph', m = last[ph];
                        final dt = DateTime.tryParse(m?['created_at']?.toString() ?? '')?.toLocal();
                        final tm = dt == null ? '' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        final isOn = _online.containsKey(ph);
                        return ListTile(
                          leading: CircleAvatar(radius: 25, backgroundColor: isOn ? Color(_bubbleColor) : Colors.blueGrey, child: Text(initialsOf(nm), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          title: Text(nm, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(m?['text']?.toString() ?? (isOn ? 'No VisionWhats • toque para conversar' : '+$ph'), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text(tm, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                          onTap: () => _openChat(ph, nm),
                        );
                      },
                    );
                  },
                ),
              ),
            ])
          : Center(
              child: Text(
                _tab == 1 ? 'Atualizações / Status em breve' : _tab == 2 ? 'Comunidades em breve' : 'Chamadas em breve',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
      floatingActionButton: FloatingActionButton(backgroundColor: Color(_bubbleColor), foregroundColor: Colors.white, onPressed: _openContacts, child: const Icon(Icons.chat)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        selectedItemColor: cPri,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Conversas'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Atualizações'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Comunidades'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Chamadas'),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String myPhone, peerPhone, peerName;
  final bool defaultVoice, defaultTrans;
  final double speechRate;
  final Color bubbleColor;
  const ChatScreen({
    super.key,
    required this.myPhone,
    required this.peerPhone,
    required this.peerName,
    required this.defaultVoice,
    required this.defaultTrans,
    required this.speechRate,
    required this.bubbleColor,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _sb = Supabase.instance.client, _ctrl = TextEditingController(), _scroll = ScrollController(), _tts = FlutterTts(), _tr = GoogleTranslator();
  late final String _room = roomOf(widget.myPhone, widget.peerPhone);
  final Map<String, String> _trans = {}, _langs = {};
  final Set<String> _busy = {}, _seen = {};
  bool _init = false;
  late bool _autoV = widget.defaultVoice, _autoT = widget.defaultTrans;
  String? _spkId;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(widget.speechRate);
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
          Container(width: double.infinity, color: const Color(0xFFD6E4F7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text('Voz auto: ${_autoV ? "ON" : "OFF"}  •  Traduzir auto: ${_autoT ? "ON" : "OFF"}', style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600))),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _sb.from('vw_messages').stream(primaryKey: ['id']).eq('room_id', _room).order('created_at', ascending: true),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rows = snap.data!;
                final fresh = rows.where((r) => _seen.add(r['id'].toString()) && _init && r['sender_phone'].toString() != widget.myPhone).toList();
                _init = true;
                if (rows.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                    for (final r in fresh) {
                      if (_autoT) await _translate(r['id'].toString(), r['text'].toString(), toggle: false);
                      if (_autoV) await _speak(r['id'].toString(), r['text'].toString());
                    }
                  });
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(10),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final r = rows[i], id = r['id'].toString(), txt = r['text'].toString(), me = r['sender_phone'].toString() == widget.myPhone;
                    final dt = DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal();
                    final tm = dt == null ? '' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    final sp = _spkId == id, tr = _trans[id];
                    return Align(
                      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(color: me ? widget.bubbleColor : Colors.white, borderRadius: BorderRadius.only(topLeft: const Radius.circular(14), topRight: const Radius.circular(14), bottomLeft: Radius.circular(me ? 14 : 2), bottomRight: Radius.circular(me ? 2 : 14))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(txt, style: TextStyle(color: me ? Colors.white : const Color(0xFF1F2937), fontSize: 15.5)),
                          if (_busy.contains(id)) const Text('Traduzindo...', style: TextStyle(fontSize: 12, color: cPri)),
                          if (tr != null) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)), child: Text('(${_langs[id] ?? "auto"} → pt): $tr', style: const TextStyle(fontSize: 14, color: Color(0xFF0D47A1)))),
                          const SizedBox(height: 5),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!me) ...[
                              InkWell(onTap: () => _speak(id, txt), child: Row(children: [Icon(sp ? Icons.stop_circle : Icons.volume_up, size: 17, color: sp ? Colors.red : cPri), const SizedBox(width: 3), Text(sp ? 'Parar' : 'Ouvir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sp ? Colors.red : cPri))])),
                              const SizedBox(width: 10),
                              InkWell(onTap: () => _translate(id, txt), child: Row(children: [const Icon(Icons.translate, size: 15, color: cPri), const SizedBox(width: 3), Text(tr == null ? 'Traduzir' : 'Original', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cPri))])),
                              const SizedBox(width: 10),
                            ],
                            Text(tm, style: TextStyle(fontSize: 11, color: me ? Colors.white70 : Colors.black45)),
                            if (me) ...[const SizedBox(width: 4), const Icon(Icons.done_all, size: 15, color: Color(0xFFB3E5FC))],
                          ]),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)), child: TextField(controller: _ctrl, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Mensagem', border: InputBorder.none)))),
                const SizedBox(width: 8),
                CircleAvatar(radius: 24, backgroundColor: cPri, child: IconButton(icon: const Icon(Icons.send, 
