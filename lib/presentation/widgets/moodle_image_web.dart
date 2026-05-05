import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'moodle_image_stub.dart' show MoodleImageError;

class MoodleImage extends StatefulWidget {
  final String src;
  final String? alt;
  final double maxHeight;

  const MoodleImage({
    super.key,
    required this.src,
    this.alt,
    this.maxHeight = 240,
  });

  @override
  State<MoodleImage> createState() => _MoodleImageState();
}

class _MoodleImageState extends State<MoodleImage> {
  static int _nextId = 0;

  late String _viewType;
  StreamSubscription<web.Event>? _errorSub;

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _registerElement();
  }

  @override
  void didUpdateWidget(covariant MoodleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src ||
        oldWidget.alt != widget.alt ||
        oldWidget.maxHeight != widget.maxHeight) {
      _errorSub?.cancel();
      _failed = false;
      _registerElement();
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return MoodleImageError(src: widget.src, alt: widget.alt);
    }

    return SizedBox(
      width: double.infinity,
      height: widget.maxHeight,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  void _registerElement() {
    _viewType = 'moodle-image-${_nextId++}';

    final image = web.HTMLImageElement()
      ..src = widget.src
      ..alt = widget.alt ?? '';
    image.setAttribute(
      'style',
      'display:block;max-width:100%;max-height:${widget.maxHeight}px;'
          'width:100%;height:100%;object-fit:contain;',
    );

    _errorSub = image.onError.listen((_) {
      if (mounted) setState(() => _failed = true);
    });

    final container = web.HTMLDivElement();
    container.setAttribute(
      'style',
      'width:100%;height:${widget.maxHeight}px;display:flex;'
          'align-items:center;justify-content:flex-start;overflow:hidden;',
    );
    container.appendChild(image);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => container,
    );
  }
}
