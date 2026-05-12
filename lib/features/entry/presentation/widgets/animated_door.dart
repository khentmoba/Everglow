import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';

class AnimatedDoor extends StatefulWidget {
  final bool isUnlocked;
  final bool isError;
  final bool isRevealing;
  final Widget? keypad;
  final VoidCallback? onEntranceComplete;

  const AnimatedDoor({
    super.key,
    this.isUnlocked = false,
    this.isError = false,
    this.isRevealing = false,
    this.keypad,
    this.onEntranceComplete,
  });

  @override
  State<AnimatedDoor> createState() => _AnimatedDoorState();
}

class _AnimatedDoorState extends State<AnimatedDoor> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _swingController;
  late AnimationController _handleController;
  late AnimationController _zoomController;
  
  late Animation<double> _entranceAnimation;
  late Animation<double> _swingAnimation;
  late Animation<double> _handleAnimation;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();
    
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _swingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _handleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _swingAnimation = CurvedAnimation(
      parent: _swingController,
      curve: Curves.easeInOutCubic,
    );

    _handleAnimation = CurvedAnimation(
      parent: _handleController,
      curve: Curves.bounceOut,
    );

    _zoomAnimation = CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInQuint,
    );

    _entranceController.forward().then((_) {
      if (widget.onEntranceComplete != null) {
        widget.onEntranceComplete!();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedDoor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUnlocked && !oldWidget.isUnlocked) {
      _unlockSequence();
    }
    if (widget.isRevealing && !oldWidget.isRevealing) {
      _zoomController.forward();
    }
  }

  Future<void> _unlockSequence() async {
    await _handleController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _swingController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _swingController.dispose();
    _handleController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entranceAnimation, _swingAnimation, _zoomAnimation]),
      builder: (context, child) {
        final zoomScale = 1.0 + (4.0 * _zoomAnimation.value);
        return Transform.scale(
          scale: (0.8 + (0.2 * _entranceAnimation.value)) * zoomScale,
          child: Opacity(
            opacity: (_entranceAnimation.value * (1.0 - _zoomAnimation.value)).clamp(0.0, 1.0),
            child: Center(
              child: SizedBox(
                width: 300,
                height: 500,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Light Bloom behind the door
                    if (widget.isUnlocked)
                      _buildLightBloom(),
                    
                    // Door Frame (Shadow/Depth)
                    _buildDoorFrame(),
                    
                    // The Swinging Door Panel
                    Transform(
                      alignment: Alignment.centerLeft,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective
                        ..rotateY(-math.pi / 2 * _swingAnimation.value),
                      child: _buildDoorPanel(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLightBloom() {
    return AnimatedBuilder(
      animation: _swingAnimation,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 250 * _swingAnimation.value,
            height: 450 * _swingAnimation.value,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.8 * _swingAnimation.value),
                  blurRadius: 50,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDoorFrame() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.pink[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pink[100]!, width: 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildDoorPanel() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isError ? Colors.red[50] : Colors.pink[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.isError ? Colors.red[100]! : Colors.white.withOpacity(0.8),
            widget.isError ? Colors.red[50]! : Colors.pink[200]!,
          ],
          stops: [0.0, 1.0 - (0.5 * _swingAnimation.value)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2 - (0.1 * _swingAnimation.value)),
            blurRadius: 20,
            offset: Offset(10 * (1 - _swingAnimation.value), 10 * (1 - _swingAnimation.value)),
          ),
          // Inner glow
          BoxShadow(
            color: Colors.white.withOpacity(0.4),
            blurRadius: 2,
            spreadRadius: -2,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Door Panels (Beveled Look)
          _buildPanelBevels(),
          
          // Integrated Keypad Area
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: widget.keypad ?? const SizedBox.shrink(),
            ),
          ),
          
          // Door Handle
          Positioned(
            right: 20,
            top: 250,
            child: AnimatedBuilder(
              animation: _handleAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _handleAnimation.value * (math.pi / 4),
                  child: _buildHandle(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelBevels() {
    return Column(
      children: [
        Expanded(flex: 3, child: _bevelBox()),
        Expanded(flex: 1, child: _bevelBox()),
        Expanded(flex: 3, child: _bevelBox()),
      ],
    );
  }

  Widget _bevelBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return SizedBox(
      width: 60,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // The base of the handle
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber[100]!, Colors.amber[700]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // The lever
          Positioned(
            left: 15,
            child: Container(
              width: 50,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.amber[200]!, Colors.amber[800]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
