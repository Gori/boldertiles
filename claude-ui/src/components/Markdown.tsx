import { type ReactNode } from "react";
import { fromMarkdown } from "mdast-util-from-markdown";
import { gfm } from "micromark-extension-gfm";
import { gfmFromMarkdown } from "mdast-util-gfm";
import type { Root, RootContent, PhrasingContent, TableRow, ListItem } from "mdast";
import { CodeBlock } from "./CodeBlock";

interface Props {
  content: string;
}

type MdNode = Root | RootContent | PhrasingContent | TableRow | ListItem;

function renderNode(node: MdNode, key: number | string): ReactNode {
  switch (node.type) {
    case "root":
      return <>{node.children.map((child, i) => renderNode(child, i))}</>;

    case "paragraph":
      return (
        <p key={key} className="my-1 text-zinc-300 leading-relaxed">
          {node.children.map((child, i) => renderNode(child, i))}
        </p>
      );

    case "text":
      return node.value;

    case "heading": {
      const Tag = `h${node.depth}` as "h1" | "h2" | "h3" | "h4" | "h5" | "h6";
      const sizes: Record<number, string> = {
        1: "text-lg font-semibold",
        2: "text-base font-semibold",
        3: "text-sm font-semibold",
        4: "text-sm font-semibold",
        5: "text-sm font-medium",
        6: "text-sm font-medium",
      };
      return (
        <Tag key={key} className={`${sizes[node.depth]} text-zinc-200 mt-3 mb-1`}>
          {node.children.map((child, i) => renderNode(child, i))}
        </Tag>
      );
    }

    case "emphasis":
      return (
        <em key={key}>
          {node.children.map((child, i) => renderNode(child, i))}
        </em>
      );

    case "strong":
      return (
        <strong key={key}>
          {node.children.map((child, i) => renderNode(child, i))}
        </strong>
      );

    case "inlineCode":
      return (
        <code key={key} className="px-1 py-0.5 bg-zinc-800 rounded text-[13px] text-zinc-300">
          {node.value}
        </code>
      );

    case "code":
      return <CodeBlock key={key} language={node.lang ?? ""} code={node.value} />;

    case "link":
      return (
        <a
          key={key}
          href={node.url}
          title={node.title ?? undefined}
          className="text-indigo-400 hover:underline"
          target="_blank"
          rel="noreferrer"
        >
          {node.children.map((child, i) => renderNode(child, i))}
        </a>
      );

    case "image":
      return (
        <img
          key={key}
          src={node.url}
          alt={node.alt ?? ""}
          title={node.title ?? undefined}
          className="max-w-full rounded my-1"
        />
      );

    case "list": {
      const Tag = node.ordered ? "ol" : "ul";
      const listCls = node.ordered
        ? "list-decimal list-inside space-y-0.5 my-1"
        : "list-disc list-inside space-y-0.5 my-1";
      return (
        <Tag key={key} className={listCls} start={node.ordered && node.start != null ? node.start : undefined}>
          {node.children.map((child, i) => renderNode(child, i))}
        </Tag>
      );
    }

    case "listItem": {
      if (node.checked != null) {
        return (
          <li key={key} className="text-zinc-300 list-none">
            <input
              type="checkbox"
              checked={node.checked}
              readOnly
              className="mr-1.5 align-middle"
            />
            {node.children.map((child, i) => {
              if (child.type === "paragraph") {
                return child.children.map((inline, j) => renderNode(inline, `${i}-${j}`));
              }
              return renderNode(child, i);
            })}
          </li>
        );
      }
      return (
        <li key={key} className="text-zinc-300">
          {node.children.map((child, i) => {
            if (child.type === "paragraph") {
              return child.children.map((inline, j) => renderNode(inline, `${i}-${j}`));
            }
            return renderNode(child, i);
          })}
        </li>
      );
    }

    case "blockquote":
      return (
        <blockquote key={key} className="markdown-blockquote">
          {node.children.map((child, i) => renderNode(child, i))}
        </blockquote>
      );

    case "thematicBreak":
      return <hr key={key} className="my-3 border-zinc-700" />;

    case "table":
      return (
        <div key={key} className="my-2 overflow-x-auto">
          <table className="markdown-table">
            <thead>
              {node.children[0] && (
                <tr>
                  {(node.children[0] as TableRow).children.map((cell, i) => (
                    <th
                      key={i}
                      className="markdown-th"
                      style={{ textAlign: node.align?.[i] ?? undefined }}
                    >
                      {cell.children.map((child, j) => renderNode(child, j))}
                    </th>
                  ))}
                </tr>
              )}
            </thead>
            <tbody>
              {node.children.slice(1).map((row, i) => (
                <tr key={i}>
                  {(row as TableRow).children.map((cell, j) => (
                    <td
                      key={j}
                      className="markdown-td"
                      style={{ textAlign: node.align?.[j] ?? undefined }}
                    >
                      {cell.children.map((child, k) => renderNode(child, k))}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );

    case "delete":
      return (
        <del key={key}>
          {node.children.map((child, i) => renderNode(child, i))}
        </del>
      );

    case "break":
      return <br key={key} />;

    case "html":
      return <span key={key} className="text-zinc-500">{node.value}</span>;

    default:
      return null;
  }
}

export function Markdown({ content }: Props) {
  if (!content) return null;

  const tree = fromMarkdown(content, {
    extensions: [gfm()],
    mdastExtensions: [gfmFromMarkdown()],
  });

  return (
    <div className="space-y-1">
      {renderNode(tree, 0)}
    </div>
  );
}
