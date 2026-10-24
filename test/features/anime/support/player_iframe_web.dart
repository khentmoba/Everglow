import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

Object playerIframe(State state) => (state as dynamic).debugIframe;

void isolatePlayerIframe(State state) {
  final iframe = playerIframe(state) as web.HTMLIFrameElement;
  // Keep browser tests independent of third-party embeds and their ads.
  iframe.src = 'about:blank';
}
