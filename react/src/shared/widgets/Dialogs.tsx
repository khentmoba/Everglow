// Flutter's showDialog + Material 3 AlertDialog / SimpleDialog / TextButton,
// themed the way app_theme.dart themes them (panelGlass with the deepRose
// surface tint at elevation 6, 24px radius, a border, inkDeep @ 72% barrier).
import { useEffect, useState, type CSSProperties, type ReactNode } from "react";
import { ValueNotifier, useValue } from "../../core/system/store";
import { AppColors, Derived, withAlpha } from "../../core/theme/colors";
import { AppRadius } from "../../core/theme/layout";
import { orZero } from "../../core/theme/motion";
import { lineHeight } from "../../core/theme/paint";
import { AppTypography } from "../../core/theme/typography";

type Entry = {
  id: number;
  render: (close: (v: unknown) => void) => ReactNode;
  resolve: (v: unknown) => void;
};

const stack = new ValueNotifier<Entry[]>([]);
let nextId = 1;

/** `showDialog`: resolves with the value passed to `close`, or null when the barrier is tapped. */
export function showDialog<R>(
  render: (close: (value: R | null) => void) => ReactNode,
): Promise<R | null> {
  return new Promise((resolve) => {
    const entry: Entry = {
      id: nextId++,
      render: render as Entry["render"],
      resolve: resolve as Entry["resolve"],
    };
    stack.value = [...stack.value, entry];
  });
}

function closeEntry(entry: Entry, value: unknown) {
  stack.value = stack.value.filter((e) => e.id !== entry.id);
  entry.resolve(value);
}

export function DialogHost() {
  const entries = useValue(stack);
  return (
    <>
      {entries.map((e) => (
        <DialogRoute key={e.id} entry={e} />
      ))}
    </>
  );
}

function DialogRoute({ entry }: { entry: Entry }) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const raf = requestAnimationFrame(() => setShown(true));
    const onKey = (ev: KeyboardEvent) => {
      if (ev.key === "Escape") closeEntry(entry, null);
    };
    window.addEventListener("keydown", onKey);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("keydown", onKey);
    };
  }, [entry]);
  return (
    <div
      role="dialog"
      aria-modal
      onClick={() => closeEntry(entry, null)}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 800,
        background: withAlpha(AppColors.inkDeep, 0.72),
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px 40px",
        opacity: shown ? 1 : 0,
        transition: `opacity ${orZero(150)}ms cubic-bezier(0, 0, 0.58, 1)`,
      }}
    >
      <div
        onClick={(ev) => ev.stopPropagation()}
        style={{ display: "contents" }}
      >
        {entry.render((v) => closeEntry(entry, v))}
      </div>
    </div>
  );
}

// M3 dialogs in Flutter 3.47 have no surface tint and no shadow.
function dialogBox(
  background: string,
  radius = AppRadius.x2,
  border = true,
): CSSProperties {
  return {
    minWidth: 280,
    background,
    borderRadius: radius,
    border: border ? `1px solid ${Derived.border}` : undefined,
    boxSizing: "border-box",
    overflow: "hidden",
  };
}

/** Flutter `Dialog` with its own shape: fills the inset width (40px sides, 24px top/bottom). */
export function DialogPanel({
  background = Derived.panelGlass,
  radius = AppRadius.x2,
  border = true,
  children,
  style,
}: {
  background?: string;
  radius?: number;
  border?: boolean;
  children: ReactNode;
  style?: CSSProperties;
}) {
  return (
    <div
      style={{
        ...dialogBox(background, radius, border),
        width: "100%",
        maxHeight: "100%",
        overflowY: "auto",
        ...style,
      }}
    >
      {children}
    </div>
  );
}

/** Dialog title text: headlineSmall merged with Everglow's cormorantBold title. */
export const dialogTitleStyle: CSSProperties = {
  ...AppTypography.cormorantBold,
  fontSize: 24,
  lineHeight: lineHeight(24, 32 / 24),
  color: AppColors.petalWhite,
};

export function AlertDialog({
  title,
  content,
  actions,
  background = Derived.panelGlass,
}: {
  title?: ReactNode;
  content?: ReactNode;
  actions?: ReactNode[];
  background?: string;
}) {
  return (
    <div style={{ ...dialogBox(background), maxWidth: 560 }}>
      {title != null && (
        <div
          style={{
            padding: `24px 24px ${content == null ? 20 : 16}px`,
            ...dialogTitleStyle,
          }}
        >
          {title}
        </div>
      )}
      {content != null && (
        <div style={{ padding: `${title == null ? 24 : 0}px 24px 24px` }}>
          {content}
        </div>
      )}
      {actions && actions.length > 0 && (
        <div
          style={{
            padding: "0 24px 24px",
            display: "flex",
            justifyContent: "flex-end",
            flexWrap: "wrap",
            gap: 8,
          }}
        >
          {actions}
        </div>
      )}
    </div>
  );
}

export function SimpleDialog({
  title,
  children,
  background = Derived.panelGlass,
}: {
  title?: ReactNode;
  children: ReactNode;
  background?: string;
}) {
  return (
    <div
      style={{ ...dialogBox(background), maxWidth: 560, width: "fit-content" }}
    >
      {title != null && (
        <div style={{ padding: "24px 24px 0", ...dialogTitleStyle }}>
          {title}
        </div>
      )}
      <div
        style={{ padding: `12px 0 16px`, maxHeight: "70vh", overflowY: "auto" }}
      >
        {children}
      </div>
    </div>
  );
}

export function SimpleDialogOption({
  onPressed,
  children,
}: {
  onPressed: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      className="bare-button"
      onClick={onPressed}
      style={{
        display: "block",
        width: "100%",
        textAlign: "left",
        padding: "8px 24px",
      }}
    >
      {children}
    </button>
  );
}

/** Material 3 TextButton: 40px tall, 12px sides, labelLarge in the primary colour. */
export function TextButton({
  onPressed,
  children,
  color = AppColors.deepRose,
  icon,
  style,
}: {
  onPressed?: () => void;
  children: ReactNode;
  color?: string;
  icon?: ReactNode;
  style?: CSSProperties;
}) {
  const [hovered, setHovered] = useState(false);
  // The 48px slot is Material's padded tap target; the visible button stays 40px.
  return (
    <div style={{ height: 48, display: "flex", alignItems: "center" }}>
      <button
        type="button"
        className="bare-button"
        onClick={onPressed}
        onMouseEnter={() => setHovered(true)}
        onMouseLeave={() => setHovered(false)}
        style={{
          minWidth: 64,
          height: 40,
          padding: icon ? "0 16px 0 12px" : "0 12px",
          borderRadius: 20,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 8,
          background: hovered ? withAlpha(color, 0.08) : "transparent",
          ...AppTypography.labelLarge,
          lineHeight: lineHeight(14),
          color,
          ...style,
        }}
      >
        {icon}
        {children}
      </button>
    </div>
  );
}
