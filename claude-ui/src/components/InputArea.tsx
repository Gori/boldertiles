import {
  useState,
  useRef,
  useCallback,
  useEffect,
  useLayoutEffect,
  type KeyboardEvent,
  type DragEvent,
} from "react";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Props {
  isStreaming: boolean;
  onSend: (text: string, images?: string[]) => void;
  onCancel: () => void;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const MAX_TEXTAREA_PX = 160;
const MAX_HISTORY = 50;
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;
const ACCEPTED_IMAGE_TYPES = ["image/png", "image/jpeg", "image/gif", "image/webp"];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function readFileAsBase64(file: File): Promise<string | null> {
  return new Promise((resolve) => {
    if (file.size > MAX_IMAGE_BYTES) {
      resolve(null);
      return;
    }
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      const base64 = result.split(",")[1];
      resolve(base64 ?? null);
    };
    reader.onerror = () => resolve(null);
    reader.readAsDataURL(file);
  });
}

function isImageType(type: string): boolean {
  return ACCEPTED_IMAGE_TYPES.includes(type);
}

async function processFiles(files: File[]): Promise<string[]> {
  const results = await Promise.all(files.map(readFileAsBase64));
  return results.filter(Boolean) as string[];
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

function ArrowUpIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 14V4M5 8l4-4 4 4" />
    </svg>
  );
}

function PlusIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
      <path d="M9 3.5v11M3.5 9h11" />
    </svg>
  );
}

function StopIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
      <rect x="2" y="2" width="10" height="10" rx="1.5" />
    </svg>
  );
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function InputArea({ isStreaming, onSend, onCancel }: Props) {
  const [text, setText] = useState("");
  const [images, setImages] = useState<string[]>([]);
  const [isDragging, setIsDragging] = useState(false);

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const historyRef = useRef<string[]>([]);
  const historyIndexRef = useRef(-1);
  const draftRef = useRef("");
  const dragCounterRef = useRef(0);

  // ---- Focus management --------------------------------------------------

  useEffect(() => {
    textareaRef.current?.focus();
  }, []);

  const prevStreamingRef = useRef(isStreaming);
  useEffect(() => {
    if (prevStreamingRef.current && !isStreaming) {
      textareaRef.current?.focus();
    }
    prevStreamingRef.current = isStreaming;
  }, [isStreaming]);

  // ---- Auto-resize -------------------------------------------------------

  const resize = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, MAX_TEXTAREA_PX) + "px";
  }, []);

  useLayoutEffect(resize, [text, resize]);

  // ---- Submit -------------------------------------------------------------

  const submit = useCallback(() => {
    const trimmed = text.trim();
    if (!trimmed && images.length === 0) return;
    if (isStreaming) return;

    if (trimmed) {
      historyRef.current = [trimmed, ...historyRef.current].slice(0, MAX_HISTORY);
    }
    historyIndexRef.current = -1;
    draftRef.current = "";

    onSend(trimmed, images.length > 0 ? images : undefined);
    setText("");
    setImages([]);
  }, [text, images, isStreaming, onSend]);

  // ---- Keyboard -----------------------------------------------------------

  const handleKeyDown = useCallback(
    (e: KeyboardEvent<HTMLTextAreaElement>) => {
      const el = textareaRef.current;

      // Cmd/Ctrl+Enter → insert newline.
      if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        const start = el?.selectionStart ?? text.length;
        const end = el?.selectionEnd ?? text.length;
        const next = text.slice(0, start) + "\n" + text.slice(end);
        setText(next);
        requestAnimationFrame(() => {
          el?.setSelectionRange(start + 1, start + 1);
        });
        return;
      }

      // Enter → send.
      if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) {
        e.preventDefault();
        submit();
        return;
      }

      // Escape → cancel streaming or clear input.
      if (e.key === "Escape") {
        if (isStreaming) {
          onCancel();
        } else if (text || images.length > 0) {
          setText("");
          setImages([]);
        }
        return;
      }

      // Up arrow at position 0 → input history.
      if (e.key === "ArrowUp" && el && el.selectionStart === 0 && el.selectionEnd === 0) {
        const hist = historyRef.current;
        if (hist.length === 0) return;
        e.preventDefault();
        if (historyIndexRef.current === -1) {
          draftRef.current = text;
        }
        const next = Math.min(historyIndexRef.current + 1, hist.length - 1);
        historyIndexRef.current = next;
        setText(hist[next]!);
        return;
      }

      // Down arrow → history forward.
      if (e.key === "ArrowDown" && historyIndexRef.current >= 0) {
        e.preventDefault();
        const next = historyIndexRef.current - 1;
        if (next < 0) {
          historyIndexRef.current = -1;
          setText(draftRef.current);
        } else {
          historyIndexRef.current = next;
          setText(historyRef.current[next]!);
        }
        return;
      }
    },
    [submit, isStreaming, onCancel, text, images],
  );

  // ---- Paste images -------------------------------------------------------

  const handlePaste = useCallback(
    async (e: React.ClipboardEvent<HTMLTextAreaElement>) => {
      const items = Array.from(e.clipboardData.items);
      const imageItems = items.filter((item) => isImageType(item.type));
      if (imageItems.length === 0) return;

      e.preventDefault();
      const files = imageItems.map((item) => item.getAsFile()).filter(Boolean) as File[];
      const valid = await processFiles(files);
      if (valid.length > 0) setImages((prev) => [...prev, ...valid]);
    },
    [],
  );

  // ---- Drag and drop ------------------------------------------------------

  const handleDragEnter = useCallback((e: DragEvent) => {
    e.preventDefault();
    dragCounterRef.current++;
    if (dragCounterRef.current === 1) setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: DragEvent) => {
    e.preventDefault();
    dragCounterRef.current--;
    if (dragCounterRef.current === 0) setIsDragging(false);
  }, []);

  const handleDragOver = useCallback((e: DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
  }, []);

  const handleDrop = useCallback(async (e: DragEvent) => {
    e.preventDefault();
    dragCounterRef.current = 0;
    setIsDragging(false);
    const files = Array.from(e.dataTransfer.files).filter((f) => isImageType(f.type));
    if (files.length === 0) return;
    const valid = await processFiles(files);
    if (valid.length > 0) setImages((prev) => [...prev, ...valid]);
    textareaRef.current?.focus();
  }, []);

  // ---- File picker --------------------------------------------------------

  const openFilePicker = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const handleFileChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = Array.from(e.target.files ?? []).filter((f) => isImageType(f.type));
      if (files.length === 0) return;
      const valid = await processFiles(files);
      if (valid.length > 0) setImages((prev) => [...prev, ...valid]);
      e.target.value = "";
      textareaRef.current?.focus();
    },
    [],
  );

  // ---- Remove image -------------------------------------------------------

  const removeImage = useCallback((index: number) => {
    setImages((prev) => prev.filter((_, i) => i !== index));
    textareaRef.current?.focus();
  }, []);

  // ---- Derived state ------------------------------------------------------

  const canSend = !isStreaming && (text.trim().length > 0 || images.length > 0);

  // ---- Render -------------------------------------------------------------

  return (
    <div className="px-4 pb-4 pt-2 shrink-0">
      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept={ACCEPTED_IMAGE_TYPES.join(",")}
        multiple
        className="hidden"
        onChange={handleFileChange}
      />

      <div
        className="max-w-3xl mx-auto relative"
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
      >
        {/* Drop zone overlay */}
        {isDragging && (
          <div className="absolute inset-0 rounded-2xl border-2 border-dashed border-indigo-500/50 bg-indigo-500/5 flex items-center justify-center z-20 pointer-events-none">
            <span className="text-sm text-indigo-400">Drop images here</span>
          </div>
        )}

        {/* Unified input card */}
        <div className="rounded-2xl border border-zinc-700 bg-zinc-800 overflow-hidden">
          {/* Image previews */}
          {images.length > 0 && (
            <div className="flex gap-2 px-4 pt-3 flex-wrap">
              {images.map((img, i) => (
                <div key={i} className="relative group">
                  <img
                    src={`data:image/png;base64,${img}`}
                    alt={`Attachment ${i + 1}`}
                    className="h-14 w-14 object-cover rounded-lg border border-zinc-600"
                  />
                  <button
                    onClick={() => removeImage(i)}
                    aria-label={`Remove image ${i + 1}`}
                    className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-zinc-600 hover:bg-zinc-500 rounded-full text-[10px] text-zinc-200 hidden group-hover:flex items-center justify-center transition-colors"
                  >
                    &times;
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Textarea */}
          <textarea
            ref={textareaRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={handleKeyDown}
            onPaste={handlePaste}
            placeholder="Send a message..."
            rows={1}
            aria-label="Message input"
            className="w-full bg-transparent px-4 pt-3 pb-2 text-sm text-zinc-100 placeholder-zinc-500 resize-none focus:outline-none"
            style={{ maxHeight: MAX_TEXTAREA_PX }}
          />

          {/* Bottom bar: + on left, send on right */}
          <div className="flex items-center justify-between px-3 pb-3">
            <button
              onClick={openFilePicker}
              aria-label="Add attachment"
              className="w-8 h-8 flex items-center justify-center rounded-full text-zinc-500 hover:text-zinc-300 hover:bg-zinc-700 transition-colors"
            >
              <PlusIcon />
            </button>

            {isStreaming ? (
              <button
                onClick={onCancel}
                aria-label="Stop generation"
                className="w-8 h-8 flex items-center justify-center rounded-full bg-zinc-600 text-zinc-200 hover:bg-zinc-500 transition-colors"
              >
                <StopIcon />
              </button>
            ) : (
              <button
                onClick={submit}
                disabled={!canSend}
                aria-label="Send message"
                className="w-8 h-8 flex items-center justify-center rounded-full bg-zinc-100 text-zinc-900 hover:bg-white disabled:opacity-20 disabled:hover:bg-zinc-100 transition-colors"
              >
                <ArrowUpIcon />
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
