import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/db_provider.dart';
import '../services/auth_service.dart';
import '../theme/design_system.dart';

/// Seller-side buyer inbox.
///
/// Merges two message sources:
///   • Local SQLite `messages` table  → LAN-connected buyers
///   • Supabase `cloud_messages` table → Cloud-connected buyers
///
/// Conversations are keyed by client_id (LAN) or buyer_id (cloud) and shown
/// in a unified thread list. The seller can reply to both.
class BuyerInboxScreen extends StatefulWidget {
  const BuyerInboxScreen({super.key});

  static void openConversation(BuildContext context, {
    required String clientId,
    required String displayId,
    required bool isCloud,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatScreen(
          conv: _Conversation(
            id: clientId,
            displayId: displayId,
            source: isCloud ? _Source.cloud : _Source.lan,
            lastMessage: '',
            lastSender: 'buyer',
            lastTs: DateTime.now().millisecondsSinceEpoch,
            unread: 0,
          ),
        ),
      ),
    );
  }

  @override
  State<BuyerInboxScreen> createState() => _BuyerInboxScreenState();
}

class _BuyerInboxScreenState extends State<BuyerInboxScreen>
    with SingleTickerProviderStateMixin {
  List<_Conversation> _conversations = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shopId = await AuthService.getShopId();
      final convs = <_Conversation>[];

      // ── LAN threads (local SQLite) ─────────────────────────────────────────
      final db = await DbProvider.db;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id TEXT NOT NULL,
          sender TEXT NOT NULL,
          content TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          read INTEGER NOT NULL DEFAULT 0
        )
      ''');
      final lanRows = await db.rawQuery('''
        SELECT
          client_id,
          MAX(timestamp) AS last_ts,
          (SELECT content FROM messages m2
           WHERE m2.client_id = m.client_id
           ORDER BY timestamp DESC LIMIT 1) AS last_message,
          (SELECT sender FROM messages m3
           WHERE m3.client_id = m.client_id
           ORDER BY timestamp DESC LIMIT 1) AS last_sender,
          SUM(CASE WHEN sender = 'buyer' AND read = 0 THEN 1 ELSE 0 END) AS unread
        FROM messages m
        GROUP BY client_id
        ORDER BY last_ts DESC
      ''');
      for (final r in lanRows) {
        convs.add(_Conversation(
          id: r['client_id'] as String,
          displayId: 'LAN · ${(r['client_id'] as String).substring(0, 8)}…',
          source: _Source.lan,
          lastMessage: r['last_message'] as String? ?? '',
          lastSender: r['last_sender'] as String? ?? 'buyer',
          lastTs: r['last_ts'] as int? ?? 0,
          unread: (r['unread'] as num?)?.toInt() ?? 0,
        ));
      }

      // ── Cloud threads (Supabase) ───────────────────────────────────────────
      if (shopId != null) {
        try {
          final cloudRows = await Supabase.instance.client
              .from('cloud_messages')
              .select('buyer_id, sender, content, created_at, read')
              .eq('shop_id', shopId)
              .order('created_at', ascending: false);

          // Group by buyer_id
          final Map<String, _Conversation> cloudMap = {};
          for (final r in (cloudRows as List)) {
            final buyerId = r['buyer_id'] as String;
            final ts = DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch;
            final isUnread = r['sender'] == 'buyer' && r['read'] == false;
            if (!cloudMap.containsKey(buyerId)) {
              cloudMap[buyerId] = _Conversation(
                id: buyerId,
                displayId: 'Cloud · ${buyerId.substring(0, 8)}…',
                source: _Source.cloud,
                lastMessage: r['content'] as String? ?? '',
                lastSender: r['sender'] as String? ?? 'buyer',
                lastTs: ts,
                unread: isUnread ? 1 : 0,
              );
            } else {
              final existing = cloudMap[buyerId]!;
              cloudMap[buyerId] = _Conversation(
                id: existing.id,
                displayId: existing.displayId,
                source: _Source.cloud,
                lastMessage: existing.lastMessage,
                lastSender: existing.lastSender,
                lastTs: existing.lastTs,
                unread: existing.unread + (isUnread ? 1 : 0),
              );
            }
          }
          convs.addAll(cloudMap.values);
        } catch (e) {
          debugPrint('BuyerInboxScreen: cloud fetch error: $e');
        }
      }

      // Sort by most recent
      convs.sort((a, b) => b.lastTs.compareTo(a.lastTs));

      if (!mounted) return;
      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalUnread => _conversations.fold(0, (s, c) => s + c.unread);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Buyer Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_totalUnread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(12)),
                child: Text('$_totalUnread', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(color: AppColors.gray100, height: 1),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryGreen,
                unselectedLabelColor: AppColors.gray400,
                indicatorColor: AppColors.primaryGreen,
                tabs: [
                  Tab(text: 'ALL (${_conversations.length})'),
                  Tab(text: 'UNREAD ($_totalUnread)'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_conversations),
                _buildList(_conversations.where((c) => c.unread > 0).toList()),
              ],
            ),
    );
  }

  Widget _buildList(List<_Conversation> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: AppColors.gray200),
            const SizedBox(height: 16),
            Text('No messages yet',
                style: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.gray500)),
            const SizedBox(height: 8),
            Text(
              'When a buyer sends a message from Mbeck Go\nit will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.gray400),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) => _buildTile(list[i]),
    );
  }

  Widget _buildTile(_Conversation conv) {
    final time = DateTime.fromMillisecondsSinceEpoch(conv.lastTs);
    final timeStr = _formatTime(time);
    final hasUnread = conv.unread > 0;
    final isCloud = conv.source == _Source.cloud;

    return ListTile(
      tileColor: hasUnread ? AppColors.primaryGreen.withOpacity(0.04) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: hasUnread ? AppColors.primaryGreen.withOpacity(0.15) : AppColors.gray100,
            child: Icon(Icons.person, color: hasUnread ? AppColors.primaryGreen : AppColors.gray400),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isCloud ? const Color(0xFF3B82F6) : AppColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(isCloud ? Icons.cloud : Icons.wifi, size: 9, color: Colors.white),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(conv.displayId,
                style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
          ),
          Text(timeStr,
              style: TextStyle(
                fontSize: 11,
                color: hasUnread ? AppColors.primaryGreen : AppColors.gray400,
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              )),
        ],
      ),
      subtitle: Row(
        children: [
          if (conv.lastSender == 'shop')
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.reply, size: 13, color: AppColors.gray400),
            ),
          Expanded(
            child: Text(conv.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: hasUnread ? AppColors.gray700 : AppColors.gray500,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                )),
          ),
          if (hasUnread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
              child: Text('${conv.unread}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ChatScreen(conv: conv)),
      ).then((_) => _load()),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// ─── Chat thread ─────────────────────────────────────────────────────────────

class _ChatScreen extends StatefulWidget {
  final _Conversation conv;
  const _ChatScreen({required this.conv});

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _pollTimer;
  bool _isSending = false;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
    AuthService.getShopId().then((id) => _shopId = id);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (widget.conv.source == _Source.lan) {
      await _fetchLan();
    } else {
      await _fetchCloud();
    }
  }

  Future<void> _fetchLan() async {
    try {
      final db = await DbProvider.db;
      final rows = await db.rawQuery(
        'SELECT id, sender, content, timestamp, read FROM messages WHERE client_id = ? ORDER BY timestamp ASC',
        [widget.conv.id],
      );
      await db.rawUpdate(
        "UPDATE messages SET read = 1 WHERE client_id = ? AND sender = 'buyer' AND read = 0",
        [widget.conv.id],
      );
      if (!mounted) return;
      setState(() {
        _messages..clear()..addAll(rows.map((r) => Map<String, dynamic>.from(r)));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _fetchCloud() async {
    try {
      final shopId = _shopId ?? await AuthService.getShopId();
      if (shopId == null) return;
      final rows = await Supabase.instance.client
          .from('cloud_messages')
          .select()
          .eq('shop_id', shopId)
          .eq('buyer_id', widget.conv.id)
          .order('created_at');
      // Mark buyer msgs as read (service-role write via direct SQL not possible
      // here — buyer marks their own. We just visually treat them as read.)
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll((rows as List).map((r) => {
            'id': r['id'],
            'sender': r['sender'],
            'content': r['content'],
            'timestamp': DateTime.parse(r['created_at'] as String).millisecondsSinceEpoch,
            'read': (r['read'] as bool? ?? false) ? 1 : 0,
          }));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    _inputCtrl.clear();
    setState(() => _isSending = true);

    final optimistic = {
      'id': -1, 'sender': 'shop', 'content': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch, 'read': 1,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      if (widget.conv.source == _Source.lan) {
        final db = await DbProvider.db;
        await db.insert('messages', {
          'client_id': widget.conv.id,
          'sender': 'shop',
          'content': text,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'read': 0,
        });
      } else {
        final shopId = _shopId ?? await AuthService.getShopId();
        await Supabase.instance.client.from('cloud_messages').insert({
          'shop_id': shopId,
          'buyer_id': widget.conv.id,
          'sender': 'shop',
          'content': text,
          'read': false,
        });
      }
      await _fetch();
    } catch (e) {
      if (mounted) {
        setState(() => _messages.remove(optimistic));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCloud = widget.conv.source == _Source.cloud;
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conv.displayId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Row(
              children: [
                Icon(isCloud ? Icons.cloud : Icons.wifi, size: 11,
                    color: isCloud ? const Color(0xFF3B82F6) : AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(isCloud ? 'Cloud buyer' : 'LAN buyer',
                    style: TextStyle(fontSize: 11, color: AppColors.gray400)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.gray100, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('No messages yet', style: TextStyle(color: AppColors.gray400)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isShop = msg['sender'] == 'shop';
    final content = msg['content'] as String? ?? '';
    final ts = msg['timestamp'] as int? ?? 0;
    final time = DateTime.fromMillisecondsSinceEpoch(ts);
    final timeStr = '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isShop ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isShop) ...[
            CircleAvatar(radius: 14, backgroundColor: AppColors.gray100,
                child: Icon(Icons.person, size: 16, color: AppColors.gray400)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isShop ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isShop ? AppColors.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isShop ? 16 : 4),
                      bottomRight: Radius.circular(isShop ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(content,
                      style: TextStyle(color: isShop ? Colors.white : AppColors.gray900, fontSize: 14)),
                ),
                const SizedBox(height: 2),
                Text(timeStr, style: TextStyle(fontSize: 10, color: AppColors.gray400)),
              ],
            ),
          ),
          if (isShop) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 8, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.gray100)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              minLines: 1, maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Reply to buyer…',
                hintStyle: TextStyle(color: AppColors.gray400),
                filled: true, fillColor: AppColors.gray50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primaryGreen,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSending ? null : _send,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _isSending
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

enum _Source { lan, cloud }

class _Conversation {
  final String id;
  final String displayId;
  final _Source source;
  final String lastMessage;
  final String lastSender;
  final int lastTs;
  final int unread;

  const _Conversation({
    required this.id,
    required this.displayId,
    required this.source,
    required this.lastMessage,
    required this.lastSender,
    required this.lastTs,
    required this.unread,
  });
}
