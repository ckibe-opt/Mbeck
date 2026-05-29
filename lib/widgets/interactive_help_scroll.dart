import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/narrative_content_service.dart';
import '../theme/design_system.dart';

class InteractiveHelpScroll extends StatefulWidget {
  final String contextKey;

  const InteractiveHelpScroll({
    super.key,
    required this.contextKey,
  });

  @override
  State<InteractiveHelpScroll> createState() => _InteractiveHelpScrollState();
}

class _InteractiveHelpScrollState extends State<InteractiveHelpScroll> {
  bool _isExpanded = false;
  String _currentScreen = 'main';
  final List<String> _history = [];

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _currentScreen = 'main';
        _history.clear();
      }
    });
  }

  void _navigateToKeyword(String keyword) {
    final narrativeData = NarrativeContentService.getNarrative(widget.contextKey);
    if (narrativeData.containsKey(keyword)) {
      setState(() {
        _history.add(_currentScreen);
        _currentScreen = keyword;
      });
    }
  }

  void _goBack() {
    if (_history.isNotEmpty) {
      setState(() {
        _currentScreen = _history.removeLast();
      });
    }
  }

  List<TextSpan> _parseNarrativeText(String text) {
    final spans = <TextSpan>[];
    // Regex matches [Word]
    final RegExp exp = RegExp(r'\[(.*?)\]');
    int lastMatchEnd = 0;

    for (final RegExpMatch match in exp.allMatches(text)) {
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: AppColors.gray700, fontSize: 13, height: 1.5),
        ));
      }

      // Add the matched keyword
      final keyword = match.group(1)!;
      final isAvailable = NarrativeContentService.getNarrative(widget.contextKey).containsKey(keyword);

      spans.add(TextSpan(
        text: keyword,
        style: TextStyle(
          color: isAvailable ? AppColors.primaryGreen : AppColors.gray700,
          fontWeight: FontWeight.bold,
          decoration: isAvailable ? TextDecoration.underline : TextDecoration.none,
        ),
        recognizer: isAvailable
            ? (TapGestureRecognizer()..onTap = () => _navigateToKeyword(keyword))
            : null,
      ));

      lastMatchEnd = match.end;
    }

    // Add trailing text
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: AppColors.gray700, fontSize: 13, height: 1.5),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final expandedWidth = screenWidth * 0.7; // 70% of screen
    final narrativeData = NarrativeContentService.getNarrative(widget.contextKey);
    final isDataAvailable = narrativeData.isNotEmpty && narrativeData.containsKey('main');

    if (!isDataAvailable) {
      return const SizedBox.shrink(); 
    }

    final currentData = narrativeData[_currentScreen] ?? narrativeData['main']!;

    // Calculate safe constraints so it doesn't get crushed by keyboards
    final topOffset = 120.0;
    // Maximum height the scroll content can take without bleeding out
    final maxScrollHeight = screenWidth < 500 && MediaQuery.of(context).viewInsets.bottom > 0 
        ? screenWidth * 0.5 // severely compress if keyboard is open
        : MediaQuery.of(context).size.height * 0.6; // 60% of vertical real estate normally

    return Positioned(
      right: 0,
      top: topOffset, 
      // Removed bottom: 100 rigid constraint that caused the 8.0px RenderFlex overflow
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The Handle (slightly noticeable tab)
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              width: 32,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
              child: Icon(
                _isExpanded ? Icons.chevron_right : Icons.menu_book,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          // The Scroll Content
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            width: _isExpanded ? expandedWidth : 0,
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7), // Parchment-like color
              border: Border(
                left: BorderSide(color: Colors.brown.withOpacity(0.2), width: 1),
                top: BorderSide(color: Colors.brown.withOpacity(0.2), width: 1),
                bottom: BorderSide(color: Colors.brown.withOpacity(0.2), width: 1),
              ),
              boxShadow: _isExpanded 
                  ? [const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(-5, 0))]
                  : [],
            ),
            // Use SingleChildScrollView to prevent overflow when animating or if content is long
            child: _isExpanded
                ? ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxScrollHeight),
                    child: SingleChildScrollView(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_history.isNotEmpty)
                                GestureDetector(
                                  onTap: _goBack,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Icon(Icons.arrow_back, size: 18, color: AppColors.gray500),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  currentData['title'] as String,
                                  style: AppTypography.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'serif',
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              children: _parseNarrativeText(currentData['body'] as String),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
