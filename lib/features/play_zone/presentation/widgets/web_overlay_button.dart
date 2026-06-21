import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Small circular HUD button rendered as a real DOM element (via
/// [HtmlElementView]) so that it sits ABOVE any sibling iframe
/// platform view in the DOM z-order and can receive pointer events.
///
/// The previous in-Flutter `GestureDetector` HUD buttons failed when
/// they were stacked over a [HtmlElementView] (iframe). Even though
/// Flutter draws them on top in the widget tree, the iframe is a
/// separate DOM element that consumes clicks in its area before
/// Flutter's pointer dispatch ever sees them. Rendering the button
/// itself as a DOM `<button>` element via another platform view puts
/// it on top of the iframe in the DOM and the browser routes the
/// click to the button.
///
/// On non-web platforms (where `kIsWeb` is false) we fall back to a
/// regular `GestureDetector` so this widget remains usable.
class WebOverlayButton extends StatefulWidget {
  const WebOverlayButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  State<WebOverlayButton> createState() => _WebOverlayButtonState();
}

class _WebOverlayButtonState extends State<WebOverlayButton> {
  late final String _viewType;
  late final web.HTMLButtonElement _element;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _viewType = '';
      _element = web.document.createElement('button') as web.HTMLButtonElement;
      return;
    }
    _viewType =
        'web-overlay-btn-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _element = _buildElement();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _element;
    });
  }

  @override
  void didUpdateWidget(covariant WebOverlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb) return;
    _element.title = widget.tooltip ?? '';
    _element.textContent = _iconChar(widget.icon);
  }

  @override
  void dispose() {
    if (kIsWeb) {
      try {
        _element.onclick = null;
      } catch (_) {}
    }
    super.dispose();
  }

  web.HTMLButtonElement _buildElement() {
    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.title = widget.tooltip ?? '';
    btn.textContent = _iconChar(widget.icon);
    btn.setAttribute('type', 'button');
    btn.setAttribute('aria-label', widget.tooltip ?? '');

    btn.style.width = '${widget.size}px';
    btn.style.height = '${widget.size}px';
    btn.style.borderRadius = '50%';
    btn.style.background = 'rgba(0, 0, 0, 0.45)';
    btn.style.border = '1px solid rgba(255, 245, 245, 0.25)';
    btn.style.color = '#FFF5F5';
    btn.style.fontSize = '${(widget.size * 0.55).clamp(14, 28).toInt()}px';
    btn.style.display = 'flex';
    btn.style.alignItems = 'center';
    btn.style.justifyContent = 'center';
    btn.style.cursor = 'pointer';
    btn.style.padding = '0';
    btn.style.margin = '0';
    btn.style.outline = 'none';
    btn.style.userSelect = 'none';
    btn.style.setProperty('-webkit-user-select', 'none');
    btn.style.setProperty('-webkit-tap-highlight-color', 'transparent');
    btn.style.fontFamily =
        'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    btn.style.lineHeight = '1';
    btn.style.boxSizing = 'border-box';
    btn.style.touchAction = 'manipulation';

    btn.onclick = ((web.Event _) => _handleClick()).toJS;
    btn.oncontextmenu = ((web.Event e) => e.preventDefault()).toJS;
    btn.ondragstart = ((web.Event e) => e.preventDefault()).toJS;

    return btn;
  }

  void _handleClick() {
    if (!mounted) return;
    widget.onTap();
    // Drop focus so the button doesn't stay in :focus state and so
    // the next click anywhere on the iframe doesn't replay a click
    // on this button.
    try {
      _element.blur();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFF5F5).withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: Icon(widget.icon, color: const Color(0xFFFFF5F5), size: 22),
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  String _iconChar(IconData icon) {
    final code = icon.codePoint;
    if (code == Icons.close_rounded.codePoint ||
        code == Icons.close.codePoint) {
      return '\u2715';
    }
    if (code == Icons.replay_rounded.codePoint ||
        code == Icons.replay.codePoint ||
        code == Icons.refresh_rounded.codePoint ||
        code == Icons.refresh.codePoint) {
      return '\u27F3';
    }
    if (code == Icons.flag_rounded.codePoint || code == Icons.flag.codePoint) {
      return '\u2691';
    }
    if (code == Icons.check_rounded.codePoint || code == Icons.check.codePoint) {
      return '\u2713';
    }
    if (code == Icons.arrow_back_ios_new_rounded.codePoint ||
        code == Icons.arrow_back_ios.codePoint ||
        code == Icons.arrow_back.codePoint) {
      return '\u2190';
    }
    if (code == Icons.arrow_forward_ios_rounded.codePoint ||
        code == Icons.arrow_forward_ios.codePoint ||
        code == Icons.arrow_forward.codePoint) {
      return '\u2192';
    }
    return String.fromCharCode(code);
  }
}

/// Large rectangular overlay button (gradient background, optional
/// leading icon + label) rendered as a DOM `<button>` element so it
/// sits above any sibling iframe platform view. Used for the
/// critical "I FINISHED!" finish button on multiplayer game
/// screens, which would otherwise be eaten by the iframe.
class WebOverlayTextButton extends StatefulWidget {
  const WebOverlayTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tooltip,
    this.busy = false,
    this.gradient = const [
      Color(0xFFF0A500), // warmAmber
      Color(0xFFC2185B), // deepRose
    ],
    this.borderColor,
    this.fullWidth = true,
    this.padding = const EdgeInsets.symmetric(vertical: 18),
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;
  final bool busy;
  final List<Color> gradient;
  final Color? borderColor;
  final bool fullWidth;
  final EdgeInsetsGeometry padding;

  @override
  State<WebOverlayTextButton> createState() => _WebOverlayTextButtonState();
}

class _WebOverlayTextButtonState extends State<WebOverlayTextButton> {
  late final String _viewType;
  late final web.HTMLButtonElement _element;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _viewType = '';
      _element = web.document.createElement('button') as web.HTMLButtonElement;
      return;
    }
    _viewType =
        'web-overlay-text-btn-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _element = _buildElement();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _element;
    });
  }

  @override
  void didUpdateWidget(covariant WebOverlayTextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb) return;
    _element.title = widget.tooltip ?? widget.label;
    _element.setAttribute('aria-label', widget.label);
    _element.setAttribute('aria-busy', widget.busy ? 'true' : 'false');
    _element.disabled = widget.busy;
    _element.style.opacity = widget.busy ? '0.7' : '1';
    _element.style.cursor = widget.busy ? 'default' : 'pointer';
    _element.textContent = widget.busy ? '\u2022\u2022\u2022' : widget.label;
    if (widget.icon != null && !widget.busy) {
      _element.textContent = '${_iconChar(widget.icon!)}  ${widget.label}';
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      try {
        _element.onclick = null;
      } catch (_) {}
    }
    super.dispose();
  }

  web.HTMLButtonElement _buildElement() {
    final btn = web.document.createElement('button') as web.HTMLButtonElement;
    btn.setAttribute('type', 'button');
    btn.title = widget.tooltip ?? widget.label;
    btn.setAttribute('aria-label', widget.label);
    btn.setAttribute('aria-busy', widget.busy ? 'true' : 'false');

    btn.style.width = '100%';
    btn.style.display = 'flex';
    btn.style.alignItems = 'center';
    btn.style.justifyContent = 'center';
    btn.style.gap = '10px';
    btn.style.fontFamily =
        'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    btn.style.fontSize = '18px';
    btn.style.fontWeight = '900';
    btn.style.letterSpacing = '3px';
    btn.style.color = '#FFF5F5';
    btn.style.textTransform = 'uppercase';
    btn.style.border = 'none';
    btn.style.borderRadius = '18px';
    btn.style.padding = '18px 24px';
    btn.style.cursor = widget.busy ? 'default' : 'pointer';
    btn.style.outline = 'none';
    btn.style.userSelect = 'none';
    btn.style.setProperty('-webkit-user-select', 'none');
    btn.style.setProperty('-webkit-tap-highlight-color', 'transparent');
    btn.style.boxSizing = 'border-box';
    btn.style.boxShadow = '0 6px 16px rgba(240, 165, 0, 0.4)';
    btn.style.touchAction = 'manipulation';
    btn.style.lineHeight = '1';
    btn.style.opacity = widget.busy ? '0.7' : '1';
    btn.disabled = widget.busy;
    _applyGradient(btn);
    if (widget.borderColor != null) {
      final c = widget.borderColor!;
      btn.style.border = '1.5px solid rgba(${_r(c)}, ${_g(c)}, ${_b(c)}, 0.6)';
    }
    if (widget.icon != null && !widget.busy) {
      btn.textContent = '${_iconChar(widget.icon!)}  ${widget.label}';
    } else {
      btn.textContent = widget.busy ? '\u2022\u2022\u2022' : widget.label;
    }

    btn.onclick = ((web.Event _) => _handleClick()).toJS;
    btn.oncontextmenu = ((web.Event e) => e.preventDefault()).toJS;
    return btn;
  }

  void _applyGradient(web.HTMLButtonElement btn) {
    if (widget.gradient.length < 2) {
      final c = widget.gradient.first;
      btn.style.background =
          'rgba(${_r(c)}, ${_g(c)}, ${_b(c)}, 1)';
      return;
    }
    final a = widget.gradient.first;
    final b = widget.gradient[1];
    btn.style.background =
        'linear-gradient(135deg, rgba(${_r(a)}, ${_g(a)}, ${_b(a)}, 1) 0%, rgba(${_r(b)}, ${_g(b)}, ${_b(b)}, 1) 100%)';
  }

  int _r(Color c) => (c.r * 255).round();
  int _g(Color c) => (c.g * 255).round();
  int _b(Color c) => (c.b * 255).round();

  void _handleClick() {
    if (!mounted) return;
    if (widget.busy) return;
    widget.onTap();
    try {
      _element.blur();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: widget.borderColor != null
                ? Border.all(
                    color: widget.borderColor!.withValues(alpha: 0.6),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFF5F5),
                    strokeWidth: 2.5,
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon, color: const Color(0xFFFFF5F5), size: 24),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFFFFF5F5),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.fullWidth ? double.infinity : null,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  String _iconChar(IconData icon) {
    final code = icon.codePoint;
    if (code == Icons.flag_rounded.codePoint || code == Icons.flag.codePoint) {
      return '\u2691';
    }
    if (code == Icons.check_rounded.codePoint || code == Icons.check.codePoint) {
      return '\u2713';
    }
    if (code == Icons.replay_rounded.codePoint ||
        code == Icons.replay.codePoint ||
        code == Icons.refresh_rounded.codePoint ||
        code == Icons.refresh.codePoint) {
      return '\u27F3';
    }
    if (code == Icons.close_rounded.codePoint ||
        code == Icons.close.codePoint) {
      return '\u2715';
    }
    return String.fromCharCode(code);
  }
}

/// Non-interactive status pill rendered as a DOM `<div>` so it can sit
/// above an iframe platform view. Used for the partner-status display
/// in the multiplayer game top bar.
class WebOverlayPill extends StatefulWidget {
  const WebOverlayPill({
    super.key,
    required this.text,
    this.leadingIcon,
    this.leadingIconColor,
    this.background = const Color(0x73000000),
    this.borderColor = const Color(0x2EFFF5F5),
    this.textColor = const Color(0xFFFFF5F5),
    this.expand = true,
  });

  final String text;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Color background;
  final Color borderColor;
  final Color textColor;
  final bool expand;

  @override
  State<WebOverlayPill> createState() => _WebOverlayPillState();
}

class _WebOverlayPillState extends State<WebOverlayPill> {
  late final String _viewType;
  late final web.HTMLDivElement _element;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _viewType = '';
      _element = web.document.createElement('div') as web.HTMLDivElement;
      return;
    }
    _viewType =
        'web-overlay-pill-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _element = _buildElement();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return _element;
    });
  }

  @override
  void didUpdateWidget(covariant WebOverlayPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb) return;
    if (oldWidget.text == widget.text &&
        oldWidget.leadingIcon == widget.leadingIcon &&
        oldWidget.leadingIconColor == widget.leadingIconColor &&
        oldWidget.background == widget.background &&
        oldWidget.borderColor == widget.borderColor &&
        oldWidget.textColor == widget.textColor) {
      return;
    }
    _element.style.background = _rgba(widget.background);
    _element.style.border = '1px solid ${_rgba(widget.borderColor)}';
    _element.style.color = _rgba(widget.textColor);
    _element.replaceChildren(_buildChildren().toJS);
  }

  @override
  void dispose() {
    super.dispose();
  }

  web.HTMLDivElement _buildElement() {
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.style.display = 'flex';
    div.style.alignItems = 'center';
    div.style.justifyContent = 'center';
    div.style.gap = '8px';
    div.style.height = '100%';
    div.style.minHeight = '36px';
    div.style.padding = '8px 16px';
    div.style.borderRadius = '20px';
    div.style.boxSizing = 'border-box';
    div.style.overflow = 'hidden';
    div.style.userSelect = 'none';
    div.style.setProperty('-webkit-user-select', 'none');
    div.style.fontFamily =
        'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    div.style.fontSize = '13px';
    div.style.fontWeight = '600';
    div.style.letterSpacing = '0.5px';
    div.style.background = _rgba(widget.background);
    div.style.border = '1px solid ${_rgba(widget.borderColor)}';
    div.style.color = _rgba(widget.textColor);
    div.replaceChildren(_buildChildren().toJS);
    return div;
  }

  List<web.Node> _buildChildren() {
    final children = <web.Node>[];
    if (widget.leadingIcon != null) {
      final iconSpan = web.document.createElement('span') as web.HTMLSpanElement;
      iconSpan.textContent = _iconChar(widget.leadingIcon!);
      iconSpan.style.fontSize = '18px';
      iconSpan.style.lineHeight = '1';
      iconSpan.style.color = widget.leadingIconColor != null
          ? _rgba(widget.leadingIconColor!)
          : _rgba(widget.textColor);
      children.add(iconSpan);
    }
    final textSpan = web.document.createElement('span') as web.HTMLSpanElement;
    textSpan.textContent = widget.text;
    textSpan.style.whiteSpace = 'nowrap';
    textSpan.style.overflow = 'hidden';
    textSpan.style.textOverflow = 'ellipsis';
    children.add(textSpan);
    return children;
  }

  String _rgba(Color c) =>
      'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, ${(c.b * 255).round()}, ${c.a})';

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.leadingIcon != null)
              Icon(
                widget.leadingIcon,
                color: widget.leadingIconColor ?? widget.textColor,
                size: 18,
              ),
            if (widget.leadingIcon != null) const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: widget.expand ? double.infinity : null,
      height: 40,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  String _iconChar(IconData icon) {
    final code = icon.codePoint;
    if (code == Icons.flag_rounded.codePoint || code == Icons.flag.codePoint) {
      return '\u2691';
    }
    if (code == Icons.check_rounded.codePoint || code == Icons.check.codePoint) {
      return '\u2713';
    }
    if (code == Icons.check_circle_rounded.codePoint ||
        code == Icons.check_circle.codePoint) {
      return '\u2713';
    }
    if (code == Icons.radio_button_unchecked_rounded.codePoint ||
        code == Icons.radio_button_unchecked.codePoint) {
      return '\u25EF';
    }
    if (code == Icons.replay_rounded.codePoint ||
        code == Icons.replay.codePoint ||
        code == Icons.refresh_rounded.codePoint ||
        code == Icons.refresh.codePoint) {
      return '\u27F3';
    }
    if (code == Icons.close_rounded.codePoint ||
        code == Icons.close.codePoint) {
      return '\u2715';
    }
    return String.fromCharCode(code);
  }
}
