import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/dashboard_models.dart';
import '../presenters/dashboard_presenter.dart';

class SafetyAssistantPage extends StatefulWidget {
  const SafetyAssistantPage({
    super.key,
    required this.presenter,
    required this.storageKey,
  });

  final DashboardPresenter presenter;
  final String storageKey;

  @override
  State<SafetyAssistantPage> createState() => _SafetyAssistantPageState();
}

class _SafetyAssistantPageState extends State<SafetyAssistantPage> {
  static const _introTurn = _AssistantTurn(
    text: 'Hi! I’m Cyvora Safety Assistant. How can I help you stay safe online today? Ask about scams, suspicious messages, account security or privacy, and I’ll help you choose safer next steps.',
    isIntro: true,
  );

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantTurn> _turns = [_introTurn];
  bool _isSending = false;
  bool _isRestoring = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreConversation());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restoreConversation() async {
    try {
      final restoredEntries = await widget.presenter.loadAssistantConversation(
        widget.storageKey,
      );
      final restoredTurns = restoredEntries
          .map(
            (entry) => _AssistantTurn(
              text: entry.text,
              isUser: entry.isUser,
              isError: entry.isError,
            ),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _turns
          ..clear()
          ..add(_introTurn)
          ..addAll(restoredTurns);
        _isRestoring = false;
      });
      _scrollToLatest();
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _storageError = 'Could not load the saved chat from this device. Check local storage and reload.';
      });
    }
  }

  Future<bool> _saveConversation() async {
    try {
      await widget.presenter.saveAssistantConversation(widget.storageKey, [
        for (final turn in _turns)
          if (!turn.isIntro)
            AssistantConversationEntry(
              text: turn.text,
              isUser: turn.isUser,
              isError: turn.isError,
            ),
      ]);
      if (mounted) setState(() => _storageError = null);
      return true;
    } on Exception {
      if (mounted) {
        setState(() {
          _storageError = 'Could not save the chat on this device. Check available storage and keep the app open.';
        });
      }
      return false;
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isRestoring || _storageError != null) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _messageController.clear();
      _turns.add(_AssistantTurn(text: message, isUser: true));
      _isSending = true;
    });
    _scrollToLatest();
    if (!await _saveConversation()) {
      if (mounted) setState(() => _isSending = false);
      return;
    }
    final conversation = _conversationForRequest();

    try {
      final reply = await widget.presenter.chatSafetyAssistant(conversation);
      if (!mounted) return;
      setState(() => _turns.add(_AssistantTurn(text: reply)));
      await _saveConversation();
    } on AssistantRequestException catch (error) {
      if (!mounted) return;
      setState(
        () => _turns.add(_AssistantTurn(text: error.message, isError: true)),
      );
      await _saveConversation();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  List<AssistantChatMessage> _conversationForRequest() {
    final messages = <AssistantChatMessage>[];
    for (final turn in _turns) {
      if (turn.isIntro) continue;
      if (turn.isError) {
        if (messages.isNotEmpty && messages.last.role == 'user') {
          messages.removeLast();
        }
        continue;
      }
      messages.add(
        AssistantChatMessage(
          role: turn.isUser ? 'user' : 'assistant',
          content: turn.text,
        ),
      );
    }
    final recent = messages.length > 7
        ? messages.sublist(messages.length - 7)
        : messages;
    return [
      for (var index = 0; index < recent.length; index++)
        AssistantChatMessage(
          role: recent[index].role,
          content: index == recent.length - 1
              ? recent[index].content
              : _contextSnippet(recent[index].content),
        ),
    ];
  }

  String _contextSnippet(String value) {
    if (value.length <= 1000) return value;
    return '${value.substring(0, 1000)} [earlier text shortened]';
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('safety-assistant-page'),
      backgroundColor: const Color(0xFF10051F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0833),
        foregroundColor: const Color(0xFFFFFFFF),
        leading: IconButton(
          key: const Key('safety-assistant-back'),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            _AssistantAvatar(size: 38),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Safety Assistant',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Ask about staying safe online',
                  style: TextStyle(fontSize: 11, color: Color(0xFFC4B5FD)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0833), Color(0xFF10051F)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      key: const Key('safety-assistant-conversation'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      itemCount:
                          _turns.length + (_isSending || _isRestoring ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _turns.length && _isRestoring) {
                          return const _TypingIndicator(
                            label: 'Loading saved chat...',
                          );
                        }
                        if (_isSending && index == _turns.length) {
                          return const _TypingIndicator();
                        }
                        final turn = _turns[index];
                        return _AssistantMessageBubble(
                          key: Key('safety-assistant-message-$index'),
                          turn: turn,
                        );
                      },
                    ),
                  ),
                  _MessageComposer(
                    controller: _messageController,
                    isSending:
                        _isSending || _isRestoring || _storageError != null,
                    onSend: _sendMessage,
                  ),
                  if (_storageError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _storageError!,
                        style: const TextStyle(
                          color: Color(0xFFFF9999),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantTurn {
  const _AssistantTurn({
    this.text = '',
    this.isUser = false,
    this.isIntro = false,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isIntro;
  final bool isError;
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({super.key, required this.turn});

  final _AssistantTurn turn;

  @override
  Widget build(BuildContext context) {
    if (turn.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          margin: const EdgeInsets.only(bottom: 14, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3B0764),
            borderRadius: BorderRadius.circular(18)
                .copyWith(bottomRight: const Radius.circular(5)),
          ),
          child: Text(
            turn.text,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AssistantAvatar(size: 32),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cyvora',
                      style: TextStyle(
                        color: turn.isError
                            ? const Color(0xFFFF9999)
                            : const Color(0xFFFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4B5FD).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF291451),
                    borderRadius: BorderRadius.circular(16)
                        .copyWith(bottomLeft: const Radius.circular(5)),
                    border: Border.all(
                      color: turn.isError
                          ? const Color(0xFF803F52)
                          : const Color(0xFF452477),
                    ),
                  ),
                  child: SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _formatAssistantResponse(
                        turn.text,
                        color: turn.isError
                            ? const Color(0xFFFF9999)
                            : const Color(0xFFC4B5FD),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _formatAssistantResponse(String text, {required Color color}) {
  const bodyStyle = TextStyle(fontSize: 14, height: 1.55);
  final style = bodyStyle.copyWith(color: color);
  final widgets = <Widget>[];
  final paragraphLines = <String>[];

  void flushParagraph() {
    if (paragraphLines.isEmpty) return;
    widgets.add(
      Text.rich(
        _assistantInlineText(paragraphLines.join(' '), style),
        style: style,
      ),
    );
    widgets.add(const SizedBox(height: 9));
    paragraphLines.clear();
  }

  for (final rawLine in text.trim().split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }

    final heading = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(line);
    if (heading != null) {
      flushParagraph();
      final headingStyle = style.copyWith(
        color: const Color(0xFFFFFFFF),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      );
      widgets.add(
        Text.rich(_assistantInlineText(heading.group(1)!, headingStyle)),
      );
      widgets.add(const SizedBox(height: 7));
      continue;
    }

    final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
    final numbered = RegExp(r'^(\d+)[.)]\s+(.+)$').firstMatch(line);
    final listContent = bullet?.group(1) ?? numbered?.group(2);
    if (listContent != null) {
      flushParagraph();
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: bullet != null
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: Color(0xFFC4B5FD),
                        ),
                      )
                    : Text(
                        '${numbered!.group(1)}.',
                        style: style.copyWith(
                          color: const Color(0xFFC4B5FD),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              Expanded(
                child: Text.rich(
                  _assistantInlineText(listContent, style),
                  style: style,
                ),
              ),
            ],
          ),
        ),
      );
      continue;
    }

    paragraphLines.add(line);
  }

  flushParagraph();
  if (widgets.isNotEmpty && widgets.last is SizedBox) {
    widgets.removeLast();
  }
  return widgets;
}

TextSpan _assistantInlineText(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  final tokenPattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)');
  var cursor = 0;
  for (final match in tokenPattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final token = match.group(0)!;
    if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('`')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: style.copyWith(
            fontFamily: 'monospace',
            color: const Color(0xFFE9D5FF),
            backgroundColor: const Color(0xFF2E1065),
          ),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: style.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: style, children: spans);
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A0833),
        border: Border(top: BorderSide(color: Color(0xFF452477))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('safety-assistant-input'),
                    controller: controller,
                    enabled: !isSending,
                    maxLength: 5000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: 'Ask a question or tell me what happened...',
                      filled: true,
                      fillColor: const Color(0xFF291451),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFF452477)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFF452477)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    return IconButton.filled(
                      key: const Key('safety-assistant-send'),
                      tooltip: 'Send message',
                      onPressed: isSending || value.text.trim().isEmpty
                          ? null
                          : onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: const Color(0xFFFFFFFF),
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFFA78BFA),
                  size: 13,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chats are saved only on this device, not synced or added to Scan History. Clearing app or browser data removes them. Minimized text may be sent to a configured AI provider (provider data policies apply). Never include passwords or one-time codes.',
                    style: TextStyle(
                      color: Color(0xFFA78BFA),
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({this.label = 'Thinking...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _AssistantAvatar(size: 34),
          SizedBox(width: 9),
          Text(label, style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 12)),
          SizedBox(width: 10),
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF3B0764),
        borderRadius: BorderRadius.circular(size * 0.35),
        border: Border.all(color: const Color(0xFF7C3AED)),
      ),
      child: Icon(
        Icons.smart_toy_outlined,
        color: const Color(0xFFC4B5FD),
        size: size * 0.55,
      ),
    );
  }
}
