import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/encounter_card.dart';
import '../models/encounter_tier.dart';
import '../providers/encounter_feed_provider.dart';

/// 스침 피드 화면.
///
/// 등급별로 열리는 정보가 다르다: 스침은 이니셜·나이대만 흐리게, 인연 이상은
/// 이름·나이·한줄소개, 운명은 '지금 근처' 뱃지, 연결은 대화 열림 표시.
class EncountersScreen extends ConsumerWidget {
  const EncountersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(encounterFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('스침')),
      body: cards.isEmpty
          ? const _EmptyFeed()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cards.length,
              itemBuilder: (context, index) =>
                  _EncounterCardTile(card: cards[index]),
            ),
    );
  }
}

/// 스친 인연이 아직 없을 때의 빈 상태.
class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            '아직 스친 인연이 없어요',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 피드 카드 한 건을 등급에 맞춰 렌더한다.
class _EncounterCardTile extends ConsumerWidget {
  const _EncounterCardTile({required this.card});

  /// 렌더할 카드.
  final EncounterCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isBrush = card.tier == EncounterTier.brush;

    // 스침은 흐린 톤으로 낮춘다.
    final nameColor = isBrush ? colorScheme.outline : colorScheme.onSurface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isBrush
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer,
                  child: Text(
                    // 엔진 결합 시 이름 없는 카드가 올 수 있다 — 빈 문자열 가드.
                    card.displayName.isEmpty
                        ? '?'
                        : card.displayName.characters.first,
                    style: TextStyle(color: nameColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${card.displayName} · ${card.ageLabel}',
                    style: TextStyle(
                      color: nameColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _Badge(
                  label: card.tier.label,
                  background: colorScheme.secondaryContainer,
                  foreground: colorScheme.onSecondaryContainer,
                ),
                if (card.tier == EncounterTier.fate && card.isNearbyNow) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    label: '지금 근처',
                    background: colorScheme.tertiaryContainer,
                    foreground: colorScheme.onTertiaryContainer,
                  ),
                ],
              ],
            ),
            if (card.bio != null) ...[
              const SizedBox(height: 10),
              Text(
                card.bio!,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              card.contextLine,
              style: TextStyle(
                color: card.tier == EncounterTier.bond
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: card.tier == EncounterTier.bond
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 14, color: colorScheme.outline),
                const SizedBox(width: 2),
                Text(
                  card.placeLabel,
                  style: TextStyle(color: colorScheme.outline, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Icon(Icons.schedule, size: 14, color: colorScheme.outline),
                const SizedBox(width: 2),
                Text(
                  card.timeLabel,
                  style: TextStyle(color: colorScheme.outline, fontSize: 12),
                ),
                const Spacer(),
                _CardAction(card: card),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 하단의 등급별 액션. 연결은 대화 열림 표시, 그 외는 호감 토글 버튼.
class _CardAction extends ConsumerWidget {
  const _CardAction({required this.card});

  /// 대상 카드.
  final EncounterCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (card.tier) {
      case EncounterTier.connect:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '대화가 열렸어요',
              style: TextStyle(color: colorScheme.primary, fontSize: 13),
            ),
          ],
        );
      case EncounterTier.brush:
      case EncounterTier.bond:
      case EncounterTier.fate:
        return IconButton(
          icon: Icon(
            card.likedByMe ? Icons.favorite : Icons.favorite_border,
            color: card.likedByMe ? colorScheme.primary : colorScheme.outline,
          ),
          onPressed: () =>
              ref.read(encounterFeedProvider.notifier).toggleLike(card.id),
        );
    }
  }
}

/// 카드 상단에 붙는 소형 라벨 뱃지(등급·'지금 근처' 공용).
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  /// 뱃지 문구.
  final String label;

  /// 배경색.
  final Color background;

  /// 글자색.
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 12),
      ),
    );
  }
}
