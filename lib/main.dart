import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:translator/translator.dart';

const String supabaseUrl = 'https://vdeuqkakvwbdjmbwvaxj.supabase.co';
const String supabaseKey = 'sb_publishable_MQuUMqoaQK8MuiqOu5as1Q_aUtagiY1';
const String appDownloadUrl = 'https://github.com/smarioernandes-create/visionwhats/releases';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const VisionWhatsApp());
}

String normalizePhone(String raw) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  var d = trimmed.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  if (!hasPlus && (d.length == 10 || d.length == 11)) {
    d = '55$d';
  }
  return d;
}

String makeRoomId(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}_${list[1]}';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

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
      home: const BootScreen(),
    );
  }
}

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String? _myPhone;
  String? _myName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myPhone = prefs.getString('vw_phone');
      _myName = prefs.getString('vw_name');
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_myPhone == null || _myPhone!.isEmpty || _myName == null || _myName!.isEmpty) {
      return RegisterScreen(onDone: (phone, name) {
        setState(() {
          _myPhone = phone;
          _myName = name;
        });
      });
    }
    return HomeScreen(
      myPhone: _myPhone!,
      myName: _myName!,
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('vw_phone');
        await prefs.remove('vw_name');
        setState(() {
          _myPhone = null;
          _myName = null;
        });
      },
    );
  }
}

class RegisterScreen extends StatefulWidget {
  final void Function(String phone, String name) onDone;
  const RegisterScreen({super.key, required this.onDone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = normalizePhone(_phoneCtrl.text);
    if (name.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu nome e um telefone válido com DDD!')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('vw_users').upsert({
        'phone': phone,
        'name': name,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vw_phone', phone);
      await prefs.setString('vw_name', name);
      widget.onDone(phone, name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao conectar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF5),
      appBar: AppBar(title: const Text('Bem-vindo ao VisionWhats')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.chat_bubble_rounded, size: 64, color: Color(0xFF1565C0)),
            const SizedBox(height: 12),
            const Text(
              'Configure seu perfil para conversar com seus contatos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Seu Nome',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Seu Telefone com DDD (ex: 11999998888)',
                hintText: 'Se for de outro país, comece com +',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Salvando...' : 'Entrar no VisionWhats', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String myPhone;
  final String myName;
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
  Map<String, String> _savedContacts = {};
  Map<String, String> _onlineUsers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('vw_saved_contacts');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _savedContacts = decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    try {
      final rows = await _sb.from('vw_users').select();
      final map = <String, String>{};
      for (final r in rows) {
        map[r['phone'].toString()] = r['name'].toString();
      }
      _onlineUsers = map;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _saveContact(String phone, String name) async {
    _savedContacts[phone] = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vw_saved_contacts', jsonEncode(_savedContacts));
    if (mounted) setState(() {});
  }

  void _openChat(String peerPhone, String peerName) async {
    await _saveContact(peerPhone, peerName);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(myPhone: widget.myPhone, peerPhone: peerPhone, peerName: peerName),
      ),
    );
    _loadData();
  }

  Future<void> _openContactsPicker() async {
    await _loadData();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          myPhone: widget.myPhone,
          onlineUsers: _onlineUsers,
          onSelect: (phone, name) {
            Navigator.pop(context);
            _openChat(phone, name);
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
                decoration: const InputDecoration(hintText: 'Buscar conversa...', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
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
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'share') {
                Clipboard.setData(const ClipboardData(text: appDownloadUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link de download do VisionWhats copiado! Mande para seus amigos.')),
                );
              } else if (v == 'logout') {
                widget.onLogout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text('${widget.myName} (+${widget.myPhone})')),
              const PopupMenuItem(value: 'share', child: Text('Copiar link para convidar amigos')),
              const PopupMenuItem(value: 'logout', child: Text('Trocar meu número')),
            ],
          ),
        ],
      ),
      body: _tab == 0
          ? StreamBuilder<List<Map<String, dynamic>>>(
              stream: _sb.from('vw_messages').stream(primaryKey: ['id']).order('created_at', ascending: false),
              builder: (context, snap) {
                final latestByPeer = <String, Map<String, dynamic>>{};
                final rows = snap.data ?? [];
                for (final m in rows) {
                  final s = m['sender_phone'].toString();
                  final r = m['receiver_phone'].toString();
                  if (s != widget.myPhone && r != widget.myPhone) continue;
                  final peer = s == widget.myPhone ? r : s;
                  latestByPeer.putIfAbsent(peer, () => m);
                }

                final allPeers = <String>{..._savedContacts.keys, ...latestByPeer.keys}.toList();
                allPeers.sort((a, b) {
                  final ta = latestByPeer[a]?['created_at']?.toString() ?? '';
                  final tb = latestByPeer[b]?['created_at']?.toString() ?? '';
                  return tb.compareTo(ta);
                });

                final filtered = allPeers.where((phone) {
                  final name = _savedContacts[phone] ?? _onlineUsers[phone] ?? '+$phone';
                  return name.toLowerCase().contains(_query.toLowerCase()) || phone.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.contacts, size: 64, color: Color(0xFF1976D2)),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhuma conversa ainda!\nToque no botão azul abaixo para adicionar um contato ou puxar da sua agenda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15.5),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openContactsPicker,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Adicionar Contato'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) {
                    final phone = filtered[i];
                    final name = _savedContacts[phone] ?? _onlineUsers[phone] ?? '+$phone';
                    final last = latestByPeer[phone];
                    final dt = DateTime.tryParse(last?['created_at']?.toString() ?? '')?.toLocal();
                    final timeStr = dt == null ? '' : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    final isRegistered = _onlineUsers.containsKey(phone);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: isRegistered ? const Color(0xFF1976D2) : Colors.blueGrey,
                        child: Text(initialsOf(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        last?['text']?.toString() ?? (isRegistered ? 'No VisionWhats — toque para conversar' : '+$phone'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.black45)),
                      onTap: () => _openChat(phone, name),
                    );
                  },
                );
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tab == 1 ? 'Atualizações / Status em breve' : 'Chamadas de Voz/Vídeo em breve', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: appDownloadUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link do VisionWhats copiado!')),
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Copiar link do app para amigos'),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        onPressed: _openContactsPicker,
        child: const Icon(Icons.person_add),
      ),
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

class ContactsScreen extends StatefulWidget {
  final String myPhone;
  final Map<String, String> onlineUsers;
  final void Function(String phone, String name) onSelect;

  const ContactsScreen({super.key, required this.myPhone, required this.onlineUsers, required this.onSelect});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _phoneBook = [];
  bool _loadingContacts = false;
  String _filter = '';

  Future<void> _importPhoneContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão da agenda negada. Você pode digitar o número acima.')),
          );
        }
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final seen = <String>{};
      final list = <Map<String, String>>[];
      for (final c in contacts) {
        for (final p in c.phones) {
          final norm = normalizePhone(p.number);
          if (norm.length >= 10 && norm != widget.myPhone && seen.add(norm)) {
            list.add({'name': c.displayName.isEmpty ? '+$norm' : c.displayName, 'phone': norm});
          }
        }
      }
      list.sort((a, b) {
        final aOn = widget.onlineUsers.containsKey(a['phone']) ? 0 : 1;
        final bOn = widget.onlineUsers.containsKey(b['phone']) ? 0 : 1;
        if (aOn != bOn) return aOn.compareTo(bOn);
        return a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase());
      });
      if (mounted) setState(() => _phoneBook = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ler agenda: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _addManual() {
    final phone = normalizePhone(_phoneCtrl.text);
    final name = _nameCtrl.text.trim().isEmpty ? '+$phone' : _nameCtrl.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um número válido com DDD!')));
      return;
    }
    widget.onSelect(phone, name);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _phoneBook.where((c) {
      return c['name']!.toLowerCase().contains(_filter.toLowerCase()) || c['phone']!.contains(_filter);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Contatos')),
      body: Column(
        children: [
          Container(
            color: const Color(0xFFE8EEF5),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Adicionar por
