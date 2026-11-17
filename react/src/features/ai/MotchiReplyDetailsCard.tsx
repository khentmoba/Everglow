// Port of lib/features/ai/presentation/widgets/motchi_reply_details_card.dart.
import { useState } from 'react';
import { AppColors, Derived } from '../../core/theme/colors';
import { AppRadius, AppSpacing } from '../../core/theme/layout';
import { lineHeight } from '../../core/theme/paint';
import { AppTypography } from '../../core/theme/typography';
import { AlertDialog, showDialog, TextButton } from '../../shared/widgets/Dialogs';
import { Icon } from '../../shared/widgets/Icon';
import { Tooltip } from '../../shared/widgets/Tooltip';
import { detailsEmpty, detailsNeedAttention, detailsSummary, memoryOwner, type Json, type ReplyDetails } from './motchiDomain';

async function inspectMemory(memory: Json, onCorrectMemory?: (prompt: string) => void) {
  const initialFact = `${memory.fact ?? ''}`;
  const correction = await showDialog<string>((close) => (
    <MemoryCorrectionDialog memory={memory} initialFact={initialFact} onClose={close} />
  ));
  if (correction && onCorrectMemory) {
    onCorrectMemory(
      `Correct the saved memory with memory_id "${memory.id}": "${correction}". Use edit_memory to update this exact id, not remember_fact; update only this fact and do not turn one person's preference into a shared preference.`,
    );
  }
}

function MemoryCorrectionDialog({
  memory,
  initialFact,
  onClose,
}: {
  memory: Json;
  initialFact: string;
  onClose: (v: string | null) => void;
}) {
  const [text, setText] = useState(initialFact);
  const provenance =
    memory.provenance === 'self_report'
      ? 'Saved from their own words.'
      : memory.provenance === 'partner_report'
        ? 'Reported by their partner.'
        : 'Explicitly saved or corrected.';
  const sourceText = `${memory.sourceText ?? ''}`;
  const trimmed = text.trim();
  const canSave = trimmed.length > 0 && trimmed !== initialFact;

  return (
    <AlertDialog
      background={AppColors.velvet}
      title="Memory behind this reply"
      content={
        <div style={{ display: 'flex', flexDirection: 'column', gap: AppSpacing.sm, color: Derived.textMedium }}>
          <div style={{ ...AppTypography.labelSmall, lineHeight: lineHeight(11) }}>{memoryOwner(memory)}</div>
          <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) }}>{initialFact}</div>
          {memory.provenance != null && (
            <>
              <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>{provenance}</div>
              {sourceText !== '' && (
                <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) }}>“{sourceText}”</div>
              )}
            </>
          )}
          <div style={{ height: 4 }} />
          <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>
            This is the saved fact Motchi cited for this reply. If it has changed, tell her the correct version.
          </div>
          <div style={{ height: 4 }} />
          <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span style={{ ...AppTypography.labelSmall, color: Derived.textMuted }}>Correct version</span>
            <textarea
              value={text}
              maxLength={500}
              rows={3}
              onChange={(e) => setText(e.target.value.slice(0, 500))}
              style={{
                width: '100%',
                minHeight: 72,
                padding: '10px 12px',
                borderRadius: AppRadius.sm,
                border: `1px solid ${Derived.border}`,
                background: AppColors.inkDeep,
                color: Derived.textHigh,
                ...AppTypography.bodyMedium,
                outline: 'none',
                resize: 'vertical',
              }}
            />
          </label>
        </div>
      }
      actions={[
        <TextButton key="close" onPressed={() => onClose(null)}>
          Close
        </TextButton>,
        <TextButton key="save" onPressed={canSave ? () => onClose(trimmed) : undefined}>
          Ask Motchi to correct it
        </TextButton>,
      ]}
    />
  );
}

const FEEDBACK_REASONS: Array<[value: string, label: string]> = [
  ['seen', 'I’ve seen it'],
  ['not_tonight', 'Not my mood tonight'],
  ['too_long', 'Too long for me'],
  ['more_like_this', 'More like this'],
];

function RecommendationFeedbackRow({ title, onSelect }: { title: string; onSelect?: (reason: string) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div style={{ position: 'relative' }}>
      <Tooltip message={`Feedback for ${title}`}>
        <button
          type="button"
          className="bare-button"
          disabled={!onSelect}
          onClick={() => setOpen((v) => !v)}
          style={{
            width: '100%',
            minHeight: 48,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            cursor: onSelect ? 'pointer' : 'default',
            opacity: onSelect ? 1 : 0.6,
          }}
        >
          <span style={{ flex: 1, textAlign: 'left', ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) }}>{title}</span>
          <Icon name="tune" size={20} color={Derived.textHigh} />
        </button>
      </Tooltip>
      {open && onSelect && (
        <>
          <div onClick={() => setOpen(false)} style={{ position: 'fixed', inset: 0, zIndex: 999 }} />
          <div
            style={{
              position: 'absolute',
              right: 0,
              top: 44,
              minWidth: 200,
              padding: 6,
              borderRadius: AppRadius.lg,
              background: AppColors.silk,
              border: `1px solid ${Derived.border}`,
              boxShadow: '0 8px 24px rgba(0,0,0,0.45)',
              zIndex: 1000,
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            {FEEDBACK_REASONS.map(([value, label]) => (
              <button
                key={value}
                type="button"
                className="bare-button"
                onClick={() => {
                  setOpen(false);
                  onSelect(value);
                }}
                style={{
                  padding: '10px 12px',
                  borderRadius: AppRadius.sm,
                  ...AppTypography.bodyMedium,
                  color: Derived.textHigh,
                  textAlign: 'left',
                }}
              >
                {label}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

export function MotchiReplyDetailsCard({
  details,
  onCorrectMemory,
  onOpenMemoryBook,
  onContinue,
  onRecommendationFeedback,
}: {
  details: ReplyDetails;
  onCorrectMemory?: (prompt: string) => void;
  onOpenMemoryBook?: () => void;
  onContinue?: () => void;
  onRecommendationFeedback?: (feedback: Record<string, unknown>) => void;
}) {
  if (detailsEmpty(details)) return null;
  const needsAttention = detailsNeedAttention(details);

  return (
    <div
      style={{
        width: '100%',
        padding: AppSpacing.md,
        background: Derived.panelGlass,
        borderRadius: AppRadius.md,
        border: `1px solid ${Derived.border}`,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {details.recommendations.length > 0 && (
        <>
          <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>Help Motchi choose better next time</div>
          {details.recommendations.map((movie, i) => {
            const title = `${movie.title ?? ''}`;
            return (
              <RecommendationFeedbackRow
                key={`${title}_${i}`}
                title={title}
                onSelect={
                  onRecommendationFeedback ? (reason) => onRecommendationFeedback({ title: movie.title, reason }) : undefined
                }
              />
            );
          })}
          <div style={{ height: AppSpacing.sm }} />
        </>
      )}

      {(details.steps.length > 0 || details.interrupted) && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', gap: AppSpacing.sm }}>
            <Icon name={needsAttention ? 'info_outline' : 'task_alt'} size={20} color={AppColors.softLavender} />
            <span style={{ flex: 1, ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>What happened</span>
          </div>
          <div style={{ height: AppSpacing.xs }} />
          <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color: Derived.textMedium }}>
            {detailsSummary(details)}
          </div>
          {details.steps.map((step, i) => (
            <div key={i} style={{ paddingTop: AppSpacing.sm }}>
              <StepRow step={step} />
            </div>
          ))}
        </>
      )}

      {needsAttention && onContinue && (
        <button
          type="button"
          className="bare-button"
          onClick={onContinue}
          style={{
            minHeight: 48,
            padding: '0 12px',
            display: 'inline-flex',
            alignItems: 'center',
            alignSelf: 'flex-start',
            ...AppTypography.labelLarge,
            color: AppColors.softLavender,
          }}
        >
          Help finish unfinished steps
        </button>
      )}

      {details.memories.length > 0 && (
        <>
          {details.steps.length > 0 && <div style={{ height: AppSpacing.md }} />}
          <div style={{ ...AppTypography.bodyMedium, lineHeight: lineHeight(14) }}>Memories Motchi cited</div>
          <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5) }}>
            These saved facts helped shape this reply.
          </div>
          {details.memories.map((memory, i) => (
            <button
              key={`${memory.id ?? i}`}
              type="button"
              className="bare-button"
              onClick={() => void inspectMemory(memory, onCorrectMemory)}
              style={{
                minHeight: 48,
                padding: '6px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: AppSpacing.sm,
                width: '100%',
                textAlign: 'left',
              }}
            >
              <Icon name="psychology_outlined" size={18} color={AppColors.softLavender} />
              <span
                className="clamp-2"
                style={{
                  flex: 1,
                  ...AppTypography.labelLarge,
                  fontWeight: 500,
                  color: Derived.textHigh,
                  lineHeight: lineHeight(14),
                }}
              >
                {memoryOwner(memory)} · {String(memory.fact ?? '')}
              </span>
              <Icon name="chevron_right" size={18} color={Derived.textHigh} />
            </button>
          ))}
          {onOpenMemoryBook && (
            <button
              type="button"
              className="bare-button"
              onClick={onOpenMemoryBook}
              style={{
                minHeight: 48,
                padding: '0 12px',
                display: 'inline-flex',
                alignItems: 'center',
                alignSelf: 'flex-start',
                ...AppTypography.labelLarge,
                color: AppColors.softLavender,
              }}
            >
              Open Memory Book
            </button>
          )}
        </>
      )}
    </div>
  );
}

function StepRow({ step }: { step: Json }) {
  const status = `${step.status ?? ''}`;
  const [icon, label, color] =
    status === 'done'
      ? ['check_circle_outline', 'Done', AppColors.softLavender]
      : status === 'waiting'
        ? ['help_outline', 'Waiting for you', AppColors.blushGold]
        : status === 'failed'
          ? ['error_outline', 'Did not complete', AppColors.error]
          : status === 'unscheduled'
            ? ['schedule', 'Saved, but not scheduled', AppColors.blushGold]
            : ['help_outline', 'Could not confirm', AppColors.blushGold];
  const tool = `${step.tool ?? ''}`.replaceAll('_', ' ');
  const title = `${step.title ?? ''}`;
  return (
    <div style={{ padding: `${AppSpacing.sm}px 0`, display: 'flex', alignItems: 'flex-start', gap: AppSpacing.sm }}>
      <div style={{ paddingTop: 2 }}>
        <Icon name={icon} size={20} color={color} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            ...AppTypography.bodySmall,
            lineHeight: lineHeight(12.5),
            color: Derived.textHigh,
            fontWeight: 600,
          }}
        >
          {tool === '' ? 'Action' : `${tool[0].toUpperCase()}${tool.slice(1)}`}
        </div>
        <div style={{ height: 3 }} />
        <div style={{ ...AppTypography.bodySmall, lineHeight: lineHeight(12.5), color }}>{label}</div>
        {title !== '' && (
          <>
            <div style={{ height: 4 }} />
            <div style={{ ...AppTypography.bodySmall, color: Derived.textMedium, lineHeight: lineHeight(12.5, 1.4) }}>
              {title}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
