import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';

void main() => runApp(const VisionWhatsApp());

class VisionWhatsApp extends StatelessWidget {
  const VisionWhatsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionWhats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class ChatMessage {
  final String id, text, time;
  final bool isMe;
  String? translatedText, detectedLang;
  bool isTranslating = false;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });
}

class ChatContact {
  final String name, initials, status, lang;
  final Color color;
  final List<String> replies;
  final List<ChatMessage> messages;
  int unread;

  ChatContact({
    required this.name,
    required this.initials,
    required this.color,
    required this.status,
    required this.lang,
    required this.replies,
    required this.messages,
    this.unread = 0,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _searching = false;
  String _query = '';

  final List<ChatContact> _contacts = [
    ChatContact(
      name: 'Maria Silva',
      initials: 'MS',
      color: const Color(0xFF1E88E5),
      status: 'online',
      lang: 'pt',
      unread: 1,
      replies: ['Que ótimo esse VisionWhats! A voz ficou bem clara.', 'Combinado!'],
      messages: [ChatMessage(id: '1', text: 'Oi! Toque em Ouvir para testar a leitura por voz!', isMe: false, time: '09:15')],
    ),
    ChatContact(
      name: 'John Carter (EUA)',
      initials: 'JC',
      color: const Color(0xFF0288D1),
      status: 'online',
      lang: 'en',
      unread: 2,
      replies: ['That sounds great! VisionWhats translates super fast.', 'See you tomorrow!'],
      messages: [
        ChatMessage(id: '1', text: 'Hello! Tap Translate to read this message in Portuguese.', isMe: false, time: '09:10'),
        ChatMessage(id: '2', text: 'Then tap the speaker icon to hear it!', isMe: false, time: '09:11'),
      ],
    ),
    ChatContact(
      name: 'Carlos Mendoza (Espanha)',
      initials: 'CM',
      color: const Color(0xFF00897B),
      status: 'visto hoje às 08:40',
      lang: 'es',
      unread: 1,
      replies: ['¡Excelente! Podemos hablar sin barreras de idioma.', '¡Muchas gracias!'],
      messages: [ChatMessage(id: '1', text: '¡Hola! ¿Cómo estás hoy? Qué buena aplicación.', isMe: false, time: '08:40')],
    ),
    ChatContact(
      name: 'Sophie Laurent (França)',
      initials: 'SL',
      color: const Color(0xFF3949AB),
      status: 'online',
      lang: 'fr',
      replies: ['Merci beaucoup ! Cette application est géniale.', 'À bientôt !'],
      messages: [ChatMessage(id: '1', text: 'Bonjour ! Tu peux traduire ce message en portugais.', isMe: false, time: 'Ontem')],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final list = _contacts.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Buscar...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('VisionWhats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
        ],
      ),
      body: _tab == 0
          ? ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (ctx, i) {
                final c = list[i];
                final last = c.messages.isNotEmpty ? c.messages.last : null;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: c.color,
                    child: Text(c.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(last?.text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(last?.time ?? '', style: TextStyle(fontSize: 12, color: c.unread > 0 ? const Color(0xFF1976D2) : Colors.black45)),
                      if (c.unread > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF1976D2), borderRadius: BorderRadius.circular(12)),
                          child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    setState(() => c.unread = 0);
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(contact: c)));
                    setState(() {});
                  },
                );
              },
            )
          : Center(child: Text(_tab == 1 ? 'Atualizações / Status em breve' : 'Histórico de Chamadas em breve')),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        selectedItemColor: const Color(0xFF1565C0),
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Conversas'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Atualizações'),
          BottomNavigationBarItem(icon: Icon(Icons.call), label: 'Chamadas'),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChatContact contact;
  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _tts = FlutterTts();
  final _translator = GoogleTranslator();

  bool _autoVoice = false;
  bool _autoTranslate = false;
  String? _speakingId;
  int _replyIdx = 0;

  @override
  void initState() {
    super.initState();
    _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingId = null);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _now() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _locale(String lang) {
    if (lang == 'en') return 'en-US';
    if (lang == 'es') return 'es-ES';
    if (lang == 'fr') return 'fr-FR';
    return 'pt-BR';
  }

  Future<void> _speak(ChatMessage m) async {
    if (_speakingId == m.id) {
      await _tts.stop();
      setState(() => _speakingId = null);
      return;
    }
    await _tts.stop();
    final hasTrans = m.translatedText != null && m.translatedText!.isNotEmpty;
    setState(() => _speakingId = m.id);
    try {
      await _tts.setLanguage(hasTrans ? 'pt-BR' : _locale(widget.contact.lang));
      await _tts.speak(hasTrans ? m.translatedText! : m.text);
    } catch (_) {
      if (mounted) setState(() => _speakingId = null);
    }
  }

  Future<void> _translate(ChatMessage m) async {
    if (m.translatedText != null) {
      setState(() => m.translatedText = null);
      return;
    }
    setState(() => m.isTranslating = true);
    try {
      final res = await _translator.translate(m.text, to: 'pt');
      if (mounted) {
        setState(() {
          m.translatedText = res.text;
          m.detectedLang = res.sourceLanguage.code;
          m.isTranslating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => m.isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem internet para traduzir.')));
      }
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      widget.contact.messages.add(ChatMessage(id: '${DateTime.now().millisecondsSinceEpoch}', text: text, isMe: true, time: _now()));
      _ctrl.clear();
    });
    _scrollDown();

    Timer(const Duration(milliseconds: 1300), () async {
      if (!mounted) return;
      final r = widget.contact.replies[_replyIdx % widget.contact.replies.length];
      _replyIdx++;
      final incoming = ChatMessage(id: '${DateTime.now().millisecondsSinceEpoch}', text: r, isMe: false, time: _now());
      setState(() => widget.contact.messages.add(incoming));
      _scrollDown();
      if (_autoTranslate && widget.contact.lang != 'pt') await _translate(incoming);
      if (_autoVoice) await _speak(incoming);
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF5),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: widget.contact.color, child: Text(widget.contact.initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.contact.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(widget.contact.status, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_autoVoice ? Icons.record_voice_over : Icons.voice_over_off),
            onPressed: () => setState(() => _autoVoice = !_autoVoice),
          ),
          IconButton(
            icon: Icon(Icons.translate, color: _autoTranslate ? const Color(0xFF90CAF9) : Colors.white),
            onPressed: () => setState(() => _autoTranslate = !_autoTranslate),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFD6E4F7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'Voz automática: ${_autoVoice ? "ON" : "OFF"}   •   Traduzir automático: ${_autoTranslate ? "ON" : "OFF"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(10),
              itemCount: widget.contact.messages.length,
              itemBuilder: (_, i) {
                final m = widget.contact.messages[i];
                final me = m.isMe;
                final speaking = _speakingId == m.id;
                return Align(
                  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: me ? const Color(0xFF1976D2) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(me ? 14 : 2),
                        bottomRight: Radius.circular(me ? 2 : 14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text, style: TextStyle(color: me ? Colors.white : const Color(0xFF1F2937), fontSize: 15.5)),
                        if (m.isTranslating) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Traduzindo...', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)))),
                        if (m.translatedText != null)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                            child: Text('(${m.detectedLang ?? "auto"} → pt): ${m.translatedText!}', style: const TextStyle(fontSize: 14, color: Color(0xFF0D47A1))),
                          ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!me) ...[
                              InkWell(
                                onTap: () => _speak(m),
                                child: Row(children: [
                                  Icon(speaking ? Icons.stop_circle : Icons.volume_up, size: 17, color: speaking ? Colors.red : const Color(0xFF1565C0)),
                                  const SizedBox(width: 3),
                                  Text(speaking ? 'Parar' : 'Ouvir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: speaking ? Colors.red : const Color(0xFF1565C0))),
                                ]),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () => _translate(m),
                                child: Row(children: [
                                  const Icon(Icons.translate, size: 15, color: Color(0xFF1565C0)),
                                  const SizedBox(width: 3),
                                  Text(m.translatedText == null ? 'Traduzir' : 'Original', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                                ]),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(m.time, style: TextStyle(fontSize: 11, color: me ? Colors.white70 : Colors.black45)),
                            if (me) ...[const SizedBox(width: 4), const Icon(Icons.done_all, size: 15, color: Color(0xFFB3E5FC))],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                      child: TextField(controller: _ctrl, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Mensagem', border: InputBorder.none)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(radius: 24, backgroundColor: const Color(0xFF1565C0), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
