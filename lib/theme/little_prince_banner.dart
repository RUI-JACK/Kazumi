import 'package:flutter/material.dart';
import 'package:kazumi/theme/little_prince_theme.dart';

/// User-supplied illustration, displayed without cropping its character.
class LittlePrinceBanner extends StatelessWidget {
  const LittlePrinceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF0B1329) : const Color(0xFFF3F8F3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final artwork = LayoutBuilder(
          builder: (context, pictureConstraints) {
            final ratio =
                pictureConstraints.maxWidth / pictureConstraints.maxHeight;
            // At ordinary desktop widths, crop only the lower planet.
            // Very wide frames keep the entire illustration instead.
            return Image.asset(
              dark ? littlePrinceDarkArtwork : littlePrinceArtwork,
              fit: ratio > 1.71 && ratio <= 3.1 ? BoxFit.cover : BoxFit.contain,
              alignment: Alignment.topRight,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            );
          },
        );
        final caption = Text(
          'The Little Prince · Stars & Beyond',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontFamily: 'KirakiraScript',
            fontWeight: FontWeight.w400,
            fontSize: 20,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
        return Semantics(
          label: '小王子主题插画：小王子站在小行星上，周围是黄色星星。图片由用户提供。',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF182238) : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: dark ? const Color(0xFF354158) : const Color(0xFFDDE4D7),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.18 : 0.055),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: paper,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: compact || largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: dark ? 2674 / 1568 : 800 / 469,
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, 0.80, 1],
                            ).createShader(bounds),
                            child: artwork,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              Text(
                                'kirakira',
                                semanticsLabel: 'キラキラ',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colors.primary,
                                  fontFamily: 'KirakiraScript',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 34,
                                  height: 1.15,
                                  letterSpacing: 0,
                                ),
                              ),
                              caption,
                            ],
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 268,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: (constraints.maxWidth * 0.68).clamp(
                                0.0,
                                830.0,
                              ),
                              height: 268,
                              child: ShaderMask(
                                // Fade the image itself into one shared canvas.
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.white,
                                      ],
                                      stops: [0, 0.30, 1],
                                    ).createShader(bounds),
                                child: artwork,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: constraints.maxWidth * 0.42,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'kirakira',
                                      semanticsLabel: 'キラキラ',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            color: colors.primary,
                                            fontFamily: 'KirakiraScript',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 52,
                                            height: 1.15,
                                            letterSpacing: 0,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Keep your favorite stories among the stars.',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontFamily: 'KirakiraScript',
                                            fontWeight: FontWeight.w400,
                                            fontSize: 24,
                                            height: 1.35,
                                            letterSpacing: 0,
                                          ),
                                    ),
                                    const Spacer(),
                                    caption,
                                  ],
                                ),
                              ),
                            ),
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
}
