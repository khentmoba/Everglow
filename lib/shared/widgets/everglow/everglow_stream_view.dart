import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/firestore_stream_utils.dart';
import '../../../core/utils/logger.dart';
import 'everglow_error_state.dart';
import 'everglow_skeleton.dart';

class EverglowStreamView<T> extends StatefulWidget {
  final Stream<T> stream;

  final bool guardFirstEvent;

  final String? streamLabel;

  final Widget Function(BuildContext context, T data) builder;

  final bool Function(T data)? isEmpty;

  final Widget? emptyView;

  final Widget? loadingView;

  final String? loadingMessage;

  final String errorMessage;

  final IconData errorIcon;

  final VoidCallback? onRetry;

  const EverglowStreamView({
    super.key,
    required this.stream,
    required this.builder,
    this.guardFirstEvent = true,
    this.streamLabel,
    this.isEmpty,
    this.emptyView,
    this.loadingView,
    this.loadingMessage,
    this.errorMessage = 'Could not load',
    this.errorIcon = Icons.cloud_off_outlined,
    this.onRetry,
  });

  @override
  State<EverglowStreamView<T>> createState() => _EverglowStreamViewState<T>();
}

class _EverglowStreamViewState<T> extends State<EverglowStreamView<T>> {
  late Stream<T> _stream;
  T? _lastData;
  Object? _loggedError;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  @override
  void didUpdateWidget(covariant EverglowStreamView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream ||
        oldWidget.guardFirstEvent != widget.guardFirstEvent) {
      _lastData = null;
      _loggedError = null;
      _updateStream();
    }
  }

  void _updateStream() {
    _stream = widget.guardFirstEvent
        ? withFirestoreTimeout(
            widget.stream,
            label: widget.streamLabel ?? 'stream',
          )
        : widget.stream;
  }

  bool _isTransient(Object? error) =>
      error is TimeoutException ||
      (error is FirebaseException &&
          const {
            'unavailable',
            'deadline-exceeded',
            'aborted',
            'cancelled',
            'resource-exhausted',
          }.contains(error.code));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      key: ObjectKey(_stream),
      stream: _stream,
      builder: (context, snap) {
        if (!snap.hasError &&
            (snap.connectionState == ConnectionState.active ||
                snap.connectionState == ConnectionState.done)) {
          _lastData = snap.data;
          _loggedError = null;
        }
        if (snap.hasError) {
          if (_loggedError != snap.error) {
            _loggedError = snap.error;
            Logger.e(widget.streamLabel ?? 'stream', error: snap.error);
          }
          if (!_isTransient(snap.error) || _lastData == null) {
            _lastData = null;
            return EverglowErrorState(
              message: widget.errorMessage,
              onRetry: widget.onRetry,
              icon: widget.errorIcon,
            );
          }
        }
        final data = _lastData;
        if (data == null) {
          return widget.loadingView ??
              EverglowLoadingState(message: widget.loadingMessage);
        }
        final content = widget.isEmpty?.call(data) == true
            ? widget.emptyView ?? const SizedBox.shrink()
            : widget.builder(context, data);
        return Stack(
          children: [
            content,
            if (snap.hasError)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: TextButton.icon(
                    onPressed: widget.onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.cloud_off_outlined, size: 16),
                    label: Text(
                      widget.onRetry == null
                          ? 'Could not refresh'
                          : 'Could not refresh · Retry',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
